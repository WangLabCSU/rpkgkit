use extendr_api::prelude::*;

/// Token kinds that matter when deciding whether a `(` opens a call.
#[derive(Clone, Copy, PartialEq, Eq)]
enum Sig {
    Ident,
    DoubleColon,
    TripleColon,
    Dollar,
    At,
    Other,
}

struct GlueString {
    id: i32,
    line1: i32,
    col1: i32,
    text: String,
    content: String,
}

struct BraceResult {
    balanced: bool,
    unmatched_opens: Vec<i32>,
    unmatched_closes: Vec<i32>,
    hl_start: i32,
    hl_end: i32,
}

fn dlgb_advance_rs(ch: char, line: &mut i32, col: &mut i32) {
    if ch == '\n' {
        *line += 1;
        *col = 1;
    } else {
        *col += 1;
    }
}

fn dlgb_consume_rs(chars: &[char], from: usize, to: usize, line: &mut i32, col: &mut i32) {
    for &ch in &chars[from..to] {
        dlgb_advance_rs(ch, line, col);
    }
}

fn dlgb_is_ident_start_rs(c: char) -> bool {
    c.is_alphabetic() || c == '.' || c == '_'
}

fn dlgb_is_ident_continue_rs(c: char) -> bool {
    c.is_alphanumeric() || c == '.' || c == '_'
}

/// Nearest `{` strictly before 1-based `pos`, returned as a 1-based index.
fn dlgb_find_nearest_open_rs(chars: &[char], pos: i32) -> Option<i32> {
    if pos <= 1 {
        return None;
    }
    let limit = ((pos - 1) as usize).min(chars.len());
    chars[..limit]
        .iter()
        .rposition(|&c| c == '{')
        .map(|idx| idx as i32 + 1)
}

fn dlgb_check_brace_balance_str_rs(s: &str) -> BraceResult {
    let chars: Vec<char> = s.chars().collect();
    let mut stack: Vec<i32> = Vec::new();
    let mut extra: Vec<i32> = Vec::new();

    for (idx, &c) in chars.iter().enumerate() {
        let pos = idx as i32 + 1;
        match c {
            '{' => stack.push(pos),
            '}' => {
                if stack.is_empty() {
                    extra.push(pos);
                } else {
                    stack.pop();
                }
            }
            _ => {}
        }
    }

    let balanced = stack.is_empty() && extra.is_empty();

    let (hl_start, hl_end) = if balanced {
        (i32::na(), i32::na())
    } else if !stack.is_empty() && !extra.is_empty() {
        let first_open = *stack.iter().min().unwrap();
        let first_extra_close = extra
            .iter()
            .copied()
            .filter(|&p| p > first_open)
            .min()
            .unwrap_or_else(|| *extra.iter().max().unwrap());
        (first_open, first_extra_close)
    } else if !stack.is_empty() {
        (*stack.iter().min().unwrap(), chars.len() as i32)
    } else {
        let first_extra = extra[0];
        let prev = dlgb_find_nearest_open_rs(&chars, first_extra);
        (prev.unwrap_or(first_extra), first_extra)
    };

    BraceResult {
        balanced,
        unmatched_opens: stack,
        unmatched_closes: extra,
        hl_start,
        hl_end,
    }
}

fn dlgb_format_brace_error_str_rs(
    line_content: &str,
    hl_start: i32,
    hl_end: i32,
    col_offset: i32,
) -> String {
    let line_hl_start = col_offset + hl_start;
    let line_hl_end = col_offset + hl_end;

    let spaces = if line_hl_start > 1 {
        " ".repeat((line_hl_start - 1) as usize)
    } else {
        String::new()
    };
    let carets = if line_hl_end >= line_hl_start {
        "^".repeat((line_hl_end - line_hl_start + 1) as usize)
    } else {
        String::new()
    };

    format!("{}\n{}{}", line_content, spaces, carets)
}

/// Parse an R raw string (`r"(...)"`, `R"---[...]---"`, ...) starting at
/// `start` (the `r`/`R`). Returns the exclusive end index and the body.
fn dlgb_parse_raw_string_rs(chars: &[char], start: usize) -> Option<(usize, String)> {
    let n = chars.len();
    if start + 1 >= n {
        return None;
    }
    let quote = chars[start + 1];
    let mut k = start + 2;
    let mut dashes = 0usize;
    while k < n && chars[k] == '-' {
        dashes += 1;
        k += 1;
    }
    if k >= n {
        return None;
    }
    let close = match chars[k] {
        '(' => ')',
        '[' => ']',
        '{' => '}',
        _ => return None,
    };
    let content_start = k + 1;
    let mut m = content_start;
    while m < n {
        if chars[m] == close {
            let mut p = m + 1;
            let mut matched = true;
            for _ in 0..dashes {
                if p >= n || chars[p] != '-' {
                    matched = false;
                    break;
                }
                p += 1;
            }
            if matched && p < n && chars[p] == quote {
                let content: String = chars[content_start..m].iter().collect();
                return Some((p + 1, content));
            }
        }
        m += 1;
    }
    None
}

/// Collect every string literal that appears inside a `glue()`,
/// `glue_data()` or `cli_*()` call.
fn dlgb_scan_glue_strings_rs(text: &str) -> Vec<GlueString> {
    let chars: Vec<char> = text.chars().collect();
    let n = chars.len();
    let mut i = 0usize;
    let mut line = 1i32;
    let mut col = 1i32;
    let mut stack: Vec<bool> = Vec::new();
    let mut target_depth = 0usize;
    let mut out: Vec<GlueString> = Vec::new();
    let mut next_id = 1i32;

    let mut last_sig: Option<Sig> = None;
    let mut prev_sig: Option<Sig> = None;
    let mut last_ident = String::new();

    macro_rules! set_sig {
        ($s:expr) => {{
            prev_sig = last_sig;
            last_sig = Some($s);
        }};
    }

    while i < n {
        let c = chars[i];

        // Comments run to the end of the line and may contain anything.
        if c == '#' {
            let mut j = i;
            while j < n && chars[j] != '\n' {
                j += 1;
            }
            dlgb_consume_rs(&chars, i, j, &mut line, &mut col);
            i = j;
            continue;
        }

        // Raw strings must be checked before the generic identifier branch.
        if (c == 'r' || c == 'R') && i + 1 < n && (chars[i + 1] == '"' || chars[i + 1] == '\'') {
            if let Some((end, content)) = dlgb_parse_raw_string_rs(&chars, i) {
                if target_depth > 0 {
                    let start_line = line;
                    let start_col = col;
                    let text: String = chars[i..end].iter().collect();
                    out.push(GlueString {
                        id: next_id,
                        line1: start_line,
                        col1: start_col,
                        text,
                        content,
                    });
                    next_id += 1;
                }
                dlgb_consume_rs(&chars, i, end, &mut line, &mut col);
                i = end;
                set_sig!(Sig::Other);
                continue;
            }
        }

        // Backtick names: `glue`("x") is still a glue call.
        if c == '`' {
            let mut j = i + 1;
            while j < n {
                if chars[j] == '\\' {
                    j += 2;
                    continue;
                }
                if chars[j] == '`' {
                    j += 1;
                    break;
                }
                j += 1;
            }
            let end = j.min(n);
            let name_end = if end > i + 1 && chars[end - 1] == '`' {
                end - 1
            } else {
                end
            };
            last_ident = chars[i + 1..name_end].iter().collect();
            dlgb_consume_rs(&chars, i, end, &mut line, &mut col);
            i = end;
            set_sig!(Sig::Ident);
            continue;
        }

        // Ordinary single- or double-quoted strings.
        if c == '"' || c == '\'' {
            let start_line = line;
            let start_col = col;
            let quote = c;
            let mut j = i + 1;
            let mut closed = false;
            let mut escaped = false;
            while j < n {
                let ch = chars[j];
                if escaped {
                    escaped = false;
                } else if ch == '\\' {
                    escaped = true;
                } else if ch == quote {
                    closed = true;
                    j += 1;
                    break;
                }
                j += 1;
            }
            let end = j;
            let content_end = if closed { end - 1 } else { end };
            if target_depth > 0 {
                let text: String = chars[i..end].iter().collect();
                let content: String = chars[i + 1..content_end].iter().collect();
                out.push(GlueString {
                    id: next_id,
                    line1: start_line,
                    col1: start_col,
                    text,
                    content,
                });
                next_id += 1;
            }
            dlgb_consume_rs(&chars, i, end, &mut line, &mut col);
            i = end;
            set_sig!(Sig::Other);
            continue;
        }

        if dlgb_is_ident_start_rs(c) {
            let start = i;
            let mut j = i + 1;
            while j < n && dlgb_is_ident_continue_rs(chars[j]) {
                j += 1;
            }
            last_ident = chars[start..j].iter().collect();
            dlgb_consume_rs(&chars, start, j, &mut line, &mut col);
            i = j;
            set_sig!(Sig::Ident);
            continue;
        }

        if c.is_ascii_digit() {
            let mut j = i + 1;
            while j < n && (chars[j].is_alphanumeric() || chars[j] == '.' || chars[j] == '_') {
                j += 1;
            }
            dlgb_consume_rs(&chars, i, j, &mut line, &mut col);
            i = j;
            set_sig!(Sig::Other);
            continue;
        }

        if c == ':' {
            if i + 1 < n && chars[i + 1] == ':' {
                if i + 2 < n && chars[i + 2] == ':' {
                    dlgb_consume_rs(&chars, i, i + 3, &mut line, &mut col);
                    i += 3;
                    set_sig!(Sig::TripleColon);
                } else {
                    dlgb_consume_rs(&chars, i, i + 2, &mut line, &mut col);
                    i += 2;
                    set_sig!(Sig::DoubleColon);
                }
            } else {
                dlgb_consume_rs(&chars, i, i + 1, &mut line, &mut col);
                i += 1;
                set_sig!(Sig::Other);
            }
            continue;
        }

        if c == '$' {
            dlgb_consume_rs(&chars, i, i + 1, &mut line, &mut col);
            i += 1;
            set_sig!(Sig::Dollar);
            continue;
        }

        if c == '@' {
            dlgb_consume_rs(&chars, i, i + 1, &mut line, &mut col);
            i += 1;
            set_sig!(Sig::At);
            continue;
        }

        if c == '(' {
            let mut is_target = false;
            if last_sig == Some(Sig::Ident)
                && !matches!(prev_sig, Some(Sig::Dollar) | Some(Sig::At))
            {
                is_target = last_ident.starts_with("glue") || last_ident.starts_with("cli_");
            }
            stack.push(is_target);
            if is_target {
                target_depth += 1;
            }
            dlgb_consume_rs(&chars, i, i + 1, &mut line, &mut col);
            i += 1;
            set_sig!(Sig::Other);
            continue;
        }

        if c == ')' {
            if let Some(target) = stack.pop() {
                if target {
                    target_depth -= 1;
                }
            }
            dlgb_consume_rs(&chars, i, i + 1, &mut line, &mut col);
            i += 1;
            set_sig!(Sig::Other);
            continue;
        }

        dlgb_consume_rs(&chars, i, i + 1, &mut line, &mut col);
        i += 1;
        set_sig!(Sig::Other);
    }

    out
}

fn dlgb_brace_result_to_list_rs(result: BraceResult) -> List {
    List::from_pairs([
        ("balanced", Robj::from(result.balanced)),
        ("unmatched_opens", Robj::from(result.unmatched_opens)),
        ("unmatched_closes", Robj::from(result.unmatched_closes)),
        ("hl_start", Robj::from(result.hl_start)),
        ("hl_end", Robj::from(result.hl_end)),
    ])
}

/// Stack-based `{` / `}` balance check for one glue/cli string body.
/// @keywords internal
#[extendr]
pub fn dlgb_check_brace_balance_rs(s: &str) -> List {
    dlgb_brace_result_to_list_rs(dlgb_check_brace_balance_str_rs(s))
}

/// Nearest `{` before a 1-based position, `-1` when there is none.
/// @keywords internal
#[extendr]
pub fn dlgb_find_nearest_open_before_rs(s: &str, pos: i32) -> i32 {
    let chars: Vec<char> = s.chars().collect();
    dlgb_find_nearest_open_rs(&chars, pos).unwrap_or(-1)
}

/// Build the two-line `source` + `^^^^` caret output.
/// @keywords internal
#[extendr]
pub fn dlgb_format_brace_error_rs(
    line_content: &str,
    hl_start: i32,
    hl_end: i32,
    col_offset: i32,
) -> String {
    dlgb_format_brace_error_str_rs(line_content, hl_start, hl_end, col_offset)
}

/// String literals inside glue()/glue_data()/cli_*() calls.
/// @keywords internal
#[extendr]
pub fn dlgb_find_glue_strings_rs(text: &str) -> List {
    let items: Vec<Robj> = dlgb_scan_glue_strings_rs(text)
        .into_iter()
        .map(|s| {
            Robj::from(List::from_pairs([
                ("id", Robj::from(s.id)),
                ("line1", Robj::from(s.line1)),
                ("col1", Robj::from(s.col1)),
                ("text", Robj::from(s.text)),
                ("content", Robj::from(s.content)),
            ]))
        })
        .collect();
    items.into_iter().collect()
}

extendr_module! {
    mod detect;
    fn dlgb_check_brace_balance_rs;
    fn dlgb_find_nearest_open_before_rs;
    fn dlgb_format_brace_error_rs;
    fn dlgb_find_glue_strings_rs;
}
