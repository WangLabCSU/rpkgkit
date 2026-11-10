use crate::r_syntax::{
    matching_close, next_sig, prev_sig, split_args, tokenize, trim_range, trim_ws, Kind,
};
use extendr_api::prelude::*;
use extendr_api::Result;

/// One element of a `c()` / `list()` call, with its source span.
#[derive(Clone, Copy)]
struct Element {
    line1: i32,
    col1: i32,
    line2: i32,
    col2: i32,
}

/// One `c()` / `list()` call that deserves the `# fmt: table` directive.
struct Target {
    line1: i32,
    line2: i32,
    col1: i32,
    n: i32,
    multiline: bool,
    elements: Vec<Element>,
}

/// Locate the long, unnamed `c()` / `list()` calls of a source text.
///
/// Rust rewrite of `rpkgkit:::.at_targets()` / `.at_call_info()`. The AST is
/// replaced by the tokenizer of [`crate::r_syntax`]: a call is kept when it is
/// the outermost call of a statement, carries no named element and holds more
/// than `min_length` elements. Returns one list per call with `line1`, `line2`,
/// `col1`, `n`, `multiline` and `elements`, the latter being one integer vector
/// `c(line1, col1, line2, col2)` per element.
/// @keywords internal
#[extendr]
pub fn uat_find_targets_rs(text: &str, min_length: i32, marker: &str) -> Result<List> {
    let out: Vec<Robj> = uat_find_targets_impl(text, min_length, marker)
        .into_iter()
        .map(uat_target_to_robj)
        .collect();
    Ok(out.into_iter().collect())
}

fn uat_find_targets_impl(text: &str, min_length: i32, marker: &str) -> Vec<Target> {
    let tokens = tokenize(text);
    let lines: Vec<String> = text.split('\n').map(|line| line.to_string()).collect();

    // Bracket frames: `(` after a function name and `[` are calls, `{` is not.
    let mut inside_call = vec![false; tokens.len()];
    let mut stack: Vec<bool> = Vec::new();
    let mut call_depth = 0usize;
    for (k, tok) in tokens.iter().enumerate() {
        inside_call[k] = call_depth > 0;
        if tok.kind != Kind::Op {
            continue;
        }
        match tok.text(text) {
            "(" => {
                let is_call = matches!(prev_sig(&tokens, k), Some(p)
                    if matches!(tokens[p].kind, Kind::Ident | Kind::Backtick | Kind::Str)
                        || tokens[p].is_close(text));
                stack.push(is_call);
                if is_call {
                    call_depth += 1;
                }
            }
            "[" => {
                stack.push(true);
                call_depth += 1;
            }
            "{" => stack.push(false),
            ")" | "]" | "}" => {
                if let Some(is_call) = stack.pop() {
                    if is_call {
                        call_depth = call_depth.saturating_sub(1);
                    }
                }
            }
            _ => {}
        }
    }

    let mut targets: Vec<Target> = Vec::new();

    for k in 0..tokens.len() {
        let tok = &tokens[k];
        if tok.kind != Kind::Ident {
            continue;
        }
        let name = tok.text(text);
        if name != "c" && name != "list" {
            continue;
        }
        // Air only honours the directive on the outermost call of a statement.
        if inside_call[k] {
            continue;
        }
        if let Some(prev) = prev_sig(&tokens, k) {
            let allowed = tokens[prev].kind == Kind::Op
                && matches!(
                    tokens[prev].text(text),
                    "<-" | "<<-" | "=" | ";" | "{" | "}" | "("
                );
            if !allowed {
                continue;
            }
        }

        let open = match next_sig(&tokens, k + 1) {
            Some(idx) => idx,
            None => continue,
        };
        if !tokens[open].is_op(text, "(") {
            continue;
        }
        let close = match matching_close(&tokens, text, open) {
            Some(idx) => idx,
            None => continue,
        };

        let mut elements: Vec<Element> = Vec::new();
        let mut named = false;
        for (from, to) in split_args(&tokens, text, open, close) {
            let (start, end) = match trim_range(&tokens, from, to) {
                Some(range) => range,
                None => continue,
            };
            if matches!(tokens[start].kind, Kind::Ident | Kind::Backtick | Kind::Str) {
                if let Some(eq) = next_sig(&tokens, start + 1) {
                    if eq < end && tokens[eq].is_op(text, "=") {
                        named = true;
                        break;
                    }
                }
            }
            elements.push(Element {
                line1: tokens[start].line1,
                col1: tokens[start].col1,
                line2: tokens[end - 1].line2,
                col2: tokens[end - 1].col2,
            });
        }
        // Air refuses to build a table out of named elements.
        if named || elements.is_empty() {
            continue;
        }
        if elements.len() as i32 <= min_length {
            continue;
        }

        let line1 = tok.line1;
        if line1 > 1 {
            if let Some(previous) = lines.get((line1 - 2) as usize) {
                if trim_ws(previous) == marker {
                    continue;
                }
            }
        }

        targets.push(Target {
            line1,
            line2: tokens[close].line2,
            col1: tok.col1,
            n: elements.len() as i32,
            multiline: tokens[close].line2 > line1,
            elements,
        });
    }

    // Keep the outermost call of nested candidates, in source order.
    targets.sort_by_key(|target| (target.line1, target.col1));
    let mut kept: Vec<Target> = Vec::new();
    let mut last_line2 = i32::MIN;
    for target in targets {
        if target.line1 > last_line2 {
            last_line2 = target.line2;
            kept.push(target);
        }
    }

    kept
}

/// Insert the directive and re-flow the elements of the targets.
///
/// Rust rewrite of `rpkgkit:::.at_collapse()`: a multi-line definition gets the
/// directive on its own line and the line breaks inside a row removed; a
/// single-line definition is split into rows instead.
/// @keywords internal
#[extendr]
pub fn uat_collapse_rs(lines: Strings, targets: List, ncol: i32, marker: &str) -> Strings {
    let lines: Vec<String> = lines.iter().map(|line| line.to_string()).collect();
    let targets = uat_targets_from_list(&targets);
    let out = uat_collapse_impl(&lines, &targets, ncol.max(1) as usize, marker);
    Strings::from_values(out)
}

/// Rewrite a single-line definition as a table, without the directive.
/// @keywords internal
#[extendr]
pub fn uat_split_lines_rs(line: &str, call_col1: i32, elements: List, ncol: i32) -> Strings {
    let elements = uat_elements_from_list(&elements);
    let out = uat_split_lines_impl(line, call_col1, &elements, ncol.max(1) as usize);
    Strings::from_values(out)
}

/// Rows of element indices, `ncol` per row.
/// @keywords internal
#[extendr]
pub fn uat_rows_rs(n: i32, ncol: i32) -> List {
    let rows = uat_rows_impl(n.max(0) as usize, ncol.max(1) as usize);
    // R's `split(seq_len(n), ...)` returns 1-based indices; the internal rows
    // are 0-based because they index Rust vectors.
    let items: Vec<Robj> = rows
        .into_iter()
        .map(|row| {
            Robj::from(
                row.into_iter()
                    .map(|idx| idx as i32 + 1)
                    .collect::<Vec<i32>>(),
            )
        })
        .collect();
    items.into_iter().collect()
}

/// Flag the line breaks that disappear when the rows are collapsed.
///
/// A line ending in a comment is never joined with the next one: the joined
/// element would be swallowed by the comment.
/// @keywords internal
#[extendr]
pub fn uat_join_flags_rs(join: Logicals, elements: List, ncol: i32, lines: Strings) -> Logicals {
    let flags: Vec<bool> = join.iter().map(|value| value.to_bool()).collect();
    let elements = uat_elements_from_list(&elements);
    let lines: Vec<String> = lines.iter().map(|line| line.to_string()).collect();
    let flags = uat_join_flags_impl(flags, &elements, ncol.max(1) as usize, &lines);
    let out: Vec<Rbool> = flags.into_iter().map(Rbool::from_bool).collect();
    Logicals::from_values(out)
}

fn uat_target_to_robj(target: Target) -> Robj {
    let elements: Vec<Robj> = target
        .elements
        .iter()
        .map(|element| {
            Robj::from(vec![
                element.line1,
                element.col1,
                element.line2,
                element.col2,
            ])
        })
        .collect();
    let elements: List = elements.into_iter().collect();
    Robj::from(List::from_pairs([
        ("line1", Robj::from(target.line1)),
        ("line2", Robj::from(target.line2)),
        ("col1", Robj::from(target.col1)),
        ("n", Robj::from(target.n)),
        ("multiline", Robj::from(target.multiline)),
        ("elements", Robj::from(elements)),
    ]))
}

fn uat_field(list: &List, name: &str) -> Option<Robj> {
    list.iter()
        .find(|(key, _)| *key == name)
        .map(|(_, value)| value)
}

fn uat_field_i32(list: &List, name: &str) -> i32 {
    uat_field(list, name)
        .and_then(|value| value.as_integer_vector())
        .and_then(|values| values.first().copied())
        .unwrap_or(0)
}

fn uat_field_bool(list: &List, name: &str) -> bool {
    uat_field(list, name)
        .and_then(|value| value.as_logical_vector())
        .and_then(|values| values.first().map(|value| value.to_bool()))
        .unwrap_or(false)
}

fn uat_targets_from_list(targets: &List) -> Vec<Target> {
    let mut out: Vec<Target> = Vec::new();
    for item in targets.values() {
        let list = match item.as_list() {
            Some(list) => list,
            None => continue,
        };
        out.push(Target {
            line1: uat_field_i32(&list, "line1"),
            line2: uat_field_i32(&list, "line2"),
            col1: uat_field_i32(&list, "col1"),
            n: uat_field_i32(&list, "n"),
            multiline: uat_field_bool(&list, "multiline"),
            elements: uat_elements_from_list(
                &uat_field(&list, "elements")
                    .and_then(|obj| obj.as_list())
                    .unwrap_or_default(),
            ),
        });
    }
    out
}

fn uat_elements_from_list(elements: &List) -> Vec<Element> {
    let mut out: Vec<Element> = Vec::new();
    for item in elements.values() {
        if let Some(values) = item.as_integer_vector() {
            if values.len() >= 4 {
                out.push(Element {
                    line1: values[0],
                    col1: values[1],
                    line2: values[2],
                    col2: values[3],
                });
            }
        }
    }
    out
}

fn uat_rows_impl(n: usize, ncol: usize) -> Vec<Vec<usize>> {
    let mut rows: Vec<Vec<usize>> = Vec::new();
    if ncol == 0 {
        return rows;
    }
    let mut row: Vec<usize> = Vec::with_capacity(ncol);
    for idx in 0..n {
        row.push(idx);
        if row.len() == ncol {
            rows.push(std::mem::take(&mut row));
        }
    }
    if !row.is_empty() {
        rows.push(row);
    }
    rows
}

fn uat_collapse_impl(
    lines: &[String],
    targets: &[Target],
    ncol: usize,
    marker: &str,
) -> Vec<String> {
    let n_lines = lines.len();
    let mut insert: Vec<Option<String>> = vec![None; n_lines];
    let mut join: Vec<bool> = vec![false; n_lines];
    let mut replace: Vec<Option<Vec<String>>> = (0..n_lines).map(|_| None).collect();

    for target in targets {
        let first_line = target.line1 - 1;
        if first_line < 0 {
            continue;
        }
        let first = first_line as usize;
        if first >= n_lines {
            continue;
        }
        let indent = uat_indent(&lines[first]);
        let marker_line = format!("{}{}", indent, marker);

        if target.multiline {
            insert[first] = Some(marker_line);
            join = uat_join_flags_impl(join, &target.elements, ncol, lines);
        } else {
            let mut replacement = vec![marker_line];
            replacement.extend(uat_split_lines_impl(
                &lines[first],
                target.col1,
                &target.elements,
                ncol,
            ));
            replace[first] = Some(replacement);
        }
    }

    let mut out: Vec<String> = Vec::new();
    for i in 0..n_lines {
        let replaced = std::mem::take(&mut replace[i]);
        if let Some(replacement) = replaced {
            out.extend(replacement);
            continue;
        }
        let inserted = std::mem::take(&mut insert[i]);
        if let Some(inserted) = inserted {
            out.push(inserted);
        }
        if join[i] && !out.is_empty() {
            let last = out.last_mut().unwrap();
            *last = format!("{} {}", last, trim_ws(&lines[i]));
        } else {
            out.push(lines[i].clone());
        }
    }

    out
}

fn uat_join_flags_impl(
    mut join: Vec<bool>,
    elements: &[Element],
    ncol: usize,
    lines: &[String],
) -> Vec<bool> {
    let n_lines = lines.len();
    for row in uat_rows_impl(elements.len(), ncol) {
        if row.len() < 2 {
            continue;
        }
        for k in 0..(row.len() - 1) {
            let from = elements[row[k]].line2;
            let to = elements[row[k + 1]].line1;
            if to != from + 1 {
                continue;
            }
            if from < 1 {
                continue;
            }
            let line_idx = (from - 1) as usize;
            if line_idx >= n_lines {
                continue;
            }
            let chars: Vec<char> = lines[line_idx].chars().collect();
            let start = (elements[row[k]].col2.max(0) as usize).min(chars.len());
            let trailing: String = chars[start..].iter().collect();
            if !trailing.contains('#') {
                let idx: usize = (to - 1) as usize;
                if idx < join.len() {
                    join[idx] = true;
                }
            }
        }
    }
    join
}

fn uat_indent(line: &str) -> String {
    line.chars()
        .take_while(|c| *c == ' ' || *c == '\t')
        .collect()
}

fn uat_split_lines_impl(
    line: &str,
    call_col1: i32,
    elements: &[Element],
    ncol: usize,
) -> Vec<String> {
    if elements.is_empty() {
        return Vec::new();
    }
    let chars: Vec<char> = line.chars().collect();
    let len = chars.len();
    let indent = uat_indent(line);
    let prefix: String = chars[..((call_col1 - 1).max(0) as usize).min(len)]
        .iter()
        .collect();
    let open_start = ((call_col1 - 1).max(0) as usize).min(len);
    let open_end = ((elements[0].col1 - 1).max(0) as usize)
        .min(len)
        .max(open_start);
    let open: String = chars[open_start..open_end].iter().collect();
    let open = open.trim_end();

    let cells: Vec<String> = elements
        .iter()
        .map(|element| {
            let start = ((element.col1 - 1).max(0) as usize).min(len);
            let end = (element.col2.max(0) as usize).min(len);
            if end > start {
                chars[start..end].iter().collect()
            } else {
                String::new()
            }
        })
        .collect();

    // `substring(line, col2 + 1L, nchar(line))` in 1-based R columns.
    let close_col = (elements[elements.len() - 1].col2.max(0) as usize).min(len);
    let close: String = chars[close_col..].iter().collect();

    let rows = uat_rows_impl(cells.len(), ncol);
    let mut row_text: Vec<String> = rows
        .iter()
        .map(|row| {
            row.iter()
                .map(|idx| cells[*idx].clone())
                .collect::<Vec<String>>()
                .join(", ")
        })
        .collect();
    let last = row_text.len().saturating_sub(1);
    for (idx, text) in row_text.iter_mut().enumerate() {
        if idx != last {
            text.push(',');
        }
    }

    let mut out: Vec<String> = Vec::new();
    out.push(format!("{}{}", prefix, open));
    for text in row_text {
        out.push(format!("{}  {}", indent, text));
    }
    out.push(format!("{}{}", indent, close));
    out
}

extendr_module! {
    mod uat;
    fn uat_find_targets_rs;
    fn uat_collapse_rs;
    fn uat_split_lines_rs;
    fn uat_rows_rs;
    fn uat_join_flags_rs;
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn finds_long_calls() {
        let targets = uat_find_targets_impl("x <- c(1, 2, 3)\n", 2, "# fmt: table");
        assert_eq!(targets.len(), 1);
        assert_eq!(targets[0].n, 3);
        assert!(!targets[0].multiline);
    }

    #[test]
    fn skips_named_and_nested() {
        assert!(
            uat_find_targets_impl("x <- list(a = 1, b = 2, c = 3)\n", 2, "# fmt: table").is_empty()
        );
        assert!(uat_find_targets_impl("y <- foo(c(1, 2, 3))\n", 2, "# fmt: table").is_empty());
        assert!(uat_find_targets_impl("z <- c(1, 2)\n", 2, "# fmt: table").is_empty());
    }

    #[test]
    fn collapses_multiline() {
        let lines = vec![
            "x <- c(".to_string(),
            "  1,".to_string(),
            "  2,".to_string(),
            "  3".to_string(),
            ")".to_string(),
        ];
        let targets = uat_find_targets_impl(&lines.join("\n"), 2, "# fmt: table");
        let out = uat_collapse_impl(&lines, &targets, 2, "# fmt: table");
        assert_eq!(
            out,
            vec![
                "# fmt: table".to_string(),
                "x <- c(".to_string(),
                "  1, 2,".to_string(),
                "  3".to_string(),
                ")".to_string()
            ]
        );
    }

    #[test]
    fn splits_single_line() {
        let line = "x <- c(1, 2, 3)";
        let targets = uat_find_targets_impl(line, 2, "# fmt: table");
        let out = uat_split_lines_impl(line, targets[0].col1, &targets[0].elements, 2);
        assert_eq!(
            out,
            vec![
                "x <- c(".to_string(),
                "  1, 2,".to_string(),
                "  3".to_string(),
                ")".to_string()
            ]
        );
    }
}
