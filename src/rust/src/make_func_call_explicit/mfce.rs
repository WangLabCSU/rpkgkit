//! Make package function calls and exported datasets explicit.
//!
//! Rust replacement for the tokenizer + replacement engine of
//! `add_double_colons()` in `R/vendor-pedant.R`. R still owns the package
//! metadata (namespace exports, datasets, `ignore_functions`); this module
//! tokenizes the source with `crate::r_syntax` and inserts `pkg::` only before
//! identifiers that really are calls or datasets.
//!
//! Because the rewrite walks tokens instead of regular expressions, an
//! identifier that follows `$` or `@` is a member of an object (`l$select`,
//! `obj@slot`) and is never qualified, even when a package exports a function
//! or dataset with the same name.

use std::collections::HashMap;

use extendr_api::prelude::*;

use crate::r_syntax::{self, Kind, Token};

/// Names that are never treated as datasets.
const SKIP_NAMES: &[&str] = &[
    "TRUE",
    "FALSE",
    "T",
    "F",
    "NA",
    "NA_integer_",
    "NA_real_",
    "NA_character_",
    "NA_complex_",
    "NULL",
    "Inf",
    "NaN",
    "if",
    "else",
    "for",
    "while",
    "repeat",
    "function",
    "in",
    "next",
    "break",
];

/// Tokens that make the identifier before them a non-candidate: a member
/// access (`l$f`), an assignment target (`f <- 1`), a placeholder of a
/// `for` loop, etc.
const SKIP_AFTER: &[&str] = &[
    "::", ":::", "$", "@", "=", "<-", "<<-", "->", "->>", "in",
];

/// What the identifier at the current token is used for.
#[derive(Clone, Copy, PartialEq, Eq)]
enum Role {
    /// `fun(...)`: a call, a candidate for `pkg::fun`.
    Call,
    /// `obj`: a dataset candidate.
    Data,
    /// Never qualify: member access, formal argument, assignment target, ...
    Skip,
}

/// Text of the previous significant token.
fn mfce_prev_text<'a>(tokens: &[Token], src: &'a str, idx: usize) -> Option<&'a str> {
    r_syntax::prev_sig(tokens, idx).map(|p| tokens[p].text(src))
}

/// Text of the next significant token.
fn mfce_next_text<'a>(tokens: &[Token], src: &'a str, idx: usize) -> Option<&'a str> {
    r_syntax::next_sig(tokens, idx + 1).map(|n| tokens[n].text(src))
}

/// Index of the bracket that encloses token `idx`, if any.
///
/// Only an enclosing `(` is reported: an identifier inside `(`, `[` or `{`
/// has no bearing on whether it is a call or a dataset, but the parenthesis
/// is what distinguishes the arguments of a `function()` formals list, of a
/// `data()` call or of a plain call.
fn mfce_enclosing_paren(tokens: &[Token], src: &str, idx: usize) -> Option<usize> {
    let mut depth = 0i32;
    for k in (0..idx).rev() {
        let tok = &tokens[k];
        if tok.kind != Kind::Op {
            continue;
        }
        match tok.text(src) {
            ")" | "]" | "}" => depth += 1,
            "(" => {
                if depth == 0 {
                    return Some(k);
                }
                depth -= 1;
            }
            "[" | "{" => {
                if depth == 0 {
                    return None;
                }
                depth -= 1;
            }
            _ => {}
        }
    }
    None
}

/// `true` when token `idx` is one of the formal arguments of a function
/// definition, as in `function(x, y = 1)` or `\(x)`.
fn mfce_in_formals(tokens: &[Token], src: &str, idx: usize) -> bool {
    let open = match mfce_enclosing_paren(tokens, src, idx) {
        Some(open) => open,
        None => return false,
    };
    matches!(mfce_prev_text(tokens, src, open), Some("function") | Some("\\"))
}

/// `true` when token `idx` is an argument of a `data()` call.
///
/// `data(mtcars)` takes the *name* of a dataset, so qualifying it would turn
/// the call into `data(datasets::mtcars)` and break it.
fn mfce_in_data_call(tokens: &[Token], src: &str, idx: usize) -> bool {
    let open = match mfce_enclosing_paren(tokens, src, idx) {
        Some(open) => open,
        None => return false,
    };
    let mut k = match r_syntax::prev_sig(tokens, open) {
        Some(k) => k,
        None => return false,
    };
    if matches!(tokens[k].text(src), "::" | ":::") {
        k = match r_syntax::prev_sig(tokens, k) {
            Some(k) => k,
            None => return false,
        };
    }
    tokens[k].text(src) == "data"
}

/// Classify the identifier at token `idx`.
fn mfce_classify(tokens: &[Token], src: &str, idx: usize) -> Role {
    let prev = mfce_prev_text(tokens, src, idx);
    // `pkg::fun` is already explicit, `obj$fun` and `obj@fun` are members of
    // an object: in both cases the identifier must stay as written.
    if matches!(prev, Some("::") | Some(":::") | Some("$") | Some("@")) {
        return Role::Skip;
    }

    let next = match mfce_next_text(tokens, src, idx) {
        Some(next) => next,
        None => return Role::Skip,
    };

    if next == "(" {
        return Role::Call;
    }
    if SKIP_AFTER.contains(&next) {
        return Role::Skip;
    }
    if mfce_in_formals(tokens, src, idx) || mfce_in_data_call(tokens, src, idx) {
        return Role::Skip;
    }
    Role::Data
}

/// Build a sorted `name -> package` table; earlier packages win.
fn mfce_build_lookup(names: &[String], packages: &[String]) -> Vec<(String, String)> {
    let mut map: HashMap<String, String> = HashMap::new();
    for (name, pkg) in names.iter().zip(packages.iter()) {
        map.entry(name.clone()).or_insert_with(|| pkg.clone());
    }
    let mut out: Vec<(String, String)> = map.into_iter().collect();
    out.sort();
    out
}

/// Look `name` up in a table built by [`mfce_build_lookup()`].
fn mfce_lookup<'a>(table: &'a [(String, String)], name: &str) -> Option<&'a str> {
    table
        .binary_search_by(|(k, _)| k.as_str().cmp(name))
        .ok()
        .map(|idx| table[idx].1.as_str())
}

/// `pkg::name`, unless the package is base or the name is ignored.
fn mfce_qualify(pkg: &str, raw: &str, ignore: &[String], is_base: bool) -> String {
    if is_base || ignore.iter().any(|f| f == raw) {
        raw.to_string()
    } else {
        format!("{}::{}", pkg, raw)
    }
}

/// Rewrite `text`, qualifying package calls and exported datasets.
///
/// `fun_exports` / `fun_packages` are parallel vectors of namespace exports
/// and their packages; `data_exports` / `data_packages` do the same for
/// exported datasets. `use_packages` is only reported back so callers can
/// describe the operation.
///
/// Character vectors are taken as `Vec<String>` (not `Strings`): iterating a
/// zero-length `Strings` aborts in debug builds, and a package may well export
/// no dataset at all.
///
/// @keywords internal
#[allow(clippy::too_many_arguments)]
#[extendr]
pub fn mfce_make_calls_explicit_rs(
    text: &str,
    use_packages: Vec<String>,
    ignore_functions: Vec<String>,
    fun_exports: Vec<String>,
    fun_packages: Vec<String>,
    data_exports: Vec<String>,
    data_packages: Vec<String>,
    base_pkg: &str,
) -> List {
    let fun_table = mfce_build_lookup(&fun_exports, &fun_packages);
    let data_table = mfce_build_lookup(&data_exports, &data_packages);
    let ignore = &ignore_functions;

    let tokens = r_syntax::tokenize(text);
    let mut edits: Vec<(usize, usize, String)> = Vec::new();
    let mut not_found: Vec<String> = Vec::new();

    for (idx, tok) in tokens.iter().enumerate() {
        if tok.kind != Kind::Ident && tok.kind != Kind::Backtick {
            continue;
        }
        let raw = tok.text(text);
        // Backticks wrap a non-syntactic name: the lookup uses the bare name,
        // the edit keeps the backticks the code was written with.
        let plain = if tok.kind == Kind::Backtick {
            if raw.len() < 2 || !raw.ends_with('`') {
                continue;
            }
            &raw[1..raw.len() - 1]
        } else {
            raw
        };
        if plain.is_empty() || SKIP_NAMES.contains(&plain) {
            continue;
        }

        match mfce_classify(&tokens, text, idx) {
            Role::Call => match mfce_lookup(&fun_table, plain) {
                Some(pkg) => {
                    let qualified = mfce_qualify(pkg, raw, ignore, pkg == base_pkg);
                    if qualified != raw {
                        edits.push((tok.start, tok.end, qualified));
                    }
                }
                None => {
                    if !not_found.iter().any(|n| n == raw) {
                        not_found.push(raw.to_string());
                    }
                }
            },
            Role::Data => {
                if let Some(pkg) = mfce_lookup(&data_table, plain) {
                    if pkg != base_pkg {
                        edits.push((tok.start, tok.end, format!("{}::{}", pkg, raw)));
                    }
                }
            }
            Role::Skip => {}
        }
    }

    let changed = !edits.is_empty();
    let mut out = String::with_capacity(text.len() + edits.len() * 8);
    let mut last = 0usize;
    for (start, end, replacement) in edits {
        out.push_str(&text[last..start]);
        out.push_str(&replacement);
        last = end;
    }
    out.push_str(&text[last..]);

    List::from_pairs([
        ("text", Robj::from(out)),
        ("not_found", Robj::from(not_found)),
        ("changed", Robj::from(changed)),
        ("packages", Robj::from(use_packages)),
    ])
}

extendr_module! {
    mod mfce;
    fn mfce_make_calls_explicit_rs;
}
