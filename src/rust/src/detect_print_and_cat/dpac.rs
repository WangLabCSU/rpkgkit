use crate::r_syntax::{
    matching_close, next_sig, prev_sig, split_args, strip_name, tokenize, trim_range, Kind, Token,
};
use extendr_api::prelude::*;
use extendr_api::Result;
use regex::Regex;

/// One reported `print()` / `cat()` occurrence.
struct Hit {
    line1: i32,
    col1: i32,
    col2: i32,
    text: String,
    kind: &'static str,
}

/// Locate unsupported `print()` / `cat()` calls in R source text.
///
/// Tokenizer of `crate::r_syntax` is used, so R's parser is not needed. Each
/// hit is a list with `line1`, `col1`, `col2`, `text`, `type` and `kind`.
/// @keywords internal
#[extendr]
pub fn dpac_find_calls_rs(
    text: &str,
    pattern_fn_names: Strings,
    include_s3: bool,
    include_refs: bool,
) -> Result<List> {
    let mut patterns: Vec<Regex> = Vec::new();
    let mut invalid: Vec<String> = Vec::new();
    for pattern in pattern_fn_names.iter() {
        let pattern: &str = pattern;
        match Regex::new(pattern) {
            Ok(re) => patterns.push(re),
            Err(_) => invalid.push(pattern.to_string()),
        }
    }
    if !invalid.is_empty() {
        return Err(format!(
            "`pattern_fn_names` contains invalid regular expressions: {}",
            invalid.join(", ")
        )
        .into());
    }

    let tokens = tokenize(text);
    let mut hits: Vec<Hit> = Vec::new();

    for k in 0..tokens.len() {
        let tok = &tokens[k];
        let name = match dpac_callable_name(tok, text) {
            Some(name) => name,
            None => continue,
        };
        if name != "print" && name != "cat" {
            continue;
        }

        let open = match next_sig(&tokens, k + 1) {
            Some(idx) => idx,
            None => continue,
        };
        if !tokens[open].is_op(text, "(") {
            continue;
        }
        // `x$print(...)` and `x@print(...)` extract a function, they do not call
        // the global `print()`.
        if let Some(prev) = prev_sig(&tokens, k) {
            if tokens[prev].is_op(text, "$") || tokens[prev].is_op(text, "@") {
                continue;
            }
        }

        let close = match matching_close(&tokens, text, open) {
            Some(idx) => idx,
            None => continue,
        };
        let args = dpac_args(&tokens, text, open, close);

        let kind = if name == "cat" {
            if dpac_has_file_arg(&tokens, text, &args) {
                "file-write"
            } else {
                "message"
            }
        } else if args.is_empty() {
            "empty"
        } else if dpac_is_stringy(&tokens, text, args[0], &patterns) {
            "message"
        } else {
            "s3-print"
        };

        if kind == "file-write" || (kind == "s3-print" && !include_s3) {
            continue;
        }

        hits.push(Hit {
            line1: tok.line1,
            col1: tok.col1,
            col2: tok.col2,
            text: name.clone(),
            kind,
        });
    }

    let mut out: Vec<Robj> = hits.into_iter().map(dpac_hit_to_robj).collect();

    if include_refs {
        for k in 0..tokens.len() {
            let tok = &tokens[k];
            let name = match tok.kind {
                Kind::Ident => tok.text(text),
                _ => continue,
            };
            if name != "print" && name != "cat" {
                continue;
            }
            let is_call =
                matches!(next_sig(&tokens, k + 1), Some(idx) if tokens[idx].is_op(text, "("));
            if is_call {
                continue;
            }
            out.push(dpac_hit_to_robj(Hit {
                line1: tok.line1,
                col1: tok.col1,
                col2: tok.col2,
                text: name.to_string(),
                kind: "ref",
            }));
        }
    }

    Ok(out.into_iter().collect())
}

/// Replace the function name at `col1`..`col2` of one source line.
/// @keywords internal
#[extendr]
pub fn dpac_replace_fn_at_rs(line: &str, col1: i32, col2: i32, new: &str) -> String {
    let chars: Vec<char> = line.chars().collect();
    let len = chars.len();
    let head_end = ((col1 - 1).max(0) as usize).min(len);
    let tail_start = (col2.max(0) as usize).min(len);
    let head: String = chars[..head_end].iter().collect();
    let tail: String = if tail_start < len {
        chars[tail_start..].iter().collect()
    } else {
        String::new()
    };
    format!("{}{}{}", head, new, tail)
}

/// Build the two-line `source [kind]` + `^^^^` caret output of one hit.
///
/// An empty `kind` omits the ` [kind]` tag, as for bare references.
/// @keywords internal
#[extendr]
pub fn dpac_format_call_error_rs(line_content: &str, col1: i32, width: i32, kind: &str) -> String {
    let tag = if kind.is_empty() {
        String::new()
    } else {
        format!(" [{}]", kind)
    };
    let spaces = if col1 > 1 {
        " ".repeat((col1 - 1) as usize)
    } else {
        String::new()
    };
    let carets = if width > 0 {
        "^".repeat(width as usize)
    } else {
        String::new()
    };
    format!("{}{}\n{}{}", line_content, tag, spaces, carets)
}

fn dpac_callable_name(tok: &Token, text: &str) -> Option<String> {
    match tok.kind {
        Kind::Ident => Some(tok.text(text).to_string()),
        Kind::Backtick => Some(strip_name(tok.text(text))),
        _ => None,
    }
}

fn dpac_hit_to_robj(hit: Hit) -> Robj {
    Robj::from(List::from_pairs([
        ("line1", Robj::from(hit.line1)),
        ("col1", Robj::from(hit.col1)),
        ("col2", Robj::from(hit.col2)),
        ("text", Robj::from(hit.text)),
        (
            "type",
            Robj::from(if hit.kind == "ref" { "ref" } else { "call" }),
        ),
        ("kind", Robj::from(hit.kind)),
    ]))
}

/// Non-empty argument ranges of the call opened at `open`.
fn dpac_args(tokens: &[Token], text: &str, open: usize, close: usize) -> Vec<(usize, usize)> {
    let mut out = Vec::new();
    for (a, b) in split_args(tokens, text, open, close) {
        if let Some(range) = trim_range(tokens, a, b) {
            out.push(range);
        }
    }
    out
}

/// Does one of the arguments use `file = `, i.e. does `cat()` write a file?
fn dpac_has_file_arg(tokens: &[Token], text: &str, args: &[(usize, usize)]) -> bool {
    for &(a, b) in args {
        if !tokens[a].is_ident(text, "file") {
            continue;
        }
        if let Some(eq) = next_sig(tokens, a + 1) {
            if eq < b && tokens[eq].is_op(text, "=") {
                return true;
            }
        }
    }
    false
}

/// Is the first argument of `print()` a diagnostic string rather than an object
/// that gets S3-printed?
///
/// Mirrors `rpkgkit:::is_stringy_expr()`: a string literal that is a direct
/// child of the argument, or a direct call to one of `patterns`.
fn dpac_is_stringy(
    tokens: &[Token],
    text: &str,
    range: (usize, usize),
    patterns: &[Regex],
) -> bool {
    let (a, b) = range;
    let mut depth = 0i32;
    for k in a..b {
        let tok = &tokens[k];
        if tok.kind == Kind::Op {
            match tok.text(text) {
                "(" | "[" | "{" => depth += 1,
                ")" | "]" | "}" => depth -= 1,
                _ => {}
            }
            continue;
        }
        if depth != 0 {
            continue;
        }
        match tok.kind {
            Kind::Str | Kind::RawStr => return true,
            Kind::Ident | Kind::Backtick => {
                let name = strip_name(tok.text(text));
                let followed_by_paren = matches!(next_sig(tokens, k + 1), Some(idx) if idx < b && tokens[idx].is_op(text, "("));
                if followed_by_paren && patterns.iter().any(|re| re.is_match(&name)) {
                    return true;
                }
            }
            _ => {}
        }
    }
    false
}

extendr_module! {
    mod dpac;
    fn dpac_find_calls_rs;
    fn dpac_replace_fn_at_rs;
    fn dpac_format_call_error_rs;
}
