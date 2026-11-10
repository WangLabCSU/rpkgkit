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

fn cil_process_text_impl(text: &str) -> String {
    let chars: Vec<char> = text.chars().collect();
    let nc = chars.len();
    let is_ident = |c: char| c.is_ascii_alphanumeric() || c == '.' || c == '_';
    let is_digit = |c: char| c.is_ascii_digit();

    // Are the digits starting at `pos` the exponent of a numeric literal?
    // Covers signed exponents (`1e-3`) and float mantissas (`1.5e3`).
    let is_exp_digits = |pos: usize| -> bool {
        if pos < 2 {
            return false;
        }
        let k = if chars[pos - 1] == '+' || chars[pos - 1] == '-' {
            if pos < 2 {
                return false;
            }
            pos - 2
        } else {
            pos - 1
        };
        if k < 1 || (chars[k] != 'e' && chars[k] != 'E') {
            return false;
        }
        let mantissa_end = k - 1;
        if !(is_digit(chars[mantissa_end]) || chars[mantissa_end] == '.') {
            return false;
        }
        let mut b = mantissa_end as isize;
        while b >= 0 && is_digit(chars[b as usize]) {
            b -= 1;
        }
        // `0x1e-3` is a hex literal minus an integer, not a numeric exponent.
        !(b > 0
            && (chars[b as usize] == 'x' || chars[b as usize] == 'X')
            && chars[(b - 1) as usize] == '0')
    };

    let mut result = String::with_capacity(text.len() + 16);
    let mut in_string = false;
    let mut string_char = '\0';
    let mut in_comment = false;
    let mut in_raw_string = false;
    let mut raw_dash_n = 0usize;
    let mut raw_close = '\0';

    let mut i = 0usize;
    while i < nc {
        let ch = chars[i];

        // ---- raw strings: r"..." / R"..." with optional dashes ----
        if !in_comment
            && !in_string
            && !in_raw_string
            && (ch == 'r' || ch == 'R')
            && i + 1 < nc
            && (chars[i + 1] == '\'' || chars[i + 1] == '"')
        {
            let quote = chars[i + 1];
            let mut k = i + 2;
            let mut dashes = 0usize;
            while k < nc && chars[k] == '-' {
                dashes += 1;
                k += 1;
            }
            if k < nc && chars[k] == '(' {
                in_raw_string = true;
                raw_dash_n = dashes;
                raw_close = quote;
                result.extend(chars[i..=k].iter());
                i = k + 1;
                continue;
            }
        }

        if in_raw_string {
            // look for `)---"` with the same dash count
            if ch == ')' {
                let mut ok = true;
                for d in 1..=raw_dash_n {
                    if i + d >= nc || chars[i + d] != '-' {
                        ok = false;
                        break;
                    }
                }
                let qpos = i + raw_dash_n + 1;
                if ok && qpos < nc && chars[qpos] == raw_close {
                    result.extend(chars[i..=qpos].iter());
                    i = qpos + 1;
                    in_raw_string = false;
                    continue;
                }
            }
            result.push(ch);
            i += 1;
            continue;
        }

        // ---- track string state ----
        if !in_comment && !in_string && (ch == '\'' || ch == '"') {
            in_string = true;
            string_char = ch;
            result.push(ch);
            i += 1;
            continue;
        }
        if in_string {
            if ch == '\\' && i + 1 < nc {
                result.push(ch);
                result.push(chars[i + 1]);
                i += 2;
                continue;
            }
            if ch == string_char {
                in_string = false;
            }
            result.push(ch);
            i += 1;
            continue;
        }

        // ---- track comment state ----
        if !in_comment && ch == '#' {
            in_comment = true;
            result.push(ch);
            i += 1;
            continue;
        }
        if in_comment {
            result.push(ch);
            if ch == '\n' {
                in_comment = false;
            }
            i += 1;
            continue;
        }

        // ---- integer literals ----
        let prev_ok = i == 0 || !is_ident(chars[i - 1]);

        // hex: 0x / 0X followed by hex digits
        if prev_ok && ch == '0' && i + 1 < nc && (chars[i + 1] == 'x' || chars[i + 1] == 'X') {
            let mut j = i + 2;
            while j < nc && chars[j].is_ascii_hexdigit() {
                j += 1;
            }
            if j > i + 2 {
                let has_l = j < nc && (chars[j] == 'L' || chars[j] == 'l');
                let has_i = j < nc && chars[j] == 'i';
                let next_ident = j < nc && is_ident(chars[j]) && !has_l && !has_i;
                if !next_ident && !has_i {
                    result.extend(chars[i..j].iter());
                    if has_l {
                        result.push(chars[j]);
                        j += 1;
                    } else {
                        result.push('L');
                    }
                    i = j;
                    continue;
                }
            }
        }

        // decimal digits
        if prev_ok && is_digit(ch) {
            let mut j = i;
            while j < nc && is_digit(chars[j]) {
                j += 1;
            }

            let nxt = if j < nc { Some(chars[j]) } else { None };
            let is_float = nxt == Some('.');
            let is_exp = nxt == Some('e') || nxt == Some('E');
            let is_complex = nxt == Some('i');
            let has_l = nxt == Some('L') || nxt == Some('l');
            let next_ident = match nxt {
                Some(c) => is_ident(c) && !has_l && !is_complex && !is_exp,
                None => false,
            };

            // Digits that complete a numeric literal must not be treated as
            // integers on their own.
            if is_exp_digits(i) {
                result.extend(chars[i..j].iter());
                i = j;
                continue;
            }

            // `1.2` / `1e3` / `10i` / glued identifier -> leave as-is
            if !is_float && !is_exp && !is_complex && !next_ident {
                result.extend(chars[i..j].iter());
                if has_l {
                    result.push(chars[j]);
                    j += 1;
                } else {
                    result.push('L');
                }
                i = j;
                continue;
            }
        }

        result.push(ch);
        i += 1;
    }

    result
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
}
