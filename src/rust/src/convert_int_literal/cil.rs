use std::ops::Range;

use extendr_api::prelude::*;

/// Add the explicit integer suffix `L` to bare integer literals.
///
/// Rust rewrite of `rpkgkit:::.cil_process_text()`. Strings, raw strings and
/// comments are copied verbatim; a literal is left alone when it already carries
/// `L` / `l`, when it is a float, a scientific notation, a complex literal, or
/// when it is glued to an identifier character.
///
/// A line preceded by a `# rpkgkit: not int` comment is left unchanged, so a
/// literal whose type has to stay double can be opted out line by line.
/// @keywords internal
#[extendr]
pub fn cil_process_text_rs(text: &str) -> String {
    cil_process_text_impl(text)
}

/// Comment text that suppresses the conversion of the line below it.
///
/// Compared case-insensitively, with any run of whitespace between the words.
const IGNORE_MARKER: &str = "rpkgkit: not int";

/// What to do with the numeric token starting at a given offset.
enum Literal {
    /// A bare integer: appending `L` right after these bytes is safe.
    Bare(usize),
    /// Already suffixed, or part of a float / exponent / complex / identifier.
    Other(usize),
}

impl Literal {
    /// Offset of the first byte after the token.
    fn end(&self) -> usize {
        match *self {
            Self::Bare(end) | Self::Other(end) => end,
        }
    }

    /// `true` when the token still needs the `L` suffix.
    fn is_bare(&self) -> bool {
        matches!(*self, Self::Bare(_))
    }
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

/// Offset of the `\n` ending the line that contains `pos`, or the input length.
fn line_end(b: &[u8], pos: usize) -> usize {
    b[pos..]
        .iter()
        .position(|&c| c == b'\n')
        .map_or(b.len(), |p| pos + p)
}

/// Byte range of the line following the `\n` at `newline_at`, if there is one.
fn next_line(b: &[u8], newline_at: usize) -> Option<Range<usize>> {
    let start = newline_at + 1;
    (start < b.len()).then(|| start..line_end(b, start))
}

/// `true` when nothing but whitespace precedes the comment at `hash`.
fn starts_line(b: &[u8], hash: usize) -> bool {
    b[..hash]
        .iter()
        .rev()
        .take_while(|&&c| c != b'\n')
        .all(u8::is_ascii_whitespace)
}

/// `true` when `comment` (the text after `#`) is the ignore marker.
///
/// Whitespace runs collapse to one space and the comparison ignores case, so
/// `#   RPkgkit:  not  int` is accepted as well.
fn is_ignore_marker(comment: &str) -> bool {
    let mut found = comment.split_whitespace();
    let matched = IGNORE_MARKER.split_whitespace().all(|word| {
        found
            .next()
            .is_some_and(|got| got.eq_ignore_ascii_case(word))
    });
    matched && found.next().is_none()
}

/// End offset (exclusive) of the digits at `start`, which must be a digit.
fn decimal_digits_end(b: &[u8], start: usize) -> usize {
    let mut end = start;
    while b.get(end).is_some_and(u8::is_ascii_digit) {
        end += 1;
    }
    end
}

/// End offset (exclusive) of the hex literal starting at `start`, if any.
///
/// `None` covers both "not a hex literal" (`10`, `0x`, `0xg`) and "a `0x` that
/// is only the start of something else", which the decimal rules then handle.
fn hex_digits_end(b: &[u8], start: usize) -> Option<usize> {
    if b.get(start).copied() != Some(b'0') {
        return None;
    }
    if !matches!(b.get(start + 1).copied(), Some(b'x' | b'X')) {
        return None;
    }
    let mut end = start + 2;
    while b.get(end).is_some_and(u8::is_ascii_hexdigit) {
        end += 1;
    }
    (end > start + 2).then_some(end)
}

/// Classify the numeric token starting at `start`, which must be a digit.
///
/// The caller has already checked that the previous byte is not an identifier
/// character, so an integer literal can only end at an identifier byte, a
/// digit, or the end of the input.
fn classify_literal(b: &[u8], start: usize) -> Literal {
    if let Some(end) = hex_digits_end(b, start) {
        let next = b.get(end).copied();
        let suffixed = matches!(next, Some(b'L' | b'l'));
        let glued = next.is_some_and(is_ident_byte);
        // `0x1i` is complex and `0xFFz` is an identifier: only a suffix, an
        // identifier character or the end of input can follow a hex literal.
        if next != Some(b'i') && (!glued || suffixed) {
            return if suffixed {
                Literal::Other(end)
            } else {
                Literal::Bare(end)
            };
        }
    }

    let end = decimal_digits_end(b, start);
    // Digits completing a numeric literal (`.5`, `1e3`, `10i`, `10L`) must not
    // be treated as integers on their own, and neither must the digits of a
    // signed exponent split off by an earlier token.
    let in_exponent = start > 0 && matches!(b[start - 1], b'+' | b'-') && is_exp_digits(b, start);
    let glued = b.get(end).is_some_and(|&c| is_ident_byte(c));
    if in_exponent || glued {
        Literal::Other(end)
    } else {
        Literal::Bare(end)
    }
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
    // Line opted out with a `# rpkgkit: not int` comment on the line above.
    let mut opt_out: Option<Range<usize>> = None;

    while i < n {
        match b[i] {
            // ---- comment: skip to the end of the line ----
            b'#' => {
                let end = line_end(b, i);
                if starts_line(b, i) && is_ignore_marker(&text[i + 1..end]) {
                    opt_out = next_line(b, end);
                }
                i = end + 1;
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
                let literal = classify_literal(b, i);
                let end = literal.end();
                let opted_out = opt_out.as_ref().is_some_and(|line| line.contains(&i));
                if literal.is_bare() && !opted_out {
                    out.push_str(&text[last..end]);
                    out.push('L');
                    last = end;
                }
                i = end;
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

    #[test]
    fn ignores_the_line_below_the_marker() {
        assert_eq!(
            cil_process_text_impl("# rpkgkit: not int\nx <- 2^31"),
            "# rpkgkit: not int\nx <- 2^31"
        );
    }

    #[test]
    fn the_marker_only_covers_the_next_line() {
        assert_eq!(
            cil_process_text_impl("# rpkgkit: not int\nx <- 2\ny <- 3"),
            "# rpkgkit: not int\nx <- 2\ny <- 3L"
        );
    }

    #[test]
    fn the_marker_skips_every_literal_on_the_opted_out_line() {
        assert_eq!(
            cil_process_text_impl("# rpkgkit: not int\nx <- c(1, 0xFF, 2L)"),
            "# rpkgkit: not int\nx <- c(1, 0xFF, 2L)"
        );
    }

    #[test]
    fn the_marker_tolerates_indentation_case_and_spacing() {
        assert_eq!(
            cil_process_text_impl("  #   RPkgkit:\tNOT  int  \nx <- 5"),
            "  #   RPkgkit:\tNOT  int  \nx <- 5"
        );
    }

    #[test]
    fn chained_markers_keep_marking_the_next_line() {
        assert_eq!(
            cil_process_text_impl("# rpkgkit: not int\n# rpkgkit: not int\nx <- 5"),
            "# rpkgkit: not int\n# rpkgkit: not int\nx <- 5"
        );
    }

    #[test]
    fn a_trailing_marker_does_not_cover_its_own_line() {
        assert_eq!(
            cil_process_text_impl("x <- 5 # rpkgkit: not int\ny <- 6"),
            "x <- 5L # rpkgkit: not int\ny <- 6L"
        );
    }

    #[test]
    fn a_marker_inside_a_string_is_not_a_marker() {
        assert_eq!(
            cil_process_text_impl("x <- \"\n# rpkgkit: not int\"\ny <- 5"),
            "x <- \"\n# rpkgkit: not int\"\ny <- 5L"
        );
    }

    #[test]
    fn a_marker_on_the_last_line_has_no_effect() {
        assert_eq!(
            cil_process_text_impl("x <- 5\n# rpkgkit: not int"),
            "x <- 5L\n# rpkgkit: not int"
        );
        assert_eq!(
            cil_process_text_impl("# rpkgkit: not int"),
            "# rpkgkit: not int"
        );
    }

    #[test]
    fn the_marker_survives_a_second_pass() {
        let once = cil_process_text_impl("# rpkgkit: not int\nx <- 2\ny <- 3");
        assert_eq!(cil_process_text_impl(&once), once);
    }
}
