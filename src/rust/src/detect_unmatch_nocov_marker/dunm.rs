use extendr_api::prelude::*;
use extendr_api::Result;
use regex::Regex;

/// One `# nocov start` / `# nocov end` comment marker.
struct Marker {
    line1: i32,
    col1: i32,
    col2: i32,
    kind: String,
    text: String,
}

/// One rule violation.
struct Problem {
    index: usize,
    reason: &'static str,
    reference: Option<usize>,
    text: String,
}

/// Find every `nocov` marker of a character vector of source lines.
///
/// Rust rewrite of `rpkgkit:::find_nocov_markers()`. Detection is purely
/// textual, so a marker hidden in a string literal or in a roxygen comment is
/// reported as well, on purpose. `lines` is a `Vec<String>` because iterating a
/// zero-length `Strings` panics in debug builds (empty files are common).
/// @keywords internal
#[extendr]
pub fn dunm_find_markers_rs(lines: Vec<String>) -> Result<List> {
    let markers = dunm_find_markers_impl(&lines)?;
    Ok(dunm_markers_to_list(&markers))
}

/// Check the markers against the `nocov` rules.
///
/// Rust rewrite of `rpkgkit:::check_nocov_markers()`. Returns one list per
/// problem with `index` (1-based position in `markers`), `reason`, `reference`
/// (1-based, `NA` when the problem has no reference marker) and `text`, the
/// sentence built by `rpkgkit:::nocov_problem_text()`.
/// @keywords internal
#[extendr]
pub fn dunm_check_markers_rs(markers: List) -> List {
    let markers = dunm_markers_from_list(&markers);
    let problems = dunm_check_markers_impl(&markers);
    let out: Vec<Robj> = problems
        .into_iter()
        .map(|problem| {
            Robj::from(List::from_pairs([
                ("index", Robj::from(problem.index as i32 + 1)),
                ("reason", Robj::from(problem.reason)),
                (
                    "reference",
                    Robj::from(match problem.reference {
                        Some(idx) => idx as i32 + 1,
                        None => i32::na(),
                    }),
                ),
                ("text", Robj::from(problem.text)),
            ]))
        })
        .collect();
    out.into_iter().collect()
}

/// Build the two-line `source` + `^^^^` caret output under a marker.
/// @keywords internal
#[extendr]
pub fn dunm_format_marker_error_rs(line_content: &str, col1: i32, col2: i32) -> String {
    let spaces = if col1 > 1 {
        " ".repeat((col1 - 1) as usize)
    } else {
        String::new()
    };
    let carets = if col2 >= col1 {
        "^".repeat((col2 - col1 + 1) as usize)
    } else {
        String::new()
    };
    format!("{}\n{}{}", line_content, spaces, carets)
}

fn dunm_find_markers_impl(lines: &[String]) -> Result<Vec<Marker>> {
    let pattern = r"(?i)#+[ \t]+nocov[ \t]+(start|end)\b";
    let re = match Regex::new(pattern) {
        Ok(re) => re,
        Err(err) => return Err(format!("invalid `nocov` pattern: {}", err).into()),
    };

    let mut out: Vec<Marker> = Vec::new();
    for (idx, line) in lines.iter().enumerate() {
        for caps in re.captures_iter(line) {
            let whole = match caps.get(0) {
                Some(m) => m,
                None => continue,
            };
            let prefix_chars = line[..whole.start()].chars().count() as i32;
            let match_chars = whole.as_str().chars().count() as i32;
            let kind = caps
                .get(1)
                .map(|m| m.as_str().to_lowercase())
                .unwrap_or_else(|| "start".to_string());
            out.push(Marker {
                line1: idx as i32 + 1,
                col1: prefix_chars + 1,
                col2: prefix_chars + match_chars,
                kind,
                text: whole.as_str().to_string(),
            });
        }
    }
    Ok(out)
}

fn dunm_check_markers_impl(markers: &[Marker]) -> Vec<Problem> {
    let start_index: Vec<usize> = markers
        .iter()
        .enumerate()
        .filter(|(_, m)| m.kind == "start")
        .map(|(idx, _)| idx)
        .collect();
    let end_index: Vec<usize> = markers
        .iter()
        .enumerate()
        .filter(|(_, m)| m.kind == "end")
        .map(|(idx, _)| idx)
        .collect();

    let mut problems: Vec<Problem> = Vec::new();

    // Only the first `nocov start` of a file is meaningful.
    for &k in start_index.iter().skip(1) {
        problems.push(dunm_problem(
            markers,
            k,
            "duplicate_start",
            Some(start_index[0]),
        ));
    }

    // Only the first `nocov end` of a file is meaningful.
    for &k in end_index.iter().skip(1) {
        problems.push(dunm_problem(
            markers,
            k,
            "duplicate_end",
            Some(end_index[0]),
        ));
    }

    if let Some(&first_end) = end_index.first() {
        if start_index.is_empty() {
            problems.push(dunm_problem(markers, first_end, "unmatched_end", None));
        } else if dunm_comes_before(&markers[first_end], &markers[start_index[0]]) {
            problems.push(dunm_problem(
                markers,
                first_end,
                "end_before_start",
                Some(start_index[0]),
            ));
        }
    }

    // A start must be closed by an end: covr aborts on an unclosed range.
    if !start_index.is_empty() && end_index.is_empty() {
        problems.push(dunm_problem(
            markers,
            start_index[0],
            "unmatched_start",
            None,
        ));
    }

    problems.sort_by_key(|problem| problem.index);
    problems
}

fn dunm_problem(
    markers: &[Marker],
    index: usize,
    reason: &'static str,
    reference: Option<usize>,
) -> Problem {
    let text = dunm_problem_text(markers, index, reason, reference);
    Problem {
        index,
        reason,
        reference,
        text,
    }
}

fn dunm_marker_at(markers: &[Marker], index: usize) -> String {
    let marker = &markers[index];
    format!(
        "`nocov {}` at line {}, column {}",
        marker.kind, marker.line1, marker.col1
    )
}

fn dunm_problem_text(
    markers: &[Marker],
    index: usize,
    reason: &str,
    reference: Option<usize>,
) -> String {
    let at = dunm_marker_at(markers, index);
    match reason {
        "unmatched_end" => format!("{} has no matching `nocov start`.", at),
        "unmatched_start" => format!("{} has no matching `nocov end`.", at),
        _ => {
            let reference_at = match reference {
                Some(idx) => dunm_marker_at(markers, idx),
                None => String::new(),
            };
            match reason {
                "duplicate_start" => format!(
                    "{}: only one `nocov start` is allowed per file, the first is {}.",
                    at, reference_at
                ),
                "duplicate_end" => format!(
                    "{}: only one `nocov end` is allowed per file, the first is {}.",
                    at, reference_at
                ),
                _ => format!("{} comes before {}.", at, reference_at),
            }
        }
    }
}

fn dunm_comes_before(a: &Marker, b: &Marker) -> bool {
    if a.line1 != b.line1 {
        return a.line1 < b.line1;
    }
    a.col1 < b.col1
}

fn dunm_markers_to_list(markers: &[Marker]) -> List {
    let items: Vec<Robj> = markers
        .iter()
        .map(|marker| {
            Robj::from(List::from_pairs([
                ("line1", Robj::from(marker.line1)),
                ("col1", Robj::from(marker.col1)),
                ("col2", Robj::from(marker.col2)),
                ("type", Robj::from(marker.kind.clone())),
                ("text", Robj::from(marker.text.clone())),
            ]))
        })
        .collect();
    items.into_iter().collect()
}

fn dunm_markers_from_list(markers: &List) -> Vec<Marker> {
    let mut out: Vec<Marker> = Vec::new();
    for item in markers.values() {
        let list = match item.as_list() {
            Some(list) => list,
            None => continue,
        };
        out.push(Marker {
            line1: dunm_field_i32(&list, "line1"),
            col1: dunm_field_i32(&list, "col1"),
            col2: dunm_field_i32(&list, "col2"),
            kind: dunm_field_string(&list, "type"),
            text: dunm_field_string(&list, "text"),
        });
    }
    out
}

fn dunm_field(list: &List, name: &str) -> Option<Robj> {
    list.iter()
        .find(|(key, _)| *key == name)
        .map(|(_, value)| value)
}

fn dunm_field_i32(list: &List, name: &str) -> i32 {
    dunm_field(list, name)
        .and_then(|value| value.as_integer_vector())
        .and_then(|values| values.first().copied())
        .unwrap_or(0)
}

fn dunm_field_string(list: &List, name: &str) -> String {
    dunm_field(list, name)
        .and_then(|value| value.as_string_vector())
        .and_then(|values| values.first().cloned())
        .unwrap_or_default()
}

extendr_module! {
    mod dunm;
    fn dunm_find_markers_rs;
    fn dunm_check_markers_rs;
    fn dunm_format_marker_error_rs;
}
