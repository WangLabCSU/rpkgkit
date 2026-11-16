use extendr_api::prelude::*;
use extendr_api::Result;
use regex::Regex;

/// Collect the names of the function definitions found in source lines.
///
/// Rust rewrite of `rpkgkit:::detect_func_defs()`. Matches
/// `name <- function(` / `name = function(` and the R 4.1 lambda shorthand
/// `name <- \(`, with optional backtick quoting of the name. Only the first
/// definition of each line is reported, and duplicates are dropped.
/// @keywords internal
#[extendr]
pub fn rf_detect_func_defs_rs(lines: Strings) -> Result<Strings> {
    let values: Vec<String> = lines.iter().map(|line| line.to_string()).collect();
    Ok(Strings::from_values(rf_detect_defs_impl(&values)?))
}

fn rf_detect_defs_impl(lines: &[String]) -> Result<Vec<String>> {
    let pattern =
        r#"`?((?:[a-zA-Z._][a-zA-Z0-9._]*)|(?:`[^`]+`))`?\s*(?:<-|=)\s*(?:function\s*\(|\\\s*\()"#;
    let re = match Regex::new(pattern) {
        Ok(re) => re,
        Err(err) => return Err(format!("invalid function-definition pattern: {}", err).into()),
    };

    let mut names: Vec<String> = Vec::new();
    for line in lines {
        let line: &str = line.as_str();
        let raw = match re.captures(line).and_then(|caps| caps.get(1)) {
            Some(matched) => matched.as_str(),
            None => continue,
        };
        let name = match raw
            .strip_prefix('`')
            .and_then(|rest| rest.strip_suffix('`'))
        {
            Some(stripped) => stripped,
            None => raw,
        };
        if !names.iter().any(|existing| existing == name) {
            names.push(name.to_string());
        }
    }
    Ok(names)
}

/// Convert one R identifier to a target naming style.
///
/// Rust rewrite of `rpkgkit:::to_style()`. `num_lookup` is a named list whose
/// names are digit abbreviations and whose values are the words they stand for
/// (`list("2" = "to", "4" = "for")`); `NULL` disables the expansion.
/// @keywords internal
#[extendr]
pub fn rf_to_style_rs(name: &str, style: &str, num_lookup: Nullable<List>) -> String {
    let lookup = rf_lookup(&num_lookup);
    rf_to_style_impl(name, style, &lookup)
}

/// Expand mapped digit runs of one word into separate words.
///
/// Rust rewrite of `rpkgkit:::split_word_numbers()`. Returns a character
/// vector. A word with any unmapped digit run is returned unchanged, as a
/// single element, so `log10` and `x10y` survive.
/// @keywords internal
#[extendr]
pub fn rf_split_word_numbers_rs(word: &str, num_lookup: Nullable<List>) -> Strings {
    let lookup = rf_lookup(&num_lookup);
    Strings::from_values(rf_split_word_numbers_impl(word, &lookup))
}

/// Replace whole R identifiers throughout the source text.
///
/// Rust rewrite of the `gsub()` renaming loop of `rename_func()`. The R version
/// used Perl look-around to ensure the old name is not part of a longer
/// identifier; Rust's regex engine has no look-around, so the boundary check is
/// done explicitly. Returns `list(text = ..., n_renamed = ...)`.
/// @keywords internal
#[extendr]
pub fn rf_rename_text_rs(text: &str, old_names: Strings, new_names: Strings) -> List {
    let mut current = text.to_string();
    let mut n_renamed = 0i32;
    for (old, new) in old_names.iter().zip(new_names.iter()) {
        let old: &str = old;
        let new: &str = new;
        let (updated, hit) = rf_replace_identifier(&current, old, new);
        if hit {
            n_renamed += 1;
        }
        current = updated;
    }
    List::from_pairs([
        ("text", Robj::from(current)),
        ("n_renamed", Robj::from(n_renamed)),
    ])
}

/// A `num_lookup` R list becomes `(digit abbreviation, word)` pairs.
fn rf_lookup(num_lookup: &Nullable<List>) -> Vec<(String, String)> {
    match num_lookup {
        Nullable::Null => Vec::new(),
        Nullable::NotNull(list) => list
            .iter()
            .filter_map(|(key, value)| {
                let word = value.as_string_vector()?.first()?.clone();
                Some((key.to_string(), word))
            })
            .collect(),
    }
}

fn rf_is_ident_char(c: char) -> bool {
    c.is_ascii_alphanumeric() || c == '.' || c == '_'
}

fn rf_is_lower_or_digit(c: char) -> bool {
    c.is_ascii_lowercase() || c.is_ascii_digit()
}

fn rf_capitalize(word: &str) -> String {
    let mut chars = word.chars();
    match chars.next() {
        Some(first) => first.to_uppercase().collect::<String>() + chars.as_str(),
        None => String::new(),
    }
}

fn rf_to_style_impl(name: &str, style: &str, lookup: &[(String, String)]) -> String {
    // Step 1: insert an underscore before lower/digit -> uppercase transitions.
    let chars: Vec<char> = name.chars().collect();
    let mut underscored = String::with_capacity(name.len() + 4);
    for (idx, c) in chars.iter().enumerate() {
        if idx > 0 && rf_is_lower_or_digit(chars[idx - 1]) && c.is_ascii_uppercase() {
            underscored.push('_');
        }
        underscored.push(*c);
    }

    // Step 2: collapse runs of separators into a single space.
    let mut spaced = String::with_capacity(underscored.len());
    let mut in_separator = false;
    for c in underscored.chars() {
        if c == '_' || c == '.' {
            if !in_separator {
                spaced.push(' ');
                in_separator = true;
            }
        } else {
            spaced.push(c);
            in_separator = false;
        }
    }

    // Step 3: lowercase and split into words.
    let lowered = spaced.to_lowercase();
    let mut words: Vec<String> = lowered
        .split(' ')
        .filter(|word| !word.is_empty())
        .map(|word| word.to_string())
        .collect();
    if words.is_empty() {
        return spaced;
    }

    // Step 4: expand digit abbreviations.
    if !lookup.is_empty() {
        let mut expanded: Vec<String> = Vec::new();
        for word in &words {
            expanded.extend(rf_split_word_numbers_impl(word, lookup));
        }
        words = expanded;
    }

    match style {
        "snake_case" => words.join("_"),
        "camelCase" => {
            let mut out = words[0].clone();
            for word in words.iter().skip(1) {
                out.push_str(&rf_capitalize(word));
            }
            out
        }
        "PascalCase" => words.iter().map(|word| rf_capitalize(word)).collect(),
        "google" => words.join("."),
        _ => words.join("_"),
    }
}

/// Split a word into alternating non-digit / digit runs.
fn rf_digit_runs(word: &str) -> Vec<String> {
    let mut parts: Vec<String> = Vec::new();
    let mut current = String::new();
    let mut current_is_digit: Option<bool> = None;
    for c in word.chars() {
        let is_digit = c.is_ascii_digit();
        if current_is_digit != Some(is_digit) {
            if !current.is_empty() {
                parts.push(std::mem::take(&mut current));
            }
            current_is_digit = Some(is_digit);
        }
        current.push(c);
    }
    if !current.is_empty() {
        parts.push(current);
    }
    parts
}

fn rf_is_digit_run(part: &str) -> bool {
    !part.is_empty() && part.chars().all(|c| c.is_ascii_digit())
}

fn rf_lookup_word(part: &str, lookup: &[(String, String)]) -> Option<String> {
    lookup
        .iter()
        .find(|(digit, _)| digit == part)
        .map(|(_, word)| word.clone())
}

fn rf_split_word_numbers_impl(word: &str, lookup: &[(String, String)]) -> Vec<String> {
    if lookup.is_empty() || !word.chars().any(|c| c.is_ascii_digit()) {
        return vec![word.to_string()];
    }

    let parts = rf_digit_runs(word);
    // All-or-nothing: an unmapped digit run leaves the whole word alone.
    if parts
        .iter()
        .filter(|part| rf_is_digit_run(part))
        .any(|part| rf_lookup_word(part, lookup).is_none())
    {
        return vec![word.to_string()];
    }

    parts
        .iter()
        .map(|part| {
            if rf_is_digit_run(part) {
                rf_lookup_word(part, lookup).unwrap_or_else(|| part.clone())
            } else {
                part.clone()
            }
        })
        .collect()
}

/// Replace every whole-identifier occurrence of `old` with `new`.
fn rf_replace_identifier(text: &str, old: &str, new: &str) -> (String, bool) {
    if old.is_empty() {
        return (text.to_string(), false);
    }
    let chars: Vec<char> = text.chars().collect();
    let needle: Vec<char> = old.chars().collect();
    let n = chars.len();
    let m = needle.len();
    let mut out = String::with_capacity(text.len());
    let mut hit = false;
    let mut i = 0usize;

    while i < n {
        if i + m <= n && chars[i..i + m] == needle[..] {
            let before_ok = i == 0 || !rf_is_ident_char(chars[i - 1]);
            let after = i + m;
            let after_ok = after >= n || !rf_is_ident_char(chars[after]);
            if before_ok && after_ok {
                out.push_str(new);
                i += m;
                hit = true;
                continue;
            }
        }
        out.push(chars[i]);
        i += 1;
    }

    (out, hit)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn empty_lookup() -> Vec<(String, String)> {
        Vec::new()
    }

    fn default_lookup() -> Vec<(String, String)> {
        vec![
            ("4".to_string(), "for".to_string()),
            ("2".to_string(), "to".to_string()),
        ]
    }

    #[test]
    fn converts_between_styles() {
        assert_eq!(
            rf_to_style_impl("myFunctionName", "snake_case", &empty_lookup()),
            "my_function_name"
        );
        assert_eq!(
            rf_to_style_impl("MyFunction", "snake_case", &empty_lookup()),
            "my_function"
        );
        assert_eq!(
            rf_to_style_impl("my.function.name", "camelCase", &empty_lookup()),
            "myFunctionName"
        );
        assert_eq!(
            rf_to_style_impl("my_function_name", "PascalCase", &empty_lookup()),
            "MyFunctionName"
        );
        assert_eq!(
            rf_to_style_impl("myFunctionName", "google", &empty_lookup()),
            "my.function.name"
        );
        assert_eq!(
            rf_to_style_impl("getHTMLParser", "snake_case", &empty_lookup()),
            "get_htmlparser"
        );
        assert_eq!(
            rf_to_style_impl("test", "PascalCase", &empty_lookup()),
            "Test"
        );
    }

    #[test]
    fn expands_digit_abbreviations() {
        let lookup = default_lookup();
        assert_eq!(
            rf_to_style_impl("list2env", "snake_case", &lookup),
            "list_to_env"
        );
        assert_eq!(
            rf_to_style_impl("list2env", "camelCase", &lookup),
            "listToEnv"
        );
        assert_eq!(
            rf_to_style_impl("convert2Json", "snake_case", &lookup),
            "convert_to_json"
        );
        assert_eq!(
            rf_to_style_impl("scale_x_log10", "snake_case", &lookup),
            "scale_x_log10"
        );
        assert_eq!(
            rf_split_word_numbers_impl("list2env", &lookup),
            vec!["list", "to", "env"]
        );
        assert_eq!(rf_split_word_numbers_impl("log10", &lookup), vec!["log10"]);
    }

    #[test]
    fn detects_definitions() {
        let lines = vec![
            "my_func <- function(x) x".to_string(),
            "`my func` = function(y) y".to_string(),
            "other <- \\(z) z".to_string(),
            "just_a_call <- helper(1)".to_string(),
        ];
        let names = rf_detect_defs_impl(&lines).unwrap();
        assert_eq!(names, vec!["my_func", "my func", "other"]);
    }

    #[test]
    fn replaces_whole_identifiers_only() {
        let (text, hit) = rf_replace_identifier(
            "foo_bar <- function() message('foo_bar'); foo_bar_x <- 1",
            "foo_bar",
            "fooBar",
        );
        assert!(hit);
        assert_eq!(
            text,
            "fooBar <- function() message('fooBar'); foo_bar_x <- 1"
        );
    }
}

extendr_module! {
    mod rf;
    fn rf_detect_func_defs_rs;
    fn rf_to_style_rs;
    fn rf_split_word_numbers_rs;
    fn rf_rename_text_rs;
}
