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
    let b: Vec<u8> = text.as_bytes().to_vec();
    let start = (open_pos - 1).max(0) as usize;
    match cfs_matching_close(&b, start) {
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

fn cfs_is_ident(c: u8) -> bool {
    c.is_ascii_alphanumeric() || c == b'.' || c == b'_'
}

/// 0-based index of the matching `)` for the `(` at `open` (0-based).
fn cfs_matching_close(b: &[u8], open: usize) -> Option<usize> {
    let mut depth = 0i32;
    for (k, &c) in b.iter().enumerate().skip(open) {
        match c {
            b'(' => depth += 1,
            b')' => {
                depth -= 1;
                if depth == 0 {
                    return Some(k);
                }
            }
            _ => {}
        }
    }
    None
}

fn cfs_process_once(text: &str, direction: &str) -> String {
    let to_lambda = direction == "to_lambda";
    let b = text.as_bytes();
    let n = b.len();
    let mut out = String::with_capacity(n);
    let (mut i, mut last) = (0usize, 0usize);

    while i < n {
        match b[i] {
            q @ (b'\'' | b'"') => {
                i += 1;
                while i < n && b[i] != q {
                    if b[i] == b'\\' {
                        i += 1;
                    }
                    i += 1;
                }
                i = (i + 1).min(n);
            }
            b'#' => {
                while i < n && b[i] != b'\n' {
                    i += 1;
                }
            }
            b'f' if to_lambda
                && (i == 0 || !cfs_is_ident(b[i - 1]))
                && b[i..].starts_with(b"function") =>
            {
                let mut j = i + 8;
                while j < n && matches!(b[j], b' ' | b'\t' | b'\n' | b'\r') {
                    j += 1;
                }
                if j < n && b[j] == b'(' {
                    if let Some(c) = cfs_matching_close(b, j) {
                        out.push_str(&text[last..i]);
                        out.push('\\');
                        out.push_str(&text[j..=c]);
                        i = c + 1;
                        last = i;
                        continue;
                    }
                }
                i += 1;
            }
            b'\\' if !to_lambda && i + 1 < n && b[i + 1] == b'(' => {
                if let Some(c) = cfs_matching_close(b, i + 1) {
                    out.push_str(&text[last..i]);
                    out.push_str("function");
                    out.push_str(&text[i + 1..=c]);
                    i = c + 1;
                    last = i;
                    continue;
                }
                i += 1;
            }
            _ => i += 1,
        }
    }
    out.push_str(&text[last..]);
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
