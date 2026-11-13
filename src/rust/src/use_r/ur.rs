//! Detect base-R functions and syntax that only exist in recent R versions.
//!
//! Everything here runs on the dependency-free tokenizer of
//! [`crate::r_syntax`], so a `%||%` inside a string, a comment or a raw string
//! is never reported. Two classes of hits are distinguished:
//!
//! * **syntax** (`|>`, `\()`, the `_` pipe placeholder): the parser of older R
//!   versions rejects the file, so the requirement can never be lowered.
//! * **names** (`%||%`, `%notin%`, `use()`, ...): the name may be defined by the
//!   package itself, as many packages do for `%||%`. Names assigned in the
//!   scanned sources are collected first and hits for those names are flagged
//!   `local`, which keeps them out of the minimum version.

use crate::r_syntax::{
    matching_close, next_sig, prev_sig, split_args, strip_name, tokenize, trim_range, Kind, Token,
};
use extendr_api::prelude::*;
use extendr_api::Result;
use std::collections::HashSet;
use std::path::{Path, PathBuf};

/// A base-R feature written as a plain name, plus the R version that added it.
struct Feature {
    name: &'static str,
    version: &'static str,
    label: &'static str,
}

/// Name-based features. `%||%` and `%notin%` are lexed as operators, the rest
/// as identifiers; both are matched by their source text.
const FEATURES: &[Feature] = &[
    Feature {
        name: "isa",
        version: "4.1.0",
        label: "isa()",
    },
    Feature {
        name: "Sys.setLanguage",
        version: "4.2.0",
        label: "Sys.setLanguage()",
    },
    Feature {
        name: "%||%",
        version: "4.4.0",
        label: "NULL-default operator",
    },
    Feature {
        name: "sort_by",
        version: "4.4.0",
        label: "sort_by()",
    },
    Feature {
        name: "Tailcall",
        version: "4.4.0",
        label: "Tailcall()",
    },
    Feature {
        name: "Exec",
        version: "4.4.0",
        label: "Exec()",
    },
    Feature {
        name: "use",
        version: "4.5.0",
        label: "use()",
    },
    Feature {
        name: "grepv",
        version: "4.5.0",
        label: "grepv()",
    },
    Feature {
        name: "penguins",
        version: "4.5.0",
        label: "the penguins dataset",
    },
    Feature {
        name: "%notin%",
        version: "4.6.0",
        label: "negated match operator",
    },
    Feature {
        name: "messageCondition",
        version: "4.6.0",
        label: "messageCondition()",
    },
];

/// One reported use of a feature. At most one row per file and feature is
/// produced; `count` carries the number of occurrences in that file.
struct Hit {
    feature: String,
    version: String,
    label: String,
    file: String,
    line1: i32,
    col1: i32,
    count: i32,
    local: bool,
}

fn ur_feature(name: &str) -> Option<&'static Feature> {
    FEATURES.iter().find(|feature| feature.name == name)
}

fn ur_version_key(version: &str) -> (u32, u32, u32) {
    let mut parts = version.split('.').map(|part| part.parse::<u32>().unwrap_or(0));
    (
        parts.next().unwrap_or(0),
        parts.next().unwrap_or(0),
        parts.next().unwrap_or(0),
    )
}

/// The larger of two `major.minor.patch` strings; `""` means "no requirement".
fn ur_max_version(current: &str, candidate: &str) -> String {
    if current.is_empty() {
        return candidate.to_string();
    }
    if ur_version_key(candidate) > ur_version_key(current) {
        candidate.to_string()
    } else {
        current.to_string()
    }
}

fn ur_push(
    hits: &mut Vec<Hit>,
    feature: &str,
    version: &str,
    label: &str,
    file: &str,
    tok: &Token,
    local: bool,
) {
    if let Some(existing) = hits
        .iter_mut()
        .find(|hit| hit.file == file && hit.feature == feature)
    {
        existing.count += 1;
        return;
    }
    hits.push(Hit {
        feature: feature.to_string(),
        version: version.to_string(),
        label: label.to_string(),
        file: file.to_string(),
        line1: tok.line1,
        col1: tok.col1,
        count: 1,
        local,
    });
}

fn ur_is_comment(tok: &Token) -> bool {
    tok.kind == Kind::Comment
}

/// First non-comment token in `[from, to)`.
fn ur_first_sig_in(tokens: &[Token], from: usize, to: usize) -> Option<usize> {
    (from..to).find(|&k| !ur_is_comment(&tokens[k]))
}

/// `true` when `tokens[k]` is the first non-comment token of its line.
fn ur_first_on_line(tokens: &[Token], src: &str, k: usize) -> bool {
    match prev_sig(tokens, k) {
        None => true,
        Some(prev) => {
            let prev = &tokens[prev];
            prev.line2 < tokens[k].line1
                || prev.is_op(src, ";")
                || prev.is_op(src, "{")
                || prev.is_op(src, "}")
        }
    }
}

/// `true` for `pkg::name` / `pkg:::name` where `pkg` is not `base`.
fn ur_foreign_qualified(tokens: &[Token], src: &str, k: usize) -> bool {
    let sep = match prev_sig(tokens, k) {
        Some(sep) => sep,
        None => return false,
    };
    if !(tokens[sep].is_op(src, "::") || tokens[sep].is_op(src, ":::")) {
        return false;
    }
    match prev_sig(tokens, sep) {
        Some(pkg) => !tokens[pkg].is_ident(src, "base"),
        None => false,
    }
}

/// `true` for `x$name` / `x@name`, which is a field, not the base function.
fn ur_is_extraction(tokens: &[Token], src: &str, k: usize) -> bool {
    match prev_sig(tokens, k) {
        Some(prev) => tokens[prev].is_op(src, "$") || tokens[prev].is_op(src, "@"),
        None => false,
    }
}

/// Names the package defines itself: `name <- ...`, `name = ...` at top level,
/// and `assign("name", ...)`. A locally provided `%||%` or `use()` lowers the R
/// requirement instead of raising it.
fn ur_local_defs(tokens: &[Token], src: &str) -> HashSet<String> {
    let mut defs: HashSet<String> = HashSet::new();

    let mut depth: Vec<i32> = Vec::with_capacity(tokens.len());
    let mut current = 0i32;
    for tok in tokens {
        depth.push(current);
        if tok.kind == Kind::Op {
            match tok.text(src) {
                "(" | "[" | "{" => current += 1,
                ")" | "]" | "}" => current -= 1,
                _ => {}
            }
        }
    }

    for (k, tok) in tokens.iter().enumerate() {
        let name = match tok.kind {
            Kind::Ident => tok.text(src).to_string(),
            Kind::Backtick | Kind::Str => strip_name(tok.text(src)),
            // A `%in%-style` operator is defined without backticks as well.
            Kind::Op if tok.text(src).len() > 2 && tok.text(src).starts_with('%') => {
                tok.text(src).to_string()
            }
            _ => continue,
        };
        let next = match next_sig(tokens, k + 1) {
            Some(next) => next,
            None => continue,
        };
        if tokens[next].kind != Kind::Op {
            continue;
        }
        match tokens[next].text(src) {
            "<-" | "<<-" => {
                defs.insert(name);
            }
            // `=` is only an assignment at the top level, on its own line.
            "=" if depth[k] == 0 && ur_first_on_line(tokens, src, k) => {
                defs.insert(name);
            }
            _ => {}
        }
    }

    for (k, tok) in tokens.iter().enumerate() {
        if tok.kind != Kind::Ident || tok.text(src) != "assign" {
            continue;
        }
        let open = match next_sig(tokens, k + 1) {
            Some(open) => open,
            None => continue,
        };
        if !tokens[open].is_op(src, "(") {
            continue;
        }
        let close = match matching_close(tokens, src, open) {
            Some(close) => close,
            None => continue,
        };
        let range = match split_args(tokens, src, open, close).first().copied() {
            Some(range) => range,
            None => continue,
        };
        let first = match ur_first_sig_in(tokens, range.0, range.1) {
            Some(first) => first,
            None => continue,
        };
        if tokens[first].kind == Kind::Str {
            defs.insert(strip_name(tokens[first].text(src)));
        }
    }

    defs
}

/// Non-comment tokens of one argument range.
fn ur_arg_tokens<'a>(tokens: &'a [Token], range: (usize, usize)) -> Vec<&'a Token> {
    let (from, to) = match trim_range(tokens, range.0, range.1) {
        Some(range) => range,
        None => return Vec::new(),
    };
    tokens[from..to]
        .iter()
        .filter(|tok| !ur_is_comment(tok))
        .collect()
}

/// `name = value` inside one argument range; `value` of `None` only requires
/// that the argument is named `name`.
fn ur_has_named_arg(
    tokens: &[Token],
    src: &str,
    range: (usize, usize),
    name: &str,
    value: Option<&str>,
) -> bool {
    let toks = ur_arg_tokens(tokens, range);
    if toks.len() < 2 || !toks[0].is_ident(src, name) || !toks[1].is_op(src, "=") {
        return false;
    }
    match value {
        None => true,
        Some(expected) => {
            toks.len() >= 3 && toks[2].kind == Kind::Str && strip_name(toks[2].text(src)) == expected
        }
    }
}

/// `match.arg(several.ok = "all")` and `barplot(orderH = ...)` need R 4.6.0.
fn ur_scan_arg_features(
    tokens: &[Token],
    src: &str,
    k: usize,
    file: &str,
    hits: &mut Vec<Hit>,
) {
    let tok = &tokens[k];
    let name = tok.text(src);
    let (arg, value, label) = match name {
        "match.arg" => ("several.ok", Some("all"), "match.arg(several.ok = \"all\")"),
        "barplot" => ("orderH", None, "barplot(orderH =)"),
        _ => return,
    };
    if ur_foreign_qualified(tokens, src, k) || ur_is_extraction(tokens, src, k) {
        return;
    }
    let open = match next_sig(tokens, k + 1) {
        Some(open) => open,
        None => return,
    };
    if !tokens[open].is_op(src, "(") {
        return;
    }
    let close = match matching_close(tokens, src, open) {
        Some(close) => close,
        None => return,
    };
    let found = split_args(tokens, src, open, close)
        .into_iter()
        .any(|range| ur_has_named_arg(tokens, src, range, arg, value));
    if found {
        ur_push(hits, name, "4.6.0", label, file, tok, false);
    }
}

fn ur_scan_op(
    tokens: &[Token],
    src: &str,
    k: usize,
    file: &str,
    defs: &HashSet<String>,
    hits: &mut Vec<Hit>,
) {
    let tok = &tokens[k];
    let text = tok.text(src);

    if text == "|>" {
        ur_push(hits, "|>", "4.1.0", "native pipe", file, tok, false);
        return;
    }
    if text == "\\" {
        let is_lambda = matches!(next_sig(tokens, k + 1), Some(next) if tokens[next].is_op(src, "("));
        if is_lambda {
            ur_push(hits, "\\()", "4.1.0", "lambda shorthand", file, tok, false);
        }
        return;
    }
    if let Some(feature) = ur_feature(text) {
        if !ur_foreign_qualified(tokens, src, k) {
            let local = defs.contains(feature.name);
            ur_push(
                hits,
                feature.name,
                feature.version,
                feature.label,
                file,
                tok,
                local,
            );
        }
    }
}

fn ur_scan_name(
    tokens: &[Token],
    src: &str,
    k: usize,
    file: &str,
    defs: &HashSet<String>,
    hits: &mut Vec<Hit>,
) {
    let tok = &tokens[k];

    if tok.kind == Kind::Ident && tok.text(src) == "_" {
        match prev_sig(tokens, k).map(|prev| &tokens[prev]) {
            Some(prev) if prev.is_op(src, "=") => {
                ur_push(
                    hits,
                    "_ (named argument)",
                    "4.2.0",
                    "pipe placeholder in a named argument",
                    file,
                    tok,
                    false,
                );
            }
            Some(prev) if prev.is_op(src, "|>") => {
                ur_push(
                    hits,
                    "_ (extraction chain)",
                    "4.3.0",
                    "pipe placeholder heading an extraction chain",
                    file,
                    tok,
                    false,
                );
            }
            _ => {}
        }
        return;
    }

    if tok.kind == Kind::Ident {
        ur_scan_arg_features(tokens, src, k, file, hits);
    }

    let name = match tok.kind {
        Kind::Ident => tok.text(src).to_string(),
        _ => strip_name(tok.text(src)),
    };
    let feature = match ur_feature(&name) {
        Some(feature) => feature,
        None => return,
    };
    if ur_foreign_qualified(tokens, src, k) || ur_is_extraction(tokens, src, k) {
        return;
    }
    // `use = TRUE` is a named argument, not a call to `use()`.
    if matches!(next_sig(tokens, k + 1), Some(next) if tokens[next].is_op(src, "=")) {
        return;
    }
    let local = defs.contains(feature.name);
    ur_push(
        hits,
        feature.name,
        feature.version,
        feature.label,
        file,
        tok,
        local,
    );
}

fn ur_scan_tokens(
    tokens: &[Token],
    src: &str,
    file: &str,
    defs: &HashSet<String>,
    hits: &mut Vec<Hit>,
) {
    for k in 0..tokens.len() {
        match tokens[k].kind {
            Kind::Op => ur_scan_op(tokens, src, k, file, defs, hits),
            Kind::Ident | Kind::Backtick => ur_scan_name(tokens, src, k, file, defs, hits),
            _ => {}
        }
    }
}

fn ur_is_r_file(path: &Path) -> bool {
    match path.extension() {
        Some(ext) => ext.to_string_lossy().eq_ignore_ascii_case("r"),
        None => false,
    }
}

/// Recursively collect `.R` / `.r` files. A missing directory is not an error:
/// packages simply do not have every directory the caller asked for.
fn ur_collect_files(target: &Path, out: &mut Vec<PathBuf>) -> Result<()> {
    let meta = match std::fs::metadata(target) {
        Ok(meta) => meta,
        Err(_) => return Ok(()),
    };
    if meta.is_file() {
        if ur_is_r_file(target) {
            out.push(target.to_path_buf());
        }
        return Ok(());
    }
    if !meta.is_dir() {
        return Ok(());
    }
    let entries = std::fs::read_dir(target)
        .map_err(|err| format!("cannot read directory {}: {err}", target.display()))?;
    for entry in entries {
        let entry =
            entry.map_err(|err| format!("cannot read directory {}: {err}", target.display()))?;
        let path = entry.path();
        let file_type = match entry.file_type() {
            Ok(file_type) => file_type,
            Err(_) => continue,
        };
        if file_type.is_dir() {
            ur_collect_files(&path, out)?;
        } else if file_type.is_file() && ur_is_r_file(&path) {
            out.push(path);
        }
    }
    Ok(())
}

fn ur_scan_root(root: &Path, dirs: &[String]) -> Result<(Vec<Hit>, Vec<String>)> {
    let mut paths: Vec<PathBuf> = Vec::new();
    for dir in dirs {
        ur_collect_files(&root.join(dir), &mut paths)?;
    }
    paths.sort();
    paths.dedup();

    let mut sources: Vec<(String, String)> = Vec::new();
    for path in paths {
        let display = path
            .strip_prefix(root)
            .unwrap_or(&path)
            .to_string_lossy()
            .replace('\\', "/");
        let src = std::fs::read_to_string(&path)
            .map_err(|err| format!("cannot read {}: {err}", path.display()))?;
        sources.push((display, src));
    }

    // A `%||%` defined in one file can be used in another, so the local
    // definitions of the whole package are collected before scanning.
    let mut defs: HashSet<String> = HashSet::new();
    for (_, src) in &sources {
        defs.extend(ur_local_defs(&tokenize(src), src));
    }

    let mut hits: Vec<Hit> = Vec::new();
    let mut files: Vec<String> = Vec::new();
    for (display, src) in &sources {
        let tokens = tokenize(src);
        ur_scan_tokens(&tokens, src, display, &defs, &mut hits);
        files.push(display.clone());
    }
    Ok((hits, files))
}

fn ur_hits_to_list(hits: Vec<Hit>, files: Vec<String>) -> List {
    let min_version = hits
        .iter()
        .filter(|hit| !hit.local)
        .map(|hit| hit.version.as_str())
        .fold(String::new(), |current, version| {
            ur_max_version(&current, version)
        });

    let feature: Vec<String> = hits.iter().map(|hit| hit.feature.clone()).collect();
    let version: Vec<String> = hits.iter().map(|hit| hit.version.clone()).collect();
    let label: Vec<String> = hits.iter().map(|hit| hit.label.clone()).collect();
    let file: Vec<String> = hits.iter().map(|hit| hit.file.clone()).collect();
    let line: Vec<i32> = hits.iter().map(|hit| hit.line1).collect();
    let col: Vec<i32> = hits.iter().map(|hit| hit.col1).collect();
    let count: Vec<i32> = hits.iter().map(|hit| hit.count).collect();
    // `Vec<i32>` instead of `Vec<bool>` keeps the conversion unambiguous; R
    // turns the column into a logical vector.
    let local: Vec<i32> = hits
        .iter()
        .map(|hit| if hit.local { 1 } else { 0 })
        .collect();

    List::from_pairs([
        ("feature", Robj::from(Strings::from_values(feature))),
        ("version", Robj::from(Strings::from_values(version))),
        ("label", Robj::from(Strings::from_values(label))),
        ("file", Robj::from(Strings::from_values(file))),
        ("line", Robj::from(line)),
        ("col", Robj::from(col)),
        ("count", Robj::from(count)),
        ("local", Robj::from(local)),
        ("min_version", Robj::from(min_version)),
        ("files", Robj::from(Strings::from_values(files))),
    ])
}

/// Base-R features that need a recent R version in one source text.
///
/// Returns one row per feature, with `feature`, `version`, `label`, `file`,
/// `line`, `col`, `count`, `local`, `min_version` and `files`. `local` marks a
/// name that the scanned sources define themselves; those hits do not raise
/// `min_version`.
/// @keywords internal
#[extendr]
pub fn ur_scan_text_rs(text: &str) -> List {
    let tokens = tokenize(text);
    let defs = ur_local_defs(&tokens, text);
    let mut hits: Vec<Hit> = Vec::new();
    ur_scan_tokens(&tokens, text, "", &defs, &mut hits);
    ur_hits_to_list(hits, Vec::new())
}

/// Recursively scan the `.R` files below `root` for base-R features that need a
/// recent R version.
///
/// `dirs` holds paths relative to `root`; missing directories are skipped. The
/// returned `file` column is relative to `root`, and `min_version` is `""` when
/// no feature (or only locally defined names) was found.
/// @keywords internal
#[extendr]
pub fn ur_scan_rs(root: &str, dirs: Strings) -> Result<List> {
    let mut dirs_vec: Vec<String> = Vec::new();
    for dir in dirs.iter() {
        let dir: &str = dir;
        dirs_vec.push(dir.to_string());
    }
    let (hits, files) = ur_scan_root(Path::new(root), &dirs_vec)?;
    Ok(ur_hits_to_list(hits, files))
}

extendr_module! {
    mod ur;
    fn ur_scan_text_rs;
    fn ur_scan_rs;
}
