use extendr_api::prelude::*;

/// Index (1-based) of the `)` closing the `(` at `open_pos`, `NA` when none.
///
/// Rust rewrite of `rpkgkit:::.cfs_find_matching_paren()`. Like the R helper it
/// counts only parentheses: the character vector is the raw source, so brackets
/// inside strings are counted too. `text` is the characters joined back into
/// one string.
/// @keywords internal
#[extendr]
pub fn cfs_find_matching_paren_rs(text: &str, open_pos: i32) -> i32 {
    let chars: Vec<char> = text.chars().collect();
    let start = (open_pos - 1).max(0) as usize;
    match cfs_matching_close(&chars, start) {
        Some(close) => close as i32 + 1,
        None => i32::na(),
    }
}

/// One character-level pass over the source text.
///
/// Rust rewrite of `rpkgkit:::.cfs_process_text_once()`. Strings (with escapes)
/// and comments are copied verbatim; `function(...)` becomes `\(...)` for
/// `direction = "to_lambda"`, and `\(...)` becomes `function(...)` otherwise.
/// Only one level of nesting is rewritten per call.
/// @keywords internal
#[extendr]
pub fn cfs_process_text_once_rs(text: &str, direction: &str) -> String {
    cfs_process_once(text, direction)
}

/// Repeat single passes until the text stops changing.
///
/// Rust rewrite of `rpkgkit:::.cfs_transform_text()`: nested function
/// definitions need one pass per nesting level.
/// @keywords internal
#[extendr]
pub fn cfs_transform_text_rs(text: &str, direction: &str) -> String {
    let mut current = text.to_string();
    // Each pass can only remove one nesting level; the bound merely prevents an
    // infinite loop on pathological input.
    for _ in 0..1024 {
        let next = cfs_process_once(&current, direction);
        if next == current {
            break;
        }
        current = next;
    }
    current
}

fn cfs_is_ident_char(c: char) -> bool {
    c.is_ascii_alphanumeric() || c == '.' || c == '_'
}

/// 0-based index of the matching `)` for the `(` at `open` (0-based).
fn cfs_matching_close(chars: &[char], open: usize) -> Option<usize> {
    let mut depth = 0i32;
    for (k, ch) in chars.iter().enumerate().skip(open) {
        if *ch == '(' {
            depth += 1;
        }
        if *ch == ')' {
            depth -= 1;
            if depth == 0 {
                return Some(k);
            }
        }
    }
    None
}

fn cfs_process_once(text: &str, direction: &str) -> String {
    let chars: Vec<char> = text.chars().collect();
    let n = chars.len();
    let to_lambda = direction == "to_lambda";
    let mut out = String::with_capacity(text.len());
    let mut in_string = false;
    let mut string_char = '\0';
    let mut in_comment = false;
    let mut i = 0usize;

    while i < n {
        let ch = chars[i];

        // ---- track string state ----
        if !in_comment && !in_string && (ch == '\'' || ch == '"') {
            in_string = true;
            string_char = ch;
            out.push(ch);
            i += 1;
            continue;
        }
        if in_string {
            if ch == '\\' && i + 1 < n {
                out.push(ch);
                out.push(chars[i + 1]);
                i += 2;
                continue;
            }
            if ch == string_char {
                in_string = false;
            }
            out.push(ch);
            i += 1;
            continue;
        }

        // ---- track comment state ----
        if !in_comment && ch == '#' {
            in_comment = true;
            out.push(ch);
            i += 1;
            continue;
        }
        if in_comment {
            out.push(ch);
            if ch == '\n' {
                in_comment = false;
            }
            i += 1;
            continue;
        }

        // ---- match function definitions in free code ----
        if to_lambda {
            let boundary_ok = i == 0 || !cfs_is_ident_char(chars[i - 1]);
            if boundary_ok && i + 8 <= n {
                let keyword: String = chars[i..i + 8].iter().collect();
                if keyword == "function" {
                    let mut j = i + 8;
                    while j < n && matches!(chars[j], ' ' | '\t' | '\n' | '\r') {
                        j += 1;
                    }
                    if j < n && chars[j] == '(' {
                        if let Some(close) = cfs_matching_close(&chars, j) {
                            out.push('\\');
                            out.extend(chars[j..=close].iter());
                            i = close + 1;
                            continue;
                        }
                    }
                }
            }
        } else if ch == '\\' && i + 1 < n && chars[i + 1] == '(' {
            if let Some(close) = cfs_matching_close(&chars, i + 1) {
                out.push_str("function");
                out.extend(chars[i + 1..=close].iter());
                i = close + 1;
                continue;
            }
        }

        out.push(ch);
        i += 1;
    }

    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn lambda_and_explicit_round_trip() {
        assert_eq!(
            cfs_process_once("add_one <- function(x) x + 1", "to_lambda"),
            "add_one <- \\(x) x + 1"
        );
        assert_eq!(
            cfs_process_once("add_one <- \\(x) x + 1", "to_explicit"),
            "add_one <- function(x) x + 1"
        );
    }

    #[test]
    fn keeps_strings_and_comments() {
        let text = "f <- function(x = \"function(y)\") x # function(z)\n";
        assert_eq!(
            cfs_process_once(text, "to_lambda"),
            "f <- \\(x = \"function(y)\") x # function(z)\n"
        );
    }

    #[test]
    fn nested_needs_several_passes() {
        let text = "f <- function(x, g = function(y) y) x";
        let first = cfs_process_once(text, "to_lambda");
        assert_eq!(first, "f <- \\(x, g = function(y) y) x");
        assert_eq!(
            cfs_transform_text_rs(text, "to_lambda"),
            "f <- \\(x, g = \\(y) y) x"
        );
    }

    #[test]
    fn matching_paren() {
        assert_eq!(cfs_find_matching_paren_rs("(a(b)c)", 1), 7);
        assert_eq!(cfs_find_matching_paren_rs("(a", 1), i32::na());
        assert_eq!(cfs_find_matching_paren_rs("x(a(b)c)", 4), 6);
    }
}

extendr_module! {
    mod cfs;
    fn cfs_find_matching_paren_rs;
    fn cfs_process_text_once_rs;
    fn cfs_transform_text_rs;
}
