use crate::r_syntax::trim_ws;
use extendr_api::prelude::*;
use extendr_api::Result;

// ===========================================================================
// A tiny YAML subset
//
// `.ory_emit_yaml()` and `.ory_optimize_output()` used the {yaml} package. The
// Rust rewrite replaces it with the small value model below, which covers what
// an Rmd YAML header actually contains: nested mappings of scalars, sequences of
// scalars, and the odd flow sequence.
// ===========================================================================

/// Minimal YAML value used by the header builder.
#[derive(Clone, Debug, PartialEq)]
enum Yaml {
    Null,
    Bool(bool),
    Int(i64),
    Real(f64),
    Str(String),
    Seq(Vec<Yaml>),
    Map(Vec<(String, Yaml)>),
}

/// Package metadata read from `DESCRIPTION` by the R side.
struct Meta {
    package: String,
    title: Option<String>,
    version: String,
    authors: Option<String>,
    date: Option<String>,
    lang: String,
}

const ORY_MANAGED: [&str; 9] = [
    "title",
    "subtitle",
    "author",
    "date",
    "lang",
    "output",
    "bibliography",
    "link-citations",
    "vignette",
];

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Split an Rmd file into YAML header lines and body lines.
///
/// Rust rewrite of `rpkgkit:::.ory_read_rmd()`. Character arguments are taken
/// as `Vec<String>` (not `Strings`): iterating a zero-length `Strings` aborts
/// the R session, and an empty YAML header is a valid input.
/// @keywords internal
#[extendr]
pub fn ory_read_rmd_rs(lines: Vec<String>) -> List {
    let (header, body) = ory_read_rmd_impl(&lines);
    List::from_pairs([
        ("header", Robj::from(Strings::from_values(header))),
        ("body", Robj::from(Strings::from_values(body))),
        ("raw", Robj::from(Strings::from_values(lines))),
    ])
}

/// Split header lines into top-level key chunks.
///
/// Rust rewrite of `rpkgkit:::.ory_split_chunks()`. The result is a named list
/// of character vectors, in source order.
/// @keywords internal
#[extendr]
pub fn ory_split_chunks_rs(header: Vec<String>) -> List {
    let chunks = ory_split_chunks_impl(&header);
    if chunks.is_empty() {
        // `list()` with no names attribute, like `.ory_split_chunks(character())`.
        return List::new(0);
    }
    let names: Vec<String> = chunks.iter().map(|(name, _)| name.clone()).collect();
    let values: Vec<Robj> = chunks
        .into_iter()
        .map(|(_, lines)| Robj::from(Strings::from_values(lines)))
        .collect();
    List::from_names_and_values(names, values).unwrap_or_default()
}

/// Quote a string as a double-quoted YAML scalar.
///
/// Rust rewrite of `rpkgkit:::.ory_yq()`.
/// @keywords internal
#[extendr]
pub fn ory_yq_rs(x: &str) -> String {
    ory_yq_impl(x)
}

/// `"readme"` for `README.Rmd`, `"vignette"` otherwise.
///
/// Rust rewrite of `rpkgkit:::.ory_detect_type()`.
/// @keywords internal
#[extendr]
pub fn ory_detect_type_rs(path: &str) -> String {
    ory_detect_type_impl(path).to_string()
}

/// Serialize an R list to YAML lines.
///
/// Rust rewrite of `rpkgkit:::.ory_emit_yaml()`: logicals become `true` /
/// `false`, nested lists become nested mappings, and the indentation is two
/// spaces.
/// @keywords internal
#[extendr]
pub fn ory_emit_yaml_rs(x: List) -> Result<Strings> {
    let value = ory_yaml_from_robj(&Robj::from(x));
    Ok(Strings::from_values(ory_emit_yaml_impl(&value)))
}

/// Enriched default options of the output formats managed by the function.
///
/// Rust rewrite of `rpkgkit:::.ory_format_defaults()`; `NULL` means the format
/// is not managed and is left untouched.
/// @keywords internal
#[extendr]
pub fn ory_format_defaults_rs(fmt: &str) -> Nullable<List> {
    match ory_format_defaults_impl(fmt) {
        Some(value) => match ory_yaml_to_robj(&value).as_list() {
            Some(list) => Nullable::NotNull(list),
            None => Nullable::Null,
        },
        None => Nullable::Null,
    }
}

/// Deep merge of two named lists, values of `over` winning.
///
/// Rust rewrite of `rpkgkit:::.ory_merge_list()`.
/// @keywords internal
#[extendr]
pub fn ory_merge_list_rs(over: List, base: List) -> List {
    let over = ory_yaml_from_robj(&Robj::from(over));
    let base = ory_yaml_from_robj(&Robj::from(base));
    let merged = ory_merge_list_impl(over, base);
    ory_yaml_to_robj(&merged).as_list().unwrap_or_default()
}

/// Default `output` block for a README or a vignette.
///
/// Rust rewrite of `rpkgkit:::.ory_default_output()`.
/// @keywords internal
#[extendr]
pub fn ory_default_output_rs(type_: &str, readme_format: &str) -> Strings {
    Strings::from_values(ory_default_output_impl(type_, readme_format))
}

/// Keep the user's `output` block, or return `NULL` to use the enriched one.
///
/// Rust rewrite of `rpkgkit:::.ory_optimize_output()`: `NULL` means "the block
/// is still the usethis default", otherwise the lines to keep.
/// @keywords internal
#[extendr]
pub fn ory_optimize_output_rs(chunk: Vec<String>, type_: &str) -> Result<Nullable<Strings>> {
    match ory_optimize_output_impl(&chunk, type_) {
        Some(lines) => Ok(Nullable::NotNull(Strings::from_values(lines))),
        None => Ok(Nullable::Null),
    }
}

/// Default title of a README or a vignette.
///
/// Rust rewrite of `rpkgkit:::.ory_default_title()`.
/// @keywords internal
#[extendr]
pub fn ory_default_title_rs(path: &str, type_: &str, meta: List) -> String {
    let meta = ory_meta_from_list(&meta);
    ory_default_title_impl(path, type_, &meta)
}

/// Build the new YAML header lines, fences excluded.
///
/// Rust rewrite of `rpkgkit:::.ory_build_header()`. `extra` is a named list of
/// extra YAML fields, added only when the key is missing from the header.
/// @keywords internal
#[extendr]
pub fn ory_build_header_rs(
    header: Vec<String>,
    path: &str,
    type_: &str,
    meta: List,
    readme_format: &str,
    date: &str,
    extra: List,
) -> Result<Strings> {
    let meta = ory_meta_from_list(&meta);
    let extra = ory_named_pairs(&Robj::from(extra));
    Ok(Strings::from_values(ory_build_header_impl(
        &header,
        path,
        type_,
        &meta,
        readme_format,
        date,
        &extra,
    )))
}

// ---------------------------------------------------------------------------
// Header assembly
// ---------------------------------------------------------------------------

#[allow(clippy::too_many_arguments)]
fn ory_build_header_impl(
    header: &[String],
    path: &str,
    type_: &str,
    meta: &Meta,
    readme_format: &str,
    date: &str,
    extra: &[(String, Yaml)],
) -> Vec<String> {
    let chunks = ory_split_chunks_impl(header);
    let has = |key: &str| chunks.iter().any(|(name, _)| name == key);
    let chunk = |key: &str| -> Option<Vec<String>> {
        chunks
            .iter()
            .find(|(name, _)| name == key)
            .map(|(_, lines)| lines.clone())
    };
    let val = |key: &str| -> String {
        match chunk(key) {
            Some(lines) => match lines.first() {
                Some(line) => ory_strip_key(line),
                None => String::new(),
            },
            None => String::new(),
        }
    };

    let base = ory_file_path_sans_ext(&ory_basename(path));
    let old_title: Option<String> = if has("title") {
        Some(ory_unquote_edges(&val("title")))
    } else {
        None
    };
    let title_is_default = match &old_title {
        Some(title) => title.is_empty() || title == "Untitled" || *title == base,
        None => true,
    };
    let title_txt = if title_is_default {
        ory_default_title_impl(path, type_, meta)
    } else {
        old_title.clone().unwrap_or_default()
    };

    let mut out: Vec<(String, Vec<String>)> = Vec::new();

    // -- title
    let title_lines = if title_is_default {
        vec![format!("title: {}", ory_yq_impl(&title_txt))]
    } else {
        chunk("title").unwrap_or_default()
    };
    out.push(("title".to_string(), title_lines));

    // -- subtitle: vignettes only
    if type_ == "vignette" {
        let lines = chunk("subtitle").unwrap_or_else(|| {
            vec![format!(
                "subtitle: {}",
                ory_yq_impl(&format!("{} {}", meta.package, meta.version))
            )]
        });
        out.push(("subtitle".to_string(), lines));
    }

    // -- author
    if let Some(lines) = chunk("author") {
        out.push(("author".to_string(), lines));
    } else if let Some(authors) = &meta.authors {
        out.push((
            "author".to_string(),
            vec![format!("author: {}", ory_yq_impl(authors))],
        ));
    }

    // -- date
    if let Some(lines) = chunk("date") {
        out.push(("date".to_string(), lines));
    } else {
        let sys_date = "date: \"`r Sys.Date()`\"".to_string();
        let lines = match date {
            "auto" => Some(vec![sys_date]),
            "desc" => Some(vec![match &meta.date {
                Some(value) => format!("date: {}", ory_yq_impl(value)),
                None => sys_date,
            }]),
            _ => None,
        };
        if let Some(lines) = lines {
            out.push(("date".to_string(), lines));
        }
    }

    // -- lang
    let lang_lines = chunk("lang").unwrap_or_else(|| vec![format!("lang: {}", meta.lang)]);
    out.push(("lang".to_string(), lang_lines));

    // -- output
    let output_lines = if has("output") {
        ory_optimize_output_impl(&chunk("output").unwrap_or_default(), type_)
    } else {
        None
    };
    let output_lines =
        output_lines.unwrap_or_else(|| ory_default_output_impl(type_, readme_format));
    out.push(("output".to_string(), output_lines));

    // -- bibliography, added when a .bib sits next to the file
    let bib = ory_find_bib_files(path);
    let bib_new: Option<(String, String)> = if !has("bibliography") && !bib.is_empty() {
        Some((
            format!("bibliography: {}", bib[0]),
            "link-citations: true".to_string(),
        ))
    } else {
        None
    };
    if let Some(lines) = chunk("bibliography") {
        out.push(("bibliography".to_string(), lines));
    } else if let Some((bibliography, _)) = &bib_new {
        out.push(("bibliography".to_string(), vec![bibliography.clone()]));
    }
    if let Some(lines) = chunk("link-citations") {
        out.push(("link-citations".to_string(), lines));
    } else if let Some((_, link_citations)) = &bib_new {
        out.push(("link-citations".to_string(), vec![link_citations.clone()]));
    }

    // -- vignette block, syncing IndexEntry only while it is still the default
    if type_ == "vignette" {
        match chunk("vignette") {
            None => out.push((
                "vignette".to_string(),
                vec![
                    "vignette: >".to_string(),
                    format!("  %\\VignetteIndexEntry{{{}}}", title_txt),
                    "  %\\VignetteEngine{knitr::rmarkdown}".to_string(),
                    "  %\\VignetteEncoding{UTF-8}".to_string(),
                ],
            )),
            Some(mut lines) => {
                let positions: Vec<usize> = lines
                    .iter()
                    .enumerate()
                    .filter(|(_, line)| line.contains("VignetteIndexEntry"))
                    .map(|(idx, _)| idx)
                    .collect();
                if positions.len() == 1 && positions[0] > 0 {
                    let idx = positions[0];
                    let entry = ory_index_entry(&lines[idx]);
                    let matches_old = match &old_title {
                        Some(title) => entry == *title,
                        None => false,
                    };
                    if title_is_default && (entry.is_empty() || entry == "Untitled" || matches_old)
                    {
                        let indent: String = lines[idx]
                            .chars()
                            .take_while(|c| c.is_whitespace())
                            .collect();
                        lines[idx] = format!("{}%\\VignetteIndexEntry{{{}}}", indent, title_txt);
                    }
                }
                out.push(("vignette".to_string(), lines));
            }
        }
    }

    // -- extra fields: added only when the key is absent, otherwise replacing
    // the value generated above under the same key
    for (key, value) in extra {
        if has(key) {
            continue;
        }
        let lines = ory_emit_yaml_impl(&Yaml::Map(vec![(key.clone(), value.clone())]));
        match out.iter_mut().find(|(name, _)| name == key) {
            Some(slot) => slot.1 = lines,
            None => out.push((key.clone(), lines)),
        }
    }

    // -- any other user field is kept as written
    for (name, lines) in &chunks {
        if ORY_MANAGED.contains(&name.as_str()) {
            continue;
        }
        out.push((name.clone(), lines.clone()));
    }

    out.into_iter().flat_map(|(_, lines)| lines).collect()
}

fn ory_index_entry(line: &str) -> String {
    let marker = "VignetteIndexEntry{";
    match line.find(marker) {
        Some(pos) => {
            let rest = &line[pos + marker.len()..];
            match rest.find('}') {
                Some(end) => rest[..end].to_string(),
                None => rest.to_string(),
            }
        }
        None => String::new(),
    }
}

fn ory_strip_key(line: &str) -> String {
    match line.find(':') {
        Some(pos) => trim_ws(&line[pos + 1..]).to_string(),
        None => trim_ws(line).to_string(),
    }
}

fn ory_unquote_edges(text: &str) -> String {
    let mut value = text.to_string();
    if value.starts_with('"') || value.starts_with('\'') {
        value.remove(0);
    }
    if value.ends_with('"') || value.ends_with('\'') {
        value.pop();
    }
    value
}

fn ory_basename(path: &str) -> String {
    match path.rfind('/') {
        Some(pos) => path[pos + 1..].to_string(),
        None => path.to_string(),
    }
}

fn ory_dirname(path: &str) -> String {
    match path.rfind('/') {
        Some(0) => "/".to_string(),
        Some(pos) => path[..pos].to_string(),
        None => ".".to_string(),
    }
}

fn ory_file_path_sans_ext(path: &str) -> String {
    let name = ory_basename(path);
    match name.rfind('.') {
        Some(0) | None => name,
        Some(pos) => name[..pos].to_string(),
    }
}

fn ory_find_bib_files(path: &str) -> Vec<String> {
    let dir = ory_dirname(path);
    let mut names: Vec<String> = Vec::new();
    if let Ok(entries) = std::fs::read_dir(&dir) {
        for entry in entries.flatten() {
            let name = entry.file_name().to_string_lossy().to_string();
            if name.ends_with(".bib") {
                names.push(name);
            }
        }
    }
    names.sort();
    names
}

// ---------------------------------------------------------------------------
// Metadata
// ---------------------------------------------------------------------------

fn ory_meta_from_list(list: &List) -> Meta {
    Meta {
        package: ory_field_string(list, "package").unwrap_or_default(),
        title: ory_field_string(list, "title"),
        version: ory_field_string(list, "version").unwrap_or_default(),
        authors: ory_field_string(list, "authors"),
        date: ory_field_string(list, "date"),
        lang: ory_field_string(list, "lang").unwrap_or_else(|| "en-US".to_string()),
    }
}

fn ory_field(list: &List, name: &str) -> Option<Robj> {
    list.iter()
        .find(|(key, _)| *key == name)
        .map(|(_, value)| value)
}

fn ory_field_string(list: &List, name: &str) -> Option<String> {
    let value = ory_field(list, name)?;
    if value.is_null() || value.is_na() {
        return None;
    }
    value
        .as_string_vector()
        .and_then(|values| values.first().cloned())
}

// ---------------------------------------------------------------------------
// `.ory_read_rmd()` / `.ory_split_chunks()`
// ---------------------------------------------------------------------------

fn ory_is_header_fence(line: &str) -> bool {
    match line.strip_prefix("---") {
        Some(rest) => rest.chars().all(|c| c == ' ' || c == '\t' || c == '\r'),
        None => false,
    }
}

fn ory_is_end_fence(line: &str) -> bool {
    for fence in ["---", "..."] {
        if let Some(rest) = line.strip_prefix(fence) {
            if rest.chars().all(|c| c == ' ' || c == '\t' || c == '\r') {
                return true;
            }
        }
    }
    false
}

/// Split an Rmd into its YAML header and body.
///
/// An empty YAML block (`---` immediately followed by a closing fence) is a
/// valid header: `header` is then zero-length. Keep it that way -- the R side
/// asserts `length(rmd$header) == 0` for such files and feeds the value back
/// into the `ory_*_rs` wrappers, which take `Vec<String>` (not `Strings`) so
/// that a zero-length character vector is safe. Never add a placeholder line
/// here to "repair" an empty header.
fn ory_read_rmd_impl(lines: &[String]) -> (Vec<String>, Vec<String>) {
    let mut header: Vec<String> = Vec::new();
    let mut body: Vec<String> = lines.to_vec();

    if lines.first().map(|line| ory_is_header_fence(line)) == Some(true) {
        let end = (1..lines.len()).find(|&idx| ory_is_end_fence(&lines[idx]));
        if let Some(end) = end {
            // `end == 1` is the empty-header case. `1..1` and `len..len` are
            // empty slices, so both cases need no special-casing.
            header = lines[1..end].to_vec();
            body = lines[(end + 1).min(lines.len())..].to_vec();
            // Drop the blank line separating the YAML block from the body.
            if body.first().map(|line| trim_ws(line).is_empty()) == Some(true) {
                body.remove(0);
            }
        }
    }

    (header, body)
}

fn ory_is_key_line(line: &str) -> bool {
    let chars: Vec<char> = line.chars().collect();
    let mut idx = 0usize;
    if chars.is_empty() {
        return false;
    }
    let first = chars[0];
    if !(first.is_ascii_alphabetic() || first == '_') {
        return false;
    }
    while idx < chars.len() {
        let c = chars[idx];
        if c == ':' {
            return true;
        }
        let allowed = c.is_ascii_alphanumeric() || c == '_' || c == '.' || c == '-';
        if !allowed {
            break;
        }
        idx += 1;
    }
    // allow whitespace before the colon
    while idx < chars.len() && (chars[idx] == ' ' || chars[idx] == '\t') {
        idx += 1;
    }
    idx < chars.len() && chars[idx] == ':'
}

fn ory_key_name(line: &str) -> String {
    match line.find(':') {
        Some(pos) => trim_ws(&line[..pos]).to_string(),
        None => trim_ws(line).to_string(),
    }
}

fn ory_split_chunks_impl(header: &[String]) -> Vec<(String, Vec<String>)> {
    let mut chunks: Vec<(String, Vec<String>)> = Vec::new();
    if header.is_empty() {
        return chunks;
    }
    if !header.iter().any(|line| ory_is_key_line(line)) {
        return chunks;
    }

    let mut current: usize = 0;
    let mut started = false;
    for line in header {
        if ory_is_key_line(line) {
            if started {
                current = chunks.len();
            }
            let name = ory_key_name(line);
            if !started {
                // leading non-key lines join the first key chunk
                if chunks.is_empty() {
                    chunks.push((name, Vec::new()));
                    current = chunks.len() - 1;
                } else {
                    chunks[current].0 = name;
                }
                started = true;
            } else {
                chunks.push((name, Vec::new()));
                current = chunks.len() - 1;
            }
            chunks[current].1.push(line.clone());
        } else if started {
            chunks[current].1.push(line.clone());
        } else {
            // a line before the first key
            if chunks.is_empty() {
                chunks.push((String::new(), Vec::new()));
            }
            chunks[0].1.push(line.clone());
        }
    }

    chunks
}

// ---------------------------------------------------------------------------
// `.ory_default_title()` / `.ory_detect_type()`
// ---------------------------------------------------------------------------

fn ory_detect_type_impl(path: &str) -> &'static str {
    if ory_basename(path).to_lowercase() == "readme.rmd" {
        "readme"
    } else {
        "vignette"
    }
}

fn ory_default_title_impl(path: &str, type_: &str, meta: &Meta) -> String {
    if type_ == "readme" {
        return match &meta.title {
            Some(title) => format!("{}: {}", meta.package, title),
            None => meta.package.clone(),
        };
    }

    let base = ory_file_path_sans_ext(&ory_basename(path));
    if base == meta.package {
        return format!("Introduction to {}", meta.package);
    }
    ory_title_case(&ory_dash_to_space(&base))
}

fn ory_dash_to_space(text: &str) -> String {
    let mut out = String::new();
    let mut in_run = false;
    for c in text.chars() {
        if c == '-' || c == '_' || c == '.' {
            if !in_run {
                out.push(' ');
                in_run = true;
            }
        } else {
            out.push(c);
            in_run = false;
        }
    }
    out
}

/// Approximation of `tools::toTitleCase()`: words are capitalized unless they
/// are a lowercase connector, except for the first and the last word; words
/// that already contain an inner capital are kept as written.
fn ory_title_case(text: &str) -> String {
    const SMALL: [&str; 28] = [
        "a", "an", "and", "as", "at", "but", "by", "for", "from", "if", "in", "into", "is", "nor",
        "not", "of", "on", "or", "past", "per", "than", "that", "the", "to", "upon", "vs", "via",
        "with",
    ];
    let words: Vec<&str> = text.split_whitespace().collect();
    let last = words.len().saturating_sub(1);
    let mut out: Vec<String> = Vec::with_capacity(words.len());
    for (idx, word) in words.iter().enumerate() {
        let lower = word.to_lowercase();
        let has_inner_capital = word.chars().skip(1).any(|c| c.is_uppercase());
        if has_inner_capital {
            out.push(word.to_string());
            continue;
        }
        if SMALL.contains(&lower.as_str()) && idx != 0 && idx != last {
            out.push(lower);
            continue;
        }
        let mut chars = lower.chars();
        match chars.next() {
            Some(first) => out.push(format!("{}{}", first.to_uppercase(), chars.as_str())),
            None => out.push(lower),
        }
    }
    out.join(" ")
}

// ---------------------------------------------------------------------------
// `.ory_yq()` / `.ory_format_defaults()` / `.ory_default_output()`
// ---------------------------------------------------------------------------

fn ory_yq_impl(text: &str) -> String {
    let escaped = text.replace('\\', "\\\\").replace('"', "\\\"");
    format!("\"{}\"", escaped)
}

fn ory_format_defaults_impl(fmt: &str) -> Option<Yaml> {
    let pairs: Vec<(&str, Yaml)> = match fmt {
        "rmarkdown::html_vignette" | "html_vignette" => vec![
            ("toc", Yaml::Bool(true)),
            ("toc_depth", Yaml::Int(3)),
            ("number_sections", Yaml::Bool(true)),
            ("fig_caption", Yaml::Bool(true)),
            ("df_print", Yaml::Str("kable".to_string())),
        ],
        "html_document" => vec![
            ("toc", Yaml::Bool(true)),
            ("toc_float", Yaml::Bool(true)),
            ("theme", Yaml::Str("cosmo".to_string())),
            ("df_print", Yaml::Str("paged".to_string())),
        ],
        "github_document" => vec![("html_preview", Yaml::Bool(false))],
        "md_document" => vec![("variant", Yaml::Str("gfm".to_string()))],
        _ => return None,
    };
    Some(Yaml::Map(
        pairs
            .into_iter()
            .map(|(key, value)| (key.to_string(), value))
            .collect(),
    ))
}

fn ory_default_output_impl(type_: &str, readme_format: &str) -> Vec<String> {
    let fmt = if type_ == "vignette" {
        "rmarkdown::html_vignette"
    } else {
        match readme_format {
            "gfm" => "md_document",
            "github_document" => "github_document",
            _ => "html_document",
        }
    };
    let value = ory_format_defaults_impl(fmt).unwrap_or(Yaml::Null);
    ory_emit_yaml_impl(&Yaml::Map(vec![(
        "output".to_string(),
        Yaml::Map(vec![(fmt.to_string(), value)]),
    )]))
}

// ---------------------------------------------------------------------------
// `.ory_optimize_output()` / `.ory_merge_list()`
// ---------------------------------------------------------------------------

fn ory_optimize_output_impl(chunk: &[String], type_: &str) -> Option<Vec<String>> {
    if chunk.iter().any(|line| line.contains("!expr")) {
        return Some(chunk.to_vec());
    }

    let parsed = ory_yaml_parse(&chunk.join("\n"));
    let out = match &parsed {
        Some(Yaml::Map(pairs)) => pairs
            .iter()
            .find(|(key, _)| key == "output")
            .map(|(_, value)| value.clone()),
        _ => None,
    };
    let out = match out {
        Some(value) => value,
        None => return Some(chunk.to_vec()),
    };

    let usethis_default: Vec<&str> = if type_ == "vignette" {
        vec!["rmarkdown::html_vignette", "html_vignette"]
    } else {
        vec!["html_document", "github_document", "md_document"]
    };

    match &out {
        // Bare scalar: the usethis default is enriched, another format is kept.
        Yaml::Str(name) => {
            if usethis_default.contains(&name.as_str()) {
                None
            } else {
                Some(chunk.to_vec())
            }
        }
        Yaml::Map(pairs) => {
            let mut merged = pairs.clone();
            let mut changed = false;
            for (name, current) in pairs.iter() {
                let defaults = match ory_format_defaults_impl(name) {
                    Some(defaults) => defaults,
                    None => continue,
                };
                let new_value = match current {
                    Yaml::Null => Some(defaults),
                    Yaml::Str(value) if value == "default" => Some(defaults),
                    Yaml::Map(_) => Some(ory_merge_list_impl(current.clone(), defaults)),
                    _ => None,
                };
                if let Some(new_value) = new_value {
                    if new_value != *current {
                        changed = true;
                    }
                    if let Some(slot) = merged.iter_mut().find(|(key, _)| key == name) {
                        slot.1 = new_value;
                    }
                }
            }
            if !changed {
                return Some(chunk.to_vec());
            }
            Some(ory_emit_yaml_impl(&Yaml::Map(vec![(
                "output".to_string(),
                Yaml::Map(merged),
            )])))
        }
        _ => Some(chunk.to_vec()),
    }
}

fn ory_merge_list_impl(over: Yaml, base: Yaml) -> Yaml {
    match (over, base) {
        (Yaml::Map(mut over_pairs), Yaml::Map(base_pairs)) => {
            for (name, value) in base_pairs {
                match over_pairs.iter_mut().find(|(key, _)| *key == name) {
                    Some(slot) => {
                        if matches!(slot.1, Yaml::Map(_)) && matches!(value, Yaml::Map(_)) {
                            let inner = std::mem::replace(&mut slot.1, Yaml::Null);
                            slot.1 = ory_merge_list_impl(inner, value);
                        }
                    }
                    None => over_pairs.push((name, value)),
                }
            }
            Yaml::Map(over_pairs)
        }
        (over, _) => over,
    }
}

// ---------------------------------------------------------------------------
// YAML emitter
// ---------------------------------------------------------------------------

fn ory_emit_yaml_impl(value: &Yaml) -> Vec<String> {
    let mut out: Vec<String> = Vec::new();
    ory_emit_yaml_at(value, 0, &mut out);
    out
}

fn ory_emit_yaml_at(value: &Yaml, indent: usize, out: &mut Vec<String>) {
    let pad = " ".repeat(indent);
    match value {
        Yaml::Map(pairs) => {
            if pairs.is_empty() {
                out.push(format!("{}{{}}", pad));
                return;
            }
            for (key, item) in pairs {
                match item {
                    Yaml::Map(inner) if !inner.is_empty() => {
                        out.push(format!("{}{}:", pad, key));
                        ory_emit_yaml_at(item, indent + 2, out);
                    }
                    Yaml::Seq(inner) if !inner.is_empty() => {
                        out.push(format!("{}{}:", pad, key));
                        ory_emit_yaml_at(item, indent + 2, out);
                    }
                    _ => out.push(format!("{}{}: {}", pad, key, ory_yaml_scalar(item))),
                }
            }
        }
        Yaml::Seq(items) => {
            if items.is_empty() {
                out.push(format!("{}[]", pad));
                return;
            }
            for item in items {
                out.push(format!("{}- {}", pad, ory_yaml_scalar(item)));
            }
        }
        other => out.push(format!("{}{}", pad, ory_yaml_scalar(other))),
    }
}

fn ory_yaml_scalar(value: &Yaml) -> String {
    match value {
        Yaml::Null => "null".to_string(),
        Yaml::Bool(flag) => {
            if *flag {
                "true".to_string()
            } else {
                "false".to_string()
            }
        }
        Yaml::Int(number) => number.to_string(),
        Yaml::Real(number) => {
            if number.fract() == 0.0 {
                format!("{:.1}", number)
            } else {
                number.to_string()
            }
        }
        Yaml::Str(text) => ory_yaml_quote(text),
        Yaml::Seq(items) => {
            let inner: Vec<String> = items.iter().map(ory_yaml_scalar).collect();
            format!("[{}]", inner.join(", "))
        }
        Yaml::Map(pairs) => {
            let inner: Vec<String> = pairs
                .iter()
                .map(|(key, item)| format!("{}: {}", key, ory_yaml_scalar(item)))
                .collect();
            format!("{{{}}}", inner.join(", "))
        }
    }
}

/// Does a plain scalar look like a YAML timestamp (`1999-01-01`)? {yaml}
/// quotes those, so that reading the header back does not turn them into dates.
fn ory_yaml_looks_like_date(text: &str) -> bool {
    let bytes = text.as_bytes();
    bytes.len() >= 10
        && bytes[4] == b'-'
        && bytes[7] == b'-'
        && bytes[..4].iter().all(|c| c.is_ascii_digit())
        && bytes[5..7].iter().all(|c| c.is_ascii_digit())
        && bytes[8..10].iter().all(|c| c.is_ascii_digit())
}

fn ory_yaml_quote(text: &str) -> String {
    let starts_special = text.chars().next().map_or(false, |c| {
        matches!(
            c,
            '-' | '?' | ':' | ',' | '&' | '*' | '!' | '|' | '>' | '%' | '@' | '`'
        )
    });
    let plain = !text.is_empty()
        && text.trim() == text
        && !starts_special
        && !text.chars().any(|c| {
            matches!(
                c,
                ':' | '#' | '"' | '\'' | '\n' | '\r' | '\t' | '[' | ']' | '{' | '}' | ','
            )
        })
        && !matches!(
            text.to_lowercase().as_str(),
            "true" | "false" | "null" | "~" | "yes" | "no" | "on" | "off"
        )
        && text.parse::<f64>().is_err()
        && !ory_yaml_looks_like_date(text);

    if plain {
        return text.to_string();
    }
    // {yaml} prefers single quotes; it only falls back to double quotes when
    // the value itself contains a single quote.
    if text.contains('\'') {
        format!("\"{}\"", text.replace('\\', "\\\\").replace('"', "\\\""))
    } else {
        format!("'{}'", text)
    }
}

// ---------------------------------------------------------------------------
// YAML parser (block mappings, block sequences, flat flow collections)
// ---------------------------------------------------------------------------

fn ory_yaml_parse(text: &str) -> Option<Yaml> {
    let lines: Vec<&str> = text
        .lines()
        .filter(|line| {
            let trimmed = line.trim();
            !trimmed.is_empty() && !trimmed.starts_with('#')
        })
        .collect();
    if lines.is_empty() {
        return None;
    }
    let mut idx = 0usize;
    let indent = ory_yaml_indent(lines[0]);
    Some(ory_yaml_parse_block(&lines, &mut idx, indent))
}

fn ory_yaml_indent(line: &str) -> usize {
    line.chars().take_while(|c| *c == ' ').count()
}

fn ory_yaml_parse_block(lines: &[&str], idx: &mut usize, indent: usize) -> Yaml {
    if *idx >= lines.len() {
        return Yaml::Null;
    }

    let first = lines[*idx];
    let first_trimmed = first.trim_start();
    if first_trimmed.starts_with('-') {
        let mut items: Vec<Yaml> = Vec::new();
        while *idx < lines.len() {
            let line = lines[*idx];
            if ory_yaml_indent(line) != indent {
                break;
            }
            let trimmed = line.trim_start();
            if !trimmed.starts_with('-') {
                break;
            }
            let rest = trimmed[1..].trim().to_string();
            *idx += 1;
            if rest.is_empty() {
                let child_indent = if *idx < lines.len() {
                    ory_yaml_indent(lines[*idx])
                } else {
                    indent + 2
                };
                items.push(ory_yaml_parse_block(lines, idx, child_indent));
            } else if ory_yaml_split_key(&rest).is_some() {
                // `- key: value` opens an inline mapping
                let mut pairs: Vec<(String, Yaml)> = Vec::new();
                let (key, value) = ory_yaml_split_key(&rest).unwrap();
                pairs.push((key, ory_yaml_parse_scalar(&value)));
                while *idx < lines.len() && ory_yaml_indent(lines[*idx]) > indent {
                    let inner = lines[*idx].trim_start();
                    match ory_yaml_split_key(inner) {
                        Some((key, value)) => {
                            *idx += 1;
                            if value.is_empty() {
                                let child_indent = if *idx < lines.len() {
                                    ory_yaml_indent(lines[*idx])
                                } else {
                                    indent + 4
                                };
                                pairs.push((key, ory_yaml_parse_block(lines, idx, child_indent)));
                            } else {
                                pairs.push((key, ory_yaml_parse_scalar(&value)));
                            }
                        }
                        None => break,
                    }
                }
                items.push(Yaml::Map(pairs));
            } else {
                items.push(ory_yaml_parse_scalar(&rest));
            }
        }
        return Yaml::Seq(items);
    }

    let mut pairs: Vec<(String, Yaml)> = Vec::new();
    while *idx < lines.len() {
        let line = lines[*idx];
        if ory_yaml_indent(line) != indent {
            break;
        }
        let trimmed = line.trim_start();
        let (key, rest) = match ory_yaml_split_key(trimmed) {
            Some(pair) => pair,
            None => break,
        };
        *idx += 1;
        if rest.is_empty() {
            let next_indent = if *idx < lines.len() {
                ory_yaml_indent(lines[*idx])
            } else {
                indent
            };
            if *idx < lines.len() && next_indent > indent {
                pairs.push((key, ory_yaml_parse_block(lines, idx, next_indent)));
            } else {
                pairs.push((key, Yaml::Null));
            }
        } else if rest == "|" || rest == ">" {
            let mut buffer: Vec<String> = Vec::new();
            while *idx < lines.len() && ory_yaml_indent(lines[*idx]) > indent {
                buffer.push(lines[*idx].trim().to_string());
                *idx += 1;
            }
            pairs.push((key, Yaml::Str(buffer.join(" "))));
        } else {
            pairs.push((key, ory_yaml_parse_scalar(&rest)));
        }
    }
    Yaml::Map(pairs)
}

fn ory_yaml_split_key(line: &str) -> Option<(String, String)> {
    let chars: Vec<char> = line.chars().collect();
    let mut quote: Option<char> = None;
    for (idx, c) in chars.iter().enumerate() {
        match quote {
            Some(active) => {
                if *c == active {
                    quote = None;
                }
            }
            None => {
                if *c == '"' || *c == '\'' {
                    quote = Some(*c);
                } else if *c == ':' {
                    let next = chars.get(idx + 1).copied();
                    if next.is_none() || next == Some(' ') || next == Some('\t') {
                        let key: String = chars[..idx].iter().collect();
                        let rest: String = chars[(idx + 1)..].iter().collect();
                        return Some((ory_yaml_unquote(key.trim()), rest.trim().to_string()));
                    }
                }
            }
        }
    }
    None
}

fn ory_yaml_unquote(text: &str) -> String {
    let chars: Vec<char> = text.chars().collect();
    if chars.len() >= 2 {
        let first = chars[0];
        let last = chars[chars.len() - 1];
        if (first == '"' && last == '"') || (first == '\'' && last == '\'') {
            return chars[1..chars.len() - 1].iter().collect();
        }
    }
    text.to_string()
}

fn ory_yaml_parse_scalar(text: &str) -> Yaml {
    let text = text.trim();
    if text.is_empty() {
        return Yaml::Null;
    }
    if text.starts_with('[') && text.ends_with(']') {
        let inner = &text[1..text.len() - 1];
        let items: Vec<Yaml> = ory_yaml_split_flow(inner)
            .into_iter()
            .map(|item| ory_yaml_parse_scalar(&item))
            .collect();
        return Yaml::Seq(items);
    }
    if text.starts_with('{') && text.ends_with('}') {
        let inner = &text[1..text.len() - 1];
        let mut pairs: Vec<(String, Yaml)> = Vec::new();
        for item in ory_yaml_split_flow(inner) {
            if let Some((key, value)) = ory_yaml_split_key(&item) {
                pairs.push((key, ory_yaml_parse_scalar(&value)));
            }
        }
        return Yaml::Map(pairs);
    }
    if text.len() >= 2
        && ((text.starts_with('"') && text.ends_with('"'))
            || (text.starts_with('\'') && text.ends_with('\'')))
    {
        let inner = &text[1..text.len() - 1];
        return Yaml::Str(inner.replace("\\\"", "\"").replace("\\\\", "\\"));
    }
    match text.to_lowercase().as_str() {
        "true" | "yes" | "on" => return Yaml::Bool(true),
        "false" | "no" | "off" => return Yaml::Bool(false),
        "null" | "~" => return Yaml::Null,
        _ => {}
    }
    if let Ok(number) = text.parse::<i64>() {
        return Yaml::Int(number);
    }
    if let Ok(number) = text.parse::<f64>() {
        return Yaml::Real(number);
    }
    Yaml::Str(text.to_string())
}

fn ory_yaml_split_flow(text: &str) -> Vec<String> {
    let mut out: Vec<String> = Vec::new();
    let mut current = String::new();
    let mut depth = 0i32;
    let mut quote: Option<char> = None;
    for c in text.chars() {
        match quote {
            Some(active) => {
                current.push(c);
                if c == active {
                    quote = None;
                }
            }
            None => match c {
                '"' | '\'' => {
                    quote = Some(c);
                    current.push(c);
                }
                '[' | '{' => {
                    depth += 1;
                    current.push(c);
                }
                ']' | '}' => {
                    depth -= 1;
                    current.push(c);
                }
                ',' if depth == 0 => {
                    out.push(current.trim().to_string());
                    current.clear();
                }
                _ => current.push(c),
            },
        }
    }
    if !current.trim().is_empty() {
        out.push(current.trim().to_string());
    }
    out
}

// ---------------------------------------------------------------------------
// R <-> YAML conversion
// ---------------------------------------------------------------------------

fn ory_yaml_from_robj(obj: &Robj) -> Yaml {
    if obj.is_null() {
        return Yaml::Null;
    }
    if let Some(list) = obj.as_list() {
        let has_names = list.iter().all(|(name, _)| !name.is_empty());
        if has_names && !list.is_empty() {
            let pairs: Vec<(String, Yaml)> = list
                .iter()
                .map(|(name, value)| (name.to_string(), ory_yaml_from_robj(&value)))
                .collect();
            return Yaml::Map(pairs);
        }
        let items: Vec<Yaml> = list
            .values()
            .map(|value| ory_yaml_from_robj(&value))
            .collect();
        return Yaml::Seq(items);
    }
    if let Some(values) = obj.as_logical_vector() {
        if values.len() == 1 {
            return Yaml::Bool(values[0].to_bool());
        }
    }
    if let Some(values) = obj.as_integer_vector() {
        if values.len() == 1 {
            return Yaml::Int(values[0] as i64);
        }
        return Yaml::Seq(
            values
                .into_iter()
                .map(|value| Yaml::Int(value as i64))
                .collect(),
        );
    }
    if let Some(values) = obj.as_real_vector() {
        if values.len() == 1 {
            return Yaml::Real(values[0]);
        }
        return Yaml::Seq(values.into_iter().map(Yaml::Real).collect());
    }
    if let Some(values) = obj.as_string_vector() {
        if values.len() == 1 {
            return Yaml::Str(values[0].clone());
        }
        return Yaml::Seq(values.into_iter().map(Yaml::Str).collect());
    }
    Yaml::Null
}

fn ory_yaml_to_robj(value: &Yaml) -> Robj {
    match value {
        Yaml::Null => Robj::from(()),
        Yaml::Bool(flag) => Robj::from(*flag),
        Yaml::Int(number) => Robj::from(*number as i32),
        Yaml::Real(number) => Robj::from(*number),
        Yaml::Str(text) => Robj::from(text.clone()),
        Yaml::Seq(items) => {
            let values: Vec<Robj> = items.iter().map(ory_yaml_to_robj).collect();
            let list: List = values.into_iter().collect();
            Robj::from(list)
        }
        Yaml::Map(pairs) => {
            let names: Vec<String> = pairs.iter().map(|(key, _)| key.clone()).collect();
            let values: Vec<Robj> = pairs
                .iter()
                .map(|(_, item)| ory_yaml_to_robj(item))
                .collect();
            match List::from_names_and_values(names, values) {
                Ok(list) => Robj::from(list),
                Err(_) => Robj::from(()),
            }
        }
    }
}

/// Named list to `(name, value)` pairs; unnamed entries are skipped.
fn ory_named_pairs(obj: &Robj) -> Vec<(String, Yaml)> {
    let mut out: Vec<(String, Yaml)> = Vec::new();
    if let Some(list) = obj.as_list() {
        for (name, value) in list.iter() {
            if name.is_empty() {
                continue;
            }
            out.push((name.to_string(), ory_yaml_from_robj(&value)));
        }
    }
    out
}

extendr_module! {
    mod ory;
    fn ory_read_rmd_rs;
    fn ory_split_chunks_rs;
    fn ory_yq_rs;
    fn ory_detect_type_rs;
    fn ory_emit_yaml_rs;
    fn ory_format_defaults_rs;
    fn ory_merge_list_rs;
    fn ory_default_output_rs;
    fn ory_optimize_output_rs;
    fn ory_default_title_rs;
    fn ory_build_header_rs;
}

#[cfg(test)]
mod tests {
    use super::*;

    fn ls(v: &[&str]) -> Vec<String> {
        v.iter().map(|s| s.to_string()).collect()
    }

    #[test]
    fn splits_header_chunks() {
        let chunks = ory_split_chunks_impl(&ls(&[
            "title: x",
            "output:",
            "  html_document:",
            "    toc: true",
        ]));
        assert_eq!(chunks.len(), 2);
        assert_eq!(chunks[0].0, "title");
        assert_eq!(chunks[1].1.len(), 3);
    }

    #[test]
    fn reads_rmd() {
        let (header, body) = ory_read_rmd_impl(&ls(&["---", "title: x", "---", "", "Body"]));
        assert_eq!(header, ls(&["title: x"]));
        assert_eq!(body, ls(&["Body"]));
    }

    #[test]
    fn reads_rmd_with_empty_header() {
        let lines = ls(&["---", "---", "", "Body"]);
        let (header, body) = ory_read_rmd_impl(&lines);
        assert!(header.is_empty());
        assert_eq!(body, ls(&["Body"]));
        assert!(ory_split_chunks_impl(&header).is_empty());
        let meta = Meta {
            package: "testpkg".to_string(),
            title: None,
            version: "1.0.0".to_string(),
            authors: None,
            date: None,
            lang: "en-US".to_string(),
        };
        let built =
            ory_build_header_impl(&header, "intro.Rmd", "vignette", &meta, "gfm", "auto", &[]);
        assert_eq!(built[0], "title: \"Intro\"");
    }

    #[test]
    fn reads_rmd_with_no_lines_and_no_closing_fence() {
        let (header, body) = ory_read_rmd_impl(&[]);
        assert!(header.is_empty());
        assert!(body.is_empty());

        let lines = ls(&["---", "---"]);
        let (header, body) = ory_read_rmd_impl(&lines);
        assert!(header.is_empty());
        assert!(body.is_empty());
    }

    #[test]
    fn default_output_for_readme() {
        assert_eq!(
            ory_default_output_impl("readme", "gfm"),
            ls(&["output:", "  md_document:", "    variant: gfm"])
        );
    }

    #[test]
    fn keeps_or_enriches_output() {
        assert!(ory_optimize_output_impl(&ls(&["output: html_document"]), "readme").is_none());
        assert_eq!(
            ory_optimize_output_impl(&ls(&["output: pdf_document"]), "readme").unwrap(),
            ls(&["output: pdf_document"])
        );
        let out = ory_optimize_output_impl(
            &ls(&["output:", "  html_document:", "    theme: cerulean"]),
            "readme",
        )
        .unwrap();
        assert_eq!(
            out,
            ls(&[
                "output:",
                "  html_document:",
                "    theme: cerulean",
                "    toc: true",
                "    toc_float: true",
                "    df_print: paged"
            ])
        );
    }

    #[test]
    fn title_case_of_file_name() {
        assert_eq!(
            ory_title_case(&ory_dash_to_space("getting-started")),
            "Getting Started"
        );
    }

    #[test]
    fn yaml_round_trip() {
        let value = ory_yaml_parse("output:\n  html_document:\n    toc: true\n");
        let text = ory_emit_yaml_impl(&value.unwrap());
        assert_eq!(text, ls(&["output:", "  html_document:", "    toc: true"]));
    }
}
