use crate::r_syntax::{
    collapse_newlines, matching_close, next_sig, split_args, strip_name, tokenize, trim_range,
    trim_ws, Kind,
};
use extendr_api::prelude::*;
use extendr_api::Result;
use regex::Regex;

/// One exported argument whose default is a concrete path.
struct Hit {
    func: String,
    arg: String,
    default: String,
    line1: i32,
    col1: i32,
    line2: i32,
    col2: i32,
}

/// Locate path-like defaults in the arguments of exported functions.
///
/// Rust rewrite of `rpkgkit:::scan_fn_arg_path()`. A top-level
/// `name <- function(...)` definition is found with the tokenizer of
/// [`crate::r_syntax`], its formals are split on top-level commas, and every
/// formal whose name matches `arg_pattern` and whose default (as written in the
/// source, whitespace collapsed) is not in `allow` is reported. `exports = NULL`
/// together with an empty `export_patterns` means "check every top-level
/// function".
///
/// Character arguments are taken as `Vec<String>` (not `Strings`): iterating a
/// zero-length `Strings` panics in debug builds, and `export_patterns` / `allow`
/// are empty in the common case.
/// @keywords internal
#[extendr]
pub fn dfap_scan_text_rs(
    text: &str,
    arg_pattern: &str,
    exports: Nullable<Vec<String>>,
    export_patterns: Vec<String>,
    allow: Vec<String>,
) -> Result<List> {
    let arg_re = match Regex::new(arg_pattern) {
        Ok(re) => re,
        Err(err) => {
            return Err(format!("`arg_pattern` is not a valid regular expression: {}", err).into())
        }
    };

    let mut export_res: Vec<Regex> = Vec::new();
    for pattern in &export_patterns {
        match Regex::new(pattern.as_str()) {
            Ok(re) => export_res.push(re),
            Err(err) => {
                return Err(format!(
                    "`export_patterns` contains an invalid regular expression: {}",
                    err
                )
                .into())
            }
        }
    }

    let export_names: Vec<String> = match &exports {
        Nullable::NotNull(names) => names.clone(),
        Nullable::Null => Vec::new(),
    };
    let check_all = matches!(&exports, Nullable::Null) && export_res.is_empty();

    let allow_values: Vec<String> = allow;

    let tokens = tokenize(text);
    let depth_before = dfap_depth_before(&tokens, text);
    let mut hits: Vec<Hit> = Vec::new();

    for k in 0..tokens.len() {
        if depth_before[k] != 0 {
            continue;
        }
        let name_tok = &tokens[k];
        if !matches!(name_tok.kind, Kind::Ident | Kind::Backtick | Kind::Str) {
            continue;
        }

        let assign = match next_sig(&tokens, k + 1) {
            Some(idx) if depth_before[idx] == 0 => idx,
            _ => continue,
        };
        let is_assign = ["<-", "<<-", "=", ":="]
            .iter()
            .any(|op| tokens[assign].is_op(text, op));
        if !is_assign {
            continue;
        }

        let func_kw = match next_sig(&tokens, assign + 1) {
            Some(idx) if depth_before[idx] == 0 => idx,
            _ => continue,
        };
        if !tokens[func_kw].is_ident(text, "function") {
            continue;
        }

        let open = match next_sig(&tokens, func_kw + 1) {
            Some(idx) => idx,
            None => continue,
        };
        if !tokens[open].is_op(text, "(") {
            continue;
        }
        let close = match matching_close(&tokens, text, open) {
            Some(idx) => idx,
            None => continue,
        };

        let func_name = strip_name(name_tok.text(text));
        let exported = check_all
            || export_names.contains(&func_name)
            || export_res.iter().any(|re| re.is_match(&func_name));
        if !exported {
            continue;
        }

        for (from, to) in split_args(&tokens, text, open, close) {
            let (start, end) = match trim_range(&tokens, from, to) {
                Some(range) => range,
                None => continue,
            };
            let first = &tokens[start];
            if !matches!(first.kind, Kind::Ident | Kind::Backtick) {
                continue;
            }
            let arg_name = strip_name(first.text(text));
            if !arg_re.is_match(&arg_name) {
                continue;
            }

            // Default value: the tokens right after `=`. A formal without a
            // default is always fine.
            let eq = match next_sig(&tokens, start + 1) {
                Some(idx) if idx < end && tokens[idx].is_op(text, "=") => idx,
                _ => continue,
            };
            let default_start = match next_sig(&tokens, eq + 1) {
                Some(idx) if idx < end => idx,
                _ => continue,
            };
            let default_end = end - 1;

            let default =
                collapse_newlines(&text[tokens[default_start].start..tokens[default_end].end]);
            if allow_values.iter().any(|value| *value == trim_ws(&default)) {
                continue;
            }

            hits.push(Hit {
                func: func_name.clone(),
                arg: arg_name,
                default,
                line1: first.line1,
                col1: first.col1,
                line2: tokens[default_end].line2,
                col2: tokens[default_end].col2,
            });
        }
    }

    let out: Vec<Robj> = hits.into_iter().map(dfap_hit_to_robj).collect();
    Ok(out.into_iter().collect())
}

fn dfap_hit_to_robj(hit: Hit) -> Robj {
    Robj::from(List::from_pairs([
        ("fn", Robj::from(hit.func)),
        ("arg", Robj::from(hit.arg)),
        ("default", Robj::from(hit.default)),
        ("line1", Robj::from(hit.line1)),
        ("col1", Robj::from(hit.col1)),
        ("line2", Robj::from(hit.line2)),
        ("col2", Robj::from(hit.col2)),
    ]))
}

/// Bracket depth in front of every token: `0` means "top level".
fn dfap_depth_before(tokens: &[crate::r_syntax::Token], text: &str) -> Vec<i32> {
    let mut out = vec![0i32; tokens.len()];
    let mut depth = 0i32;
    for (k, tok) in tokens.iter().enumerate() {
        out[k] = depth;
        if tok.kind != Kind::Op {
            continue;
        }
        match tok.text(text) {
            "(" | "[" | "{" => depth += 1,
            ")" | "]" | "}" => depth = (depth - 1).max(0),
            _ => {}
        }
    }
    out
}

extendr_module! {
    mod dfap;
    fn dfap_scan_text_rs;
}