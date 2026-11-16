use crate::r_syntax::raw_string_end;
use extendr_api::prelude::*;

/// Rewrite the pipes of a character vector of source lines.
///
/// Rust rewrite of `rpkgkit:::.cp_process_text()`. `direction = "to_base"`
/// turns `%>%` into `|>`; every other value turns `|>` into `%>%`. Lines whose
/// first non-whitespace character is `#` are returned untouched, and occurrences
/// inside strings, raw strings and trailing comments are preserved.
/// @keywords internal
#[extendr]
pub fn cp_process_text_rs(text: Strings, direction: &str) -> Strings {
    let out: Vec<String> = text
        .iter()
        .map(|line| {
            let line: &str = line;
            if cp_is_comment_line(line) {
                line.to_string()
            } else {
                cp_rewrite_line_impl(line, direction)
            }
        })
        .collect();
    Strings::from_values(out)
}

/// Rewrite the pipes of one source line, skipping strings and comments.
/// @keywords internal
#[extendr]
pub fn cp_rewrite_line_rs(line: &str, direction: &str) -> String {
    cp_rewrite_line_impl(line, direction)
}

fn cp_is_comment_line(line: &str) -> bool {
    for c in line.chars() {
        if c == '#' {
            return true;
        }
        if !c.is_whitespace() {
            return false;
        }
    }
    false
}

fn cp_rewrite_line_impl(line: &str, direction: &str) -> String {
    let to_base = direction == "to_base";
    let chars: Vec<char> = line.chars().collect();
    let n = chars.len();
    let mut out = String::with_capacity(line.len());
    let mut i = 0usize;

    while i < n {
        let c = chars[i];

        // raw strings first, they also start with `r` / `R`
        if (c == 'r' || c == 'R') && i + 1 < n && (chars[i + 1] == '"' || chars[i + 1] == '\'') {
            if let Some(end) = raw_string_end(&chars, i) {
                out.extend(chars[i..end].iter());
                i = end;
                continue;
            }
        }

        if c == '\'' || c == '"' {
            let mut j = i + 1;
            let mut closed = false;
            while j < n {
                if chars[j] == '\\' {
                    j += 2;
                    continue;
                }
                if chars[j] == c {
                    j += 1;
                    closed = true;
                    break;
                }
                j += 1;
            }
            if closed {
                let end = j.min(n);
                out.extend(chars[i..end].iter());
                i = end;
                continue;
            }
            // Unterminated string: R's pattern does not match it either, so the
            // quote stays literal and scanning continues in free code.
            out.push(c);
            i += 1;
            continue;
        }

        if c == '#' {
            out.extend(chars[i..n].iter());
            break;
        }

        if to_base {
            if c == '%' && i + 2 < n && chars[i + 1] == '>' && chars[i + 2] == '%' {
                out.push_str("|>");
                i += 3;
                continue;
            }
        } else if c == '|' && i + 1 < n && chars[i + 1] == '>' {
            let preceded_by_percent = i > 0 && chars[i - 1] == '%';
            if !preceded_by_percent {
                out.push_str("%>%");
                i += 2;
                continue;
            }
        }

        out.push(c);
        i += 1;
    }

    out
}

extendr_module! {
    mod cp;
    fn cp_process_text_rs;
    fn cp_rewrite_line_rs;
}

#[cfg(test)]
mod tests {
    use super::{cp_is_comment_line, cp_rewrite_line_impl};

    #[test]
    fn rewrites_pipes() {
        assert_eq!(cp_rewrite_line_impl("x %>% y", "to_base"), "x |> y");
        assert_eq!(cp_rewrite_line_impl("x |> y", "to_magrittr"), "x %>% y");
        assert_eq!(cp_rewrite_line_impl("x %<>% y", "to_base"), "x %<>% y");
        assert_eq!(
            cp_rewrite_line_impl("\"a %>% b\"", "to_base"),
            "\"a %>% b\""
        );
        assert_eq!(
            cp_rewrite_line_impl("f(a) # a %>% b", "to_base"),
            "f(a) # a %>% b"
        );
        assert_eq!(cp_rewrite_line_impl("x %|>% y", "to_magrittr"), "x %|>% y");
        assert_eq!(cp_rewrite_line_impl("x %>% y", "nope"), "x %>% y");
        assert!(cp_is_comment_line("  # x %>% y"));
        assert!(!cp_is_comment_line("x # y"));
    }
}
