//! Parsing half of the standalone crawlers: the two GitHub payloads, and the
//! provenance header that `usethis::use_standalone()` writes into a file.
//!
//! Every function here is pure -- text in, owned data out -- so the interesting
//! logic is testable without a network and without a fixture server.

use serde_json::Value;

/// One entry of the `R/` listing returned by the `contents` API.
#[derive(Debug, Default, PartialEq)]
pub(super) struct ContentEntry {
    pub(super) name: String,
    pub(super) path: String,
    pub(super) sha: String,
    pub(super) size: Option<i64>,
    pub(super) url: String,
    pub(super) html_url: String,
    pub(super) git_url: String,
    pub(super) download_url: Option<String>,
    /// The `type` field of the API (`"file"`, `"dir"`, ...).
    pub(super) kind: String,
    /// Filled by the crawler from the file contents, never by the API.
    pub(super) description: Option<String>,
}

/// One hit of the `search/code` API.
#[derive(Debug, Default, PartialEq)]
pub(super) struct SearchItem {
    pub(super) repo: String,
    pub(super) name: String,
    pub(super) path: String,
    pub(super) sha: String,
    pub(super) url: String,
    pub(super) html_url: String,
    pub(super) git_url: String,
    pub(super) repo_url: String,
    pub(super) repo_description: Option<String>,
}

/// One page of `search/code` results.
#[derive(Debug, Default)]
pub(super) struct SearchPage {
    pub(super) total_count: usize,
    pub(super) items: Vec<SearchItem>,
}

/// A JSON field as text. Numbers and booleans are stringified, `null` and
/// missing fields become `None` so that R sees `NA`.
fn as_text(value: Option<&Value>) -> Option<String> {
    match value? {
        Value::String(text) => Some(text.clone()),
        Value::Number(number) => Some(number.to_string()),
        Value::Bool(flag) => Some(flag.to_string()),
        _ => None,
    }
}

fn field(object: &Value, key: &str) -> Option<String> {
    as_text(object.get(key))
}

/// Parse the `contents` API listing of a directory. A `404` body
/// (`{"message": "Not Found"}`) is not a listing, hence the array check.
pub(super) fn contents_entries(body: &str) -> Result<Vec<ContentEntry>, String> {
    let value: Value = serde_json::from_str(body)
        .map_err(|error| format!("GitHub returned invalid JSON for the R/ listing: {error}"))?;
    let array = value.as_array().ok_or_else(|| {
        format!(
            "GitHub did not return a directory listing: {}",
            excerpt(body)
        )
    })?;
    Ok(array.iter().map(content_entry).collect())
}

fn content_entry(object: &Value) -> ContentEntry {
    ContentEntry {
        name: field(object, "name").unwrap_or_default(),
        path: field(object, "path").unwrap_or_default(),
        sha: field(object, "sha").unwrap_or_default(),
        size: object.get("size").and_then(Value::as_i64),
        url: field(object, "url").unwrap_or_default(),
        html_url: field(object, "html_url").unwrap_or_default(),
        git_url: field(object, "git_url").unwrap_or_default(),
        download_url: field(object, "download_url"),
        kind: field(object, "type").unwrap_or_default(),
        description: None,
    }
}

/// Parse one page of `search/code` results. The `items` array is empty on the
/// last page, which is how the crawler detects that it is done.
pub(super) fn search_page(body: &str) -> Result<SearchPage, String> {
    let value: Value = serde_json::from_str(body)
        .map_err(|error| format!("GitHub returned invalid JSON for the code search: {error}"))?;
    let items: Vec<SearchItem> = value
        .get("items")
        .and_then(Value::as_array)
        .map(|array| array.iter().map(search_item).collect())
        .unwrap_or_default();
    let total_count = value
        .get("total_count")
        .and_then(Value::as_u64)
        .map_or(items.len(), |count| count as usize);
    Ok(SearchPage { total_count, items })
}

fn search_item(value: &Value) -> SearchItem {
    let repository = value.get("repository");
    SearchItem {
        repo: repository
            .and_then(|repo| field(repo, "full_name"))
            .unwrap_or_default(),
        name: field(value, "name").unwrap_or_default(),
        path: field(value, "path").unwrap_or_default(),
        sha: field(value, "sha").unwrap_or_default(),
        url: field(value, "url").unwrap_or_default(),
        html_url: field(value, "html_url").unwrap_or_default(),
        git_url: field(value, "git_url").unwrap_or_default(),
        repo_url: repository
            .and_then(|repo| field(repo, "html_url"))
            .unwrap_or_default(),
        repo_description: repository.and_then(|repo| field(repo, "description")),
    }
}

/// Standalone files are the ones `usethis::use_standalone()` keeps in sync with
/// their source package, identified by the `standalone-` prefix.
pub(super) fn is_standalone_name(name: &str) -> bool {
    name.starts_with("standalone-")
}

/// The `usethis::use_standalone()` call that imports `name` from `repo_spec`.
pub(super) fn usage_snippet(repo_spec: &str, name: &str) -> String {
    let identifier = name.strip_prefix("standalone-").unwrap_or(name);
    let identifier = identifier
        .strip_suffix(".R")
        .or_else(|| identifier.strip_suffix(".r"))
        .unwrap_or(identifier);
    format!("usethis::use_standalone(\"{repo_spec}\", \"{identifier}\")")
}

/// Description of one standalone file.
///
/// The `description:` field of the `# ---` provenance header wins, then its
/// `title:` field, then the roxygen title, then the first free roxygen line.
pub(super) fn standalone_description(text: &str) -> Option<String> {
    let fields = provenance_fields(text);
    for key in ["description", "title"] {
        let value = fields
            .iter()
            .find(|(name, _)| name == key)
            .map(|(_, value)| clean_text(value))
            .unwrap_or_default();
        if !value.is_empty() {
            return Some(value);
        }
    }
    roxygen_summary(text)
}

/// The `key: value` pairs of the `# ---` block at the top of the file.
///
/// A continuation line, without a colon, is appended to the previous value,
/// which is how YAML wraps a long description.
fn provenance_fields(text: &str) -> Vec<(String, String)> {
    let mut fields: Vec<(String, String)> = Vec::new();
    let mut inside = false;
    for line in text.lines() {
        let Some(comment) = line.trim().strip_prefix('#') else {
            if inside {
                break;
            }
            continue;
        };
        let content = comment.trim();
        if content == "---" {
            if inside {
                break;
            }
            inside = true;
            continue;
        }
        if !inside {
            continue;
        }
        match content.split_once(':') {
            Some((key, value)) => {
                fields.push((key.trim().to_ascii_lowercase(), value.trim().to_string()))
            }
            None => {
                if content.is_empty() {
                    continue;
                }
                if let Some((_, value)) = fields.last_mut() {
                    value.push(' ');
                    value.push_str(content);
                }
            }
        }
    }
    fields
}

/// Roxygen tags whose value is a one-line summary of the file.
#[derive(Clone, Copy, PartialEq)]
enum Tag {
    Title,
    Description,
}

/// The `@title` / `@description` tag of a roxygen block, or its first line.
fn roxygen_summary(text: &str) -> Option<String> {
    let mut first_line: Option<String> = None;
    let mut title: Option<String> = None;
    let mut description: Option<String> = None;
    let mut pending: Option<Tag> = None;

    for line in text.lines() {
        let Some(body) = line.trim_start().strip_prefix("#'") else {
            pending = None;
            continue;
        };
        let body = body.trim();
        if body.is_empty() {
            continue;
        }

        if let Some(rest) = body.strip_prefix('@') {
            let (tag, value) = rest.split_once(char::is_whitespace).unwrap_or((rest, ""));
            let value = value.trim();
            let tag = match tag {
                "title" => Tag::Title,
                "description" => Tag::Description,
                _ => {
                    pending = None;
                    continue;
                }
            };
            let slot = match tag {
                Tag::Title => &mut title,
                Tag::Description => &mut description,
            };
            pending = Some(tag);
            if !value.is_empty() && slot.is_none() {
                *slot = Some(value.to_string());
                pending = None;
            }
            continue;
        }

        match pending {
            Some(Tag::Title) if title.is_none() => {
                title = Some(body.to_string());
                pending = None;
            }
            Some(Tag::Description) if description.is_none() => {
                description = Some(body.to_string());
                pending = None;
            }
            Some(_) => {}
            None if first_line.is_none() => first_line = Some(body.to_string()),
            None => {}
        }
    }

    title
        .or(description)
        .or(first_line)
        .map(|value| clean_text(&value))
        .filter(|value| !value.is_empty())
}

/// Trim a YAML scalar and drop the quotes around it.
fn clean_text(value: &str) -> String {
    let trimmed = value.trim();
    let unquoted = trimmed
        .strip_prefix('"')
        .and_then(|inner| inner.strip_suffix('"'))
        .or_else(|| {
            trimmed
                .strip_prefix('\'')
                .and_then(|inner| inner.strip_suffix('\''))
        })
        .filter(|inner| !inner.is_empty())
        .unwrap_or(trimmed);
    unquoted.trim().to_string()
}

/// First `BODY_TAIL` characters of a body, for error messages.
fn excerpt(body: &str) -> String {
    const LIMIT: usize = 200;
    let trimmed = body.trim();
    let mut excerpt: String = trimmed.chars().take(LIMIT).collect();
    if trimmed.chars().count() > LIMIT {
        excerpt.push('…');
    }
    if excerpt.is_empty() {
        excerpt.push_str("empty response");
    }
    excerpt
}

#[cfg(test)]
mod tests {
    use super::*;

    const CONTENTS: &str = r#"[
        {"name":"standalone-types-check.R","path":"R/standalone-types-check.R",
         "sha":"abc","size":1024,"url":"https://api.github.com/url",
         "html_url":"https://github.com/html","git_url":"https://api.github.com/git",
         "download_url":"https://raw.githubusercontent.com/raw","type":"file",
         "_links":{"self":"https://api.github.com/self"}},
        {"name":"utils.R","path":"R/utils.R","sha":"def","size":10,
         "url":"u","html_url":"h","git_url":"g","download_url":"d","type":"file"}
    ]"#;

    const SEARCH: &str = r#"{"total_count":2,"incomplete_results":false,"items":[
        {"name":"standalone-utils.R","path":"R/standalone-utils.R","sha":"abc",
         "url":"https://api.github.com/url","html_url":"https://github.com/html",
         "git_url":"https://api.github.com/git",
         "repository":{"full_name":"owner/repo","html_url":"https://github.com/owner/repo",
                       "description":"An R package"}},
        {"name":"import-helper.R","path":"R/import-helper.R","sha":"def","url":"u",
         "html_url":"h","git_url":"g",
         "repository":{"full_name":"owner/repo2","html_url":"https://github.com/owner/repo2",
                       "description":null}}
    ]}"#;

    #[test]
    fn contents_are_read_in_order() {
        let entries = contents_entries(CONTENTS).expect("valid listing");
        assert_eq!(entries.len(), 2);
        assert_eq!(entries[0].name, "standalone-types-check.R");
        assert_eq!(entries[0].size, Some(1024));
        assert_eq!(
            entries[0].download_url.as_deref(),
            Some("https://raw.githubusercontent.com/raw")
        );
        assert_eq!(entries[0].kind, "file");
        assert_eq!(entries[0].description, None);
    }

    #[test]
    fn a_404_body_is_not_a_listing() {
        let error = contents_entries(r#"{"message":"Not Found"}"#).unwrap_err();
        assert!(error.contains("did not return a directory listing"));
        assert!(error.contains("Not Found"));
    }

    #[test]
    fn search_items_carry_the_repository_fields() {
        let page = search_page(SEARCH).expect("valid search");
        assert_eq!(page.total_count, 2);
        assert_eq!(page.items[0].repo, "owner/repo");
        assert_eq!(
            page.items[0].repo_description.as_deref(),
            Some("An R package")
        );
        assert_eq!(page.items[0].repo_url, "https://github.com/owner/repo");
        assert_eq!(page.items[1].repo_description, None);
    }

    #[test]
    fn only_the_standalone_prefix_is_kept() {
        let page = search_page(SEARCH).expect("valid search");
        let kept: Vec<&str> = page
            .items
            .iter()
            .filter(|item| is_standalone_name(&item.name))
            .map(|item| item.name.as_str())
            .collect();
        assert_eq!(kept, vec!["standalone-utils.R"]);
    }

    #[test]
    fn usage_drops_the_prefix_and_the_extension() {
        assert_eq!(
            usage_snippet("r-lib/rlang", "standalone-types-check.R"),
            "usethis::use_standalone(\"r-lib/rlang\", \"types-check\")"
        );
        assert_eq!(
            usage_snippet("owner/repo", "standalone-cli.r"),
            "usethis::use_standalone(\"owner/repo\", \"cli\")"
        );
    }

    #[test]
    fn description_comes_from_the_provenance_header() {
        let text = "# ---\n# repo: r-lib/rlang\n# description: Check argument types\n# ---\n\n#' Ignored title\n";
        assert_eq!(
            standalone_description(text).as_deref(),
            Some("Check argument types")
        );
    }

    #[test]
    fn description_keeps_a_wrapped_header_value() {
        let text = "# ---\n# description: A very long\n#   description\n# ---\n";
        assert_eq!(
            standalone_description(text).as_deref(),
            Some("A very long description")
        );
    }

    #[test]
    fn description_falls_back_to_the_roxygen_title() {
        let text = "# ---\n# repo: r-lib/rlang\n# ---\n\n#' Check argument types\n#'\n#' Longer text.\n#' @export\n";
        assert_eq!(
            standalone_description(text).as_deref(),
            Some("Check argument types")
        );
    }

    #[test]
    fn description_uses_a_tag_on_the_next_line() {
        let text = "#' @title\n#' Check argument types\n#' @param x A value\n";
        assert_eq!(
            standalone_description(text).as_deref(),
            Some("Check argument types")
        );
    }

    #[test]
    fn description_strips_the_quotes_of_a_yaml_scalar() {
        let text = "# ---\n# description: \"Quoted title\"\n# ---\n";
        assert_eq!(
            standalone_description(text).as_deref(),
            Some("Quoted title")
        );
    }

    #[test]
    fn a_file_without_a_header_or_roxygen_has_no_description() {
        assert_eq!(standalone_description("x <- 1\n"), None);
    }
}
