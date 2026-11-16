//! Minimal, dependency-free R tokenizer shared by the checker rewrites.
//!
//! The R implementations of the checkers built their logic on
//! `utils::getParseData()`. The Rust rewrites must not call back into R, so this
//! module provides the small amount of R lexis they need: comments, ordinary
//! strings, raw strings, backtick names, numbers, identifiers and operators,
//! each token carrying its byte span and its 1-based line/column range.
//!
//! This is intentionally *not* a parser. It only guarantees that the token
//! stream never mistakes the content of a string, a raw string or a comment for
//! code, which is what the checkers need in order to stay free of false
//! positives.

/// Token kinds produced by [`tokenize()`].
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Kind {
    /// Symbol, e.g. `mean`, `x.1`, `..2`.
    Ident,
    /// Numeric literal, e.g. `1`, `2.5`, `1e-3`, `0xFF`, `3L`, `1i`.
    Num,
    /// Ordinary single- or double-quoted string.
    Str,
    /// R 4.0 raw string, e.g. `r"(...)"`.
    RawStr,
    /// Backtick name, e.g. `` `my name` ``.
    Backtick,
    /// `#` comment running to (but excluding) the end of the line.
    Comment,
    /// Operator or punctuation, e.g. `<-`, `::`, `%>%`, `(`, `,`.
    Op,
}

/// A single lexical token with its source position.
#[derive(Clone, Debug)]
pub struct Token {
    /// Byte offset of the first character.
    pub start: usize,
    /// Byte offset just past the last character.
    pub end: usize,
    /// 1-based line of the first character.
    pub line1: i32,
    /// 1-based column of the first character.
    pub col1: i32,
    /// 1-based line of the last character.
    pub line2: i32,
    /// 1-based column of the last character.
    pub col2: i32,
    /// Lexical kind.
    pub kind: Kind,
}

impl Token {
    /// Source text of the token.
    pub fn text<'a>(&self, src: &'a str) -> &'a str {
        &src[self.start..self.end]
    }

    /// `true` when the token is the operator `op`.
    pub fn is_op(&self, src: &str, op: &str) -> bool {
        self.kind == Kind::Op && self.text(src) == op
    }

    /// `true` when the token is the identifier `name`.
    pub fn is_ident(&self, src: &str, name: &str) -> bool {
        self.kind == Kind::Ident && self.text(src) == name
    }

    /// `true` for a closing bracket.
    pub fn is_close(&self, src: &str) -> bool {
        self.kind == Kind::Op && matches!(self.text(src), ")" | "]" | "}")
    }
}

fn is_ident_start(c: char) -> bool {
    c.is_alphabetic() || c == '.' || c == '_'
}

fn is_ident_continue(c: char) -> bool {
    c.is_alphanumeric() || c == '.' || c == '_'
}

fn advance(ch: char, line: &mut i32, col: &mut i32) {
    if ch == '\n' {
        *line += 1;
        *col = 1;
    } else {
        *col += 1;
    }
}

/// Exclusive end index of the R raw string starting at `start`.
///
/// `start` must point at the `r` / `R`. Returns `None` when the sequence is not
/// a raw string opener. An unterminated raw string extends to the end of the
/// input, mirroring R's own lexer.
pub fn raw_string_end(chars: &[char], start: usize) -> Option<usize> {
    let n = chars.len();
    if start + 1 >= n {
        return None;
    }
    let quote = chars[start + 1];
    if quote != '"' && quote != '\'' {
        return None;
    }
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
    let mut m = k + 1;
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
                return Some(p + 1);
            }
        }
        m += 1;
    }
    Some(n)
}

fn number_end(chars: &[char], start: usize) -> usize {
    let n = chars.len();
    if chars[start] == '0' && start + 1 < n && (chars[start + 1] == 'x' || chars[start + 1] == 'X')
    {
        let mut j = start + 2;
        while j < n && chars[j].is_ascii_hexdigit() {
            j += 1;
        }
        if j < n && (chars[j] == 'L' || chars[j] == 'l' || chars[j] == 'i') {
            j += 1;
        }
        return j;
    }

    let mut j = start;
    while j < n && chars[j].is_ascii_digit() {
        j += 1;
    }
    if j < n && chars[j] == '.' {
        j += 1;
        while j < n && chars[j].is_ascii_digit() {
            j += 1;
        }
    }
    if j < n && (chars[j] == 'e' || chars[j] == 'E') {
        let mut k = j + 1;
        if k < n && (chars[k] == '+' || chars[k] == '-') {
            k += 1;
        }
        if k < n && chars[k].is_ascii_digit() {
            while k < n && chars[k].is_ascii_digit() {
                k += 1;
            }
            j = k;
        }
    }
    if j < n && (chars[j] == 'L' || chars[j] == 'l' || chars[j] == 'i') {
        j += 1;
    }
    j
}

fn op_end(chars: &[char], start: usize) -> usize {
    let n = chars.len();
    let at = |k: usize| -> char {
        if k < n {
            chars[k]
        } else {
            '\0'
        }
    };
    let c = chars[start];

    // `%...%` user operators (`%>%`, `%in%`, `%||%`, ...).
    if c == '%' {
        let mut j = start + 1;
        while j < n && chars[j] != '%' && chars[j] != '\n' {
            j += 1;
        }
        if j < n && chars[j] == '%' {
            return j + 1;
        }
        return start + 1;
    }

    let three = matches!(
        (c, at(start + 1), at(start + 2)),
        ('<', '<', '-') | ('-', '>', '>') | (':', ':', ':')
    );
    if three {
        return start + 3;
    }

    let two = matches!(
        (c, at(start + 1)),
        ('<', '-')
            | ('-', '>')
            | (':', ':')
            | (':', '=')
            | ('=', '=')
            | ('!', '=')
            | ('<', '=')
            | ('>', '=')
            | ('&', '&')
            | ('|', '|')
            | ('|', '>')
            | ('*', '*')
            | ('=', '>')
            | ('^', '^')
    );
    if two {
        return start + 2;
    }

    start + 1
}

#[allow(clippy::too_many_arguments)]
fn push_token(
    out: &mut Vec<Token>,
    chars: &[char],
    bytes: &[usize],
    src_len: usize,
    kind: Kind,
    from: usize,
    to: usize,
    line: &mut i32,
    col: &mut i32,
) {
    let line1 = *line;
    let col1 = *col;
    let mut line2 = *line;
    let mut col2 = *col;
    for ch in chars.iter().take(to).skip(from) {
        line2 = *line;
        col2 = *col;
        advance(*ch, line, col);
    }
    let end = if to < bytes.len() { bytes[to] } else { src_len };
    out.push(Token {
        start: bytes[from],
        end,
        line1,
        col1,
        line2,
        col2,
        kind,
    });
}

/// Tokenize `text`.
///
/// Whitespace is dropped; comments are kept as [`Kind::Comment`] tokens so that
/// callers can decide whether to skip them.
pub fn tokenize(text: &str) -> Vec<Token> {
    let chars: Vec<char> = text.chars().collect();
    let bytes: Vec<usize> = text.char_indices().map(|(idx, _)| idx).collect();
    let n = chars.len();
    let src_len = text.len();
    let mut out: Vec<Token> = Vec::new();
    let mut line = 1i32;
    let mut col = 1i32;
    let mut i = 0usize;

    while i < n {
        let c = chars[i];

        if c.is_whitespace() {
            advance(c, &mut line, &mut col);
            i += 1;
            continue;
        }

        if c == '#' {
            let mut j = i;
            while j < n && chars[j] != '\n' {
                j += 1;
            }
            push_token(
                &mut out,
                &chars,
                &bytes,
                src_len,
                Kind::Comment,
                i,
                j,
                &mut line,
                &mut col,
            );
            i = j;
            continue;
        }

        if (c == 'r' || c == 'R') && i + 1 < n && (chars[i + 1] == '"' || chars[i + 1] == '\'') {
            if let Some(end) = raw_string_end(&chars, i) {
                push_token(
                    &mut out,
                    &chars,
                    &bytes,
                    src_len,
                    Kind::RawStr,
                    i,
                    end,
                    &mut line,
                    &mut col,
                );
                i = end;
                continue;
            }
        }

        if c == '"' || c == '\'' {
            let mut j = i + 1;
            while j < n {
                if chars[j] == '\\' {
                    j += 2;
                    continue;
                }
                if chars[j] == c {
                    j += 1;
                    break;
                }
                j += 1;
            }
            let end = j.min(n);
            push_token(
                &mut out,
                &chars,
                &bytes,
                src_len,
                Kind::Str,
                i,
                end,
                &mut line,
                &mut col,
            );
            i = end;
            continue;
        }

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
            push_token(
                &mut out,
                &chars,
                &bytes,
                src_len,
                Kind::Backtick,
                i,
                end,
                &mut line,
                &mut col,
            );
            i = end;
            continue;
        }

        let number_start =
            c.is_ascii_digit() || (c == '.' && i + 1 < n && chars[i + 1].is_ascii_digit());
        if number_start {
            let end = number_end(&chars, i);
            push_token(
                &mut out,
                &chars,
                &bytes,
                src_len,
                Kind::Num,
                i,
                end,
                &mut line,
                &mut col,
            );
            i = end;
            continue;
        }

        if is_ident_start(c) {
            let mut j = i + 1;
            while j < n && is_ident_continue(chars[j]) {
                j += 1;
            }
            push_token(
                &mut out,
                &chars,
                &bytes,
                src_len,
                Kind::Ident,
                i,
                j,
                &mut line,
                &mut col,
            );
            i = j;
            continue;
        }

        let end = op_end(&chars, i);
        push_token(
            &mut out,
            &chars,
            &bytes,
            src_len,
            Kind::Op,
            i,
            end,
            &mut line,
            &mut col,
        );
        i = end;
    }

    out
}

/// Index of the next token that is not a comment, starting at `from`.
pub fn next_sig(tokens: &[Token], from: usize) -> Option<usize> {
    let mut k = from;
    while k < tokens.len() {
        if tokens[k].kind != Kind::Comment {
            return Some(k);
        }
        k += 1;
    }
    None
}

/// Index of the previous token that is not a comment, starting at `from - 1`.
pub fn prev_sig(tokens: &[Token], from: usize) -> Option<usize> {
    let mut k = from;
    while k > 0 {
        k -= 1;
        if tokens[k].kind != Kind::Comment {
            return Some(k);
        }
    }
    None
}

/// Index of the bracket closing the one opened at `open`.
pub fn matching_close(tokens: &[Token], src: &str, open: usize) -> Option<usize> {
    let mut depth = 0i32;
    for (k, tok) in tokens.iter().enumerate().skip(open) {
        if tok.kind != Kind::Op {
            continue;
        }
        match tok.text(src) {
            "(" | "[" | "{" => depth += 1,
            ")" | "]" | "}" => {
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

/// Token-index ranges `[start, end)` of the top-level arguments between the
/// brackets at `open` and `close`.
///
/// Empty arguments (a trailing comma) are returned as empty ranges; callers
/// should drop them.
pub fn split_args(tokens: &[Token], src: &str, open: usize, close: usize) -> Vec<(usize, usize)> {
    let mut out: Vec<(usize, usize)> = Vec::new();
    let mut start = open + 1;
    let mut depth = 0i32;
    for (k, tok) in tokens.iter().enumerate().take(close).skip(open + 1) {
        if tok.kind != Kind::Op {
            continue;
        }
        match tok.text(src) {
            "(" | "[" | "{" => depth += 1,
            ")" | "]" | "}" => depth -= 1,
            "," if depth == 0 => {
                out.push((start, k));
                start = k + 1;
            }
            _ => {}
        }
    }
    out.push((start, close));
    out
}

/// Drop leading and trailing comment tokens from a token range.
pub fn trim_range(tokens: &[Token], from: usize, to: usize) -> Option<(usize, usize)> {
    let mut a = from;
    while a < to && tokens[a].kind == Kind::Comment {
        a += 1;
    }
    let mut b = to;
    while b > a && tokens[b - 1].kind == Kind::Comment {
        b -= 1;
    }
    if a >= b {
        None
    } else {
        Some((a, b))
    }
}

/// `base::trimws()` with the default `[ \t\r\n]` character set.
pub fn trim_ws(s: &str) -> &str {
    s.trim_matches(|c| matches!(c, ' ' | '\t' | '\r' | '\n' | '\u{b}'))
}

/// `gsub("^[`\"']|[`\"']$", "", s)`: strip one pair of surrounding quotes.
pub fn strip_name(s: &str) -> String {
    let chars: Vec<char> = s.chars().collect();
    if chars.len() < 2 {
        return s.to_string();
    }
    let first = chars[0];
    let last = chars[chars.len() - 1];
    let is_quote = |c: char| c == '`' || c == '"' || c == '\'';
    if is_quote(first) && is_quote(last) {
        chars[1..chars.len() - 1].iter().collect()
    } else {
        s.to_string()
    }
}

/// Replace every `\s*\n\s*` run with a single space, like
/// `gsub("\\s*\n\\s*", " ", x)`.
pub fn collapse_newlines(s: &str) -> String {
    let chars: Vec<char> = s.chars().collect();
    let mut out = String::new();
    let mut i = 0usize;
    while i < chars.len() {
        if chars[i] == '\n' {
            while out.ends_with(' ') || out.ends_with('\t') || out.ends_with('\r') {
                out.pop();
            }
            out.push(' ');
            i += 1;
            while i < chars.len() && matches!(chars[i], ' ' | '\t' | '\r') {
                i += 1;
            }
        } else {
            out.push(chars[i]);
            i += 1;
        }
    }
    out
}
