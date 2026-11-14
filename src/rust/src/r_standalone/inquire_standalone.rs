//! Crawl the `R/` directory of one GitHub repository for its standalone files.
//!
//! The listing comes from the `contents` API, which is one request; the
//! description of each file costs one more request against
//! `raw.githubusercontent.com`, where GitHub does not count it against the API
//! rate limit.

use extendr_api::prelude::*;
use extendr_api::Result;

use super::columns;
use super::http::{GithubClient, GithubError, GithubResult};
use super::parse::{self, ContentEntry};

const API_ROOT: &str = "https://api.github.com/repos";

fn contents_url(repo_spec: &str) -> String {
    format!("{API_ROOT}/{repo_spec}/contents/R")
}

/// The standalone files of `repo_spec`, sorted by name and without duplicates.
fn crawl(client: &GithubClient, repo_spec: &str) -> GithubResult<Vec<ContentEntry>> {
    let body = client.get_api(&contents_url(repo_spec), &[])?;
    let mut entries = parse::contents_entries(&body).map_err(GithubError::new)?;
    entries.retain(|entry| parse::is_standalone_name(&entry.name));
    entries.sort_by(|left, right| left.name.cmp(&right.name));
    entries.dedup_by(|left, right| left.name == right.name);
    Ok(entries)
}

/// Read the provenance header of every file. A download that fails only costs
/// the description: the listing itself stays useful.
fn fill_descriptions(client: &GithubClient, entries: &mut [ContentEntry]) {
    for entry in entries.iter_mut() {
        let Some(url) = entry.download_url.as_deref() else {
            continue;
        };
        if let Ok(text) = client.get_raw(url) {
            entry.description = parse::standalone_description(&text);
        }
    }
}

fn entries_to_list(repo_spec: &str, entries: &[ContentEntry]) -> List {
    let count = entries.len();
    List::from_pairs([
        (
            "name",
            columns::text(entries.iter().map(|e| e.name.clone())),
        ),
        (
            "path",
            columns::text(entries.iter().map(|e| e.path.clone())),
        ),
        ("sha", columns::text(entries.iter().map(|e| e.sha.clone()))),
        (
            "size",
            // `f64` rather than `i32`: a size never collides with `NA_integer_`
            // and R is not limited to 2^31 bytes.
            Robj::from(
                entries
                    .iter()
                    .map(|e| e.size.map_or(f64::na(), |size| size as f64))
                    .collect::<Vec<f64>>(),
            ),
        ),
        ("url", columns::text(entries.iter().map(|e| e.url.clone()))),
        (
            "html_url",
            columns::text(entries.iter().map(|e| e.html_url.clone())),
        ),
        (
            "git_url",
            columns::text(entries.iter().map(|e| e.git_url.clone())),
        ),
        (
            "download_url",
            columns::optional_text(entries.iter().map(|e| e.download_url.clone())),
        ),
        (
            "type",
            columns::text(entries.iter().map(|e| e.kind.clone())),
        ),
        (
            "repo",
            columns::text(std::iter::repeat_n(repo_spec.to_string(), count)),
        ),
        (
            "description",
            columns::optional_text(entries.iter().map(|e| e.description.clone())),
        ),
        (
            "usage",
            columns::text(
                entries
                    .iter()
                    .map(|e| parse::usage_snippet(repo_spec, &e.name)),
            ),
        ),
    ])
}

/// Crawl the standalone files of a GitHub repository.
///
/// `repo_spec` is the `"owner/repo"` identifier and `token` an empty string for
/// an unauthenticated client. Returns one named column per field of the listing.
/// @keywords internal
#[extendr]
pub fn inquire_standalone_rs(repo_spec: &str, token: &str) -> Result<List> {
    let client = GithubClient::new(token);
    let mut entries = crawl(&client, repo_spec).map_err(|error| Error::Other(error.to_string()))?;
    fill_descriptions(&client, &mut entries);
    Ok(entries_to_list(repo_spec, &entries))
}

extendr_module! {
    mod inquire_standalone;
    fn inquire_standalone_rs;
}
