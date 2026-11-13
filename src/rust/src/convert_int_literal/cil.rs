use extendr_api::prelude::*;

/// Add the explicit integer suffix `L` to bare integer literals.
///
/// Rust rewrite of `rpkgkit:::.cil_process_text()`. Strings, raw strings and
/// comments are copied verbatim; a literal is left alone when it already carries
/// `L` / `l`, when it is a float, a scientific notation, a complex literal, or
/// when it is glued to an identifier character.
/// @keywords internal
#[extendr]
pub fn cil_process_text_rs(text: &str) -> String {
    cil_process_text_impl(text)
}

/// Is `c` a character that glues a literal to an identifier?
///
/// ASCII alphanumerics, `.` and `_` are identifier characters in R, and so is
/// everything outside ASCII (`变量1`): each byte of a multi-byte UTF-8 sequence
/// is `>= 0x80`, so no decoding is needed here.
#[inline]
fn is_ident_byte(c: u8) -> bool {
    c.is_ascii_alphanumeric() || c == b'.' || c == b'_' || c >= 0x80
}

/// Are the digits starting at `pos` the exponent of a numeric literal?
///
/// Only meaningful when `b[pos - 1]` is `+` or `-`: an unsigned exponent is
/// already skipped by the caller, because `e` / `E` are identifier characters
/// and therefore fail the "previous byte is not an identifier byte" test.
fn is_exp_digits(b: &[u8], pos: usize) -> bool {
    if pos < 3 {
        return false;
    }
    let sign = b[pos - 1];
    if sign != b'+' && sign != b'-' {
        return false;
    }
    let k = pos - 2;
    if b[k] != b'e' && b[k] != b'E' {
        return false;
    }
    let mantissa_end = k - 1;
    if !(b[mantissa_end].is_ascii_digit() || b[mantissa_end] == b'.') {
        return false;
    }
    let mut p = mantissa_end;
    while p > 0 && b[p].is_ascii_digit() {
        p -= 1;
    }
    // `0x1e-3` is a hex literal minus an integer, not a numeric exponent.
    !(p > 0 && (b[p] == b'x' || b[p] == b'X') && b[p - 1] == b'0')
}

/// End offset (exclusive) of the raw string opening at `start`, if any.
///
/// Raw strings look like `r"(...)"`, `R"---(...)---"`: a quote, optional dashes,
/// an opening parenthesis, and a closing `)` + the same number of dashes + the
/// same quote. Returns `Some(b.len())` when the string is never closed, since
/// the whole remainder is then copied verbatim. `None` means "not a raw
/// string", and the byte at `start` is an ordinary identifier character.
fn raw_string_end(b: &[u8], start: usize) -> Option<usize> {
    let n = b.len();
    if start > 0 && is_ident_byte(b[start - 1]) {
        return None;
    }
    let quote = *b.get(start + 1)?;
    if quote != b'"' && quote != b'\'' {
        return None;
    }
    let mut k = start + 2;
    while k < n && b[k] == b'-' {
        k += 1;
    }
    if k >= n || b[k] != b'(' {
        return None;
    }
    let dashes = k - start - 2;
    let mut j = k + 1;
    while j < n {
        if b[j] == b')'
            && j + dashes + 1 < n
            && b[j + 1..j + 1 + dashes].iter().all(|&c| c == b'-')
            && b[j + dashes + 1] == quote
        {
            return Some(j + dashes + 2);
        }
        j += 1;
    }
    Some(n)
}

// The scan works on raw bytes: every syntactic character (`"`, `'`, `#`, `(`,
// `-`, digits, `e`, `x`, ...) is ASCII, and ASCII bytes never appear inside a
// multi-byte UTF-8 sequence, so byte-wise matching cannot split a character and
// no `Vec<char>` copy of the input is needed.
fn cil_process_text_impl(text: &str) -> String {
    let b = text.as_bytes();
    let n = b.len();
    let mut out = String::with_capacity(n + n / 8 + 16);
    // Everything before `last` has been written out; `out` is flushed lazily so
    // that a run of text needing no suffix costs one `push_str` (a memcpy).
    let mut last = 0usize;
    let mut i = 0usize;

    while i < n {
        match b[i] {
            // ---- comment: skip to the end of the line ----
            b'#' => {
                i = b[i..]
                    .iter()
                    .position(|&c| c == b'\n')
                    .map_or(n, |p| i + p + 1);
            }

            // ---- string: skip to the matching unescaped quote ----
            q @ (b'"' | b'\'') => {
                i += 1;
                while i < n {
                    if b[i] == b'\\' {
                        i += 2;
                    } else if b[i] == q {
                        i += 1;
                        break;
                    } else {
                        i += 1;
                    }
                }
            }

            // ---- raw string: skip to `)` + dashes + quote ----
            b'r' | b'R' => {
                i = raw_string_end(b, i).unwrap_or(i + 1);
            }

            // ---- integer literals ----
            c if c.is_ascii_digit() && (i == 0 || !is_ident_byte(b[i - 1])) => {
                // hex: 0x / 0X followed by hex digits
                if c == b'0' && i + 1 < n && (b[i + 1] == b'x' || b[i + 1] == b'X') {
                    let mut j = i + 2;
                    while j < n && b[j].is_ascii_hexdigit() {
                        j += 1;
                    }
                    if j > i + 2 {
                        let has_l = j < n && (b[j] == b'L' || b[j] == b'l');
                        let has_i = j < n && b[j] == b'i';
                        let glued = j < n && is_ident_byte(b[j]);
                        if !has_i && (!glued || has_l) {
                            if !has_l {
                                out.push_str(&text[last..j]);
                                out.push('L');
                                last = j;
                            }
                            i = j;
                            continue;
                        }
                    }
                }

                // decimal digits
                let mut j = i;
                while j < n && b[j].is_ascii_digit() {
                    j += 1;
                }
                let nxt = if j < n { Some(b[j]) } else { None };
                let is_float = nxt == Some(b'.');
                let is_exp = nxt == Some(b'e') || nxt == Some(b'E');
                let is_complex = nxt == Some(b'i');
                let has_l = nxt == Some(b'L') || nxt == Some(b'l');
                let next_ident = match nxt {
                    Some(c) => is_ident_byte(c) && !has_l && !is_complex && !is_exp,
                    None => false,
                };

                // Digits that complete a numeric literal must not be treated as
                // integers on their own.
                let in_exponent =
                    i > 0 && (b[i - 1] == b'+' || b[i - 1] == b'-') && is_exp_digits(b, i);

                // `1.2` / `1e3` / `10i` / glued identifier -> leave as-is;
                // otherwise append `L` unless the literal already carries one.
                if !in_exponent && !is_float && !is_exp && !is_complex && !next_ident && !has_l {
                    out.push_str(&text[last..j]);
                    out.push('L');
                    last = j;
                }
                i = j;
            }

            // Only `#`, quotes, `r` / `R` and digits can change the output.
            _ => i += 1,
        }
    }

    out.push_str(&text[last..]);
    out
}

extendr_module! {
    mod cil;
    fn cil_process_text_rs;
}

#[cfg(test)]
mod tests {
    use super::cil_process_text_impl;

    #[test]
    fn adds_integer_suffix() {
        assert_eq!(cil_process_text_impl("seq_len(10)"), "seq_len(10L)");
        assert_eq!(cil_process_text_impl("x <- 0xFF"), "x <- 0xFFL");
        assert_eq!(cil_process_text_impl("x <- 10L"), "x <- 10L");
        assert_eq!(cil_process_text_impl("x <- 1.5"), "x <- 1.5");
        assert_eq!(cil_process_text_impl("x <- 1e-3"), "x <- 1e-3");
        assert_eq!(cil_process_text_impl("x <- 10i"), "x <- 10i");
        assert_eq!(cil_process_text_impl("a10"), "a10");
        assert_eq!(cil_process_text_impl("# 10"), "# 10");
        assert_eq!(cil_process_text_impl("\"10\""), "\"10\"");
        assert_eq!(cil_process_text_impl("r\"(10)\""), "r\"(10)\"");
    }

    #[test]
    fn batch_flush_keeps_the_original_text() {
        let text = "x <- c(1, 2.5, 0xFF, 3L)\ny <- 'a10b' # 10\nz <- 1e-3 + 4";
        assert_eq!(
            cil_process_text_impl(text),
            "x <- c(1L, 2.5, 0xFFL, 3L)\ny <- 'a10b' # 10\nz <- 1e-3 + 4L"
        );
    }

    #[test]
    fn skips_comments_before_strings() {
        // A quote inside a comment must not open a string.
        assert_eq!(cil_process_text_impl("x <- 1 # it's 5"), "x <- 1L # it's 5");
        assert_eq!(cil_process_text_impl("x <- 1 # \" 5"), "x <- 1L # \" 5");
    }

    #[test]
    fn skips_strings_before_comments() {
        // A `#` inside a string must not open a comment.
        assert_eq!(
            cil_process_text_impl("x <- \"a # 5\" ; f(2)"),
            "x <- \"a # 5\" ; f(2L)"
        );
    }

    #[test]
    fn handles_escaped_quotes_and_raw_strings() {
        assert_eq!(
            cil_process_text_impl("x <- \"a\\\"10\\\"\" ; f(5)"),
            "x <- \"a\\\"10\\\"\" ; f(5L)"
        );
        assert_eq!(
            cil_process_text_impl("x <- r\"---(10)---\" ; f(5)"),
            "x <- r\"---(10)---\" ; f(5L)"
        );
        // Unterminated raw string: the rest of the input is copied verbatim.
        assert_eq!(cil_process_text_impl("r\"(10)"), "r\"(10)");
    }

    #[test]
    fn treats_non_ascii_bytes_as_identifier_chars() {
        assert_eq!(cil_process_text_impl("变量1 <- 2"), "变量1 <- 2L");
        assert_eq!(cil_process_text_impl("x <- 变量1 + 1"), "x <- 变量1 + 1L");
    }

    #[test]
    fn keeps_hex_and_exponent_edge_cases() {
        assert_eq!(cil_process_text_impl("x <- 0x1e-3"), "x <- 0x1eL-3L");
        assert_eq!(cil_process_text_impl("x <- 1e3-1e2"), "x <- 1e3-1e2");
        assert_eq!(cil_process_text_impl("x <- .5e-3"), "x <- .5e-3");
        assert_eq!(cil_process_text_impl("x <- 1_000"), "x <- 1_000");
        assert_eq!(cil_process_text_impl("x <- 0xzz"), "x <- 0xzz");
    }
}
