//! Search GitHub for `standalone-*.R` files across public repositories.
//!
//! The code-search API pages with `page` / `per_page`, ranks by relevance and
//! never exposes more than 1,000 results, so the crawl stops at whichever of
//! those limits is reached first.

use std::collections::HashSet;

use extendr_api::prelude::*;
use extendr_api::Result;

use super::columns;
use super::http::{GithubClient, GithubError, GithubResult};
use super::parse::{self, SearchItem};

const SEARCH_URL: &str = "https://api.github.com/search/code";
/// Same query as the GitHub web UI: standalone files, in R, without the
/// `import-*.R` files that `renv` generates.
const SEARCH_QUERY: &str = "filename:standalone- language:R -filename:import-";
/// The search API never returns more than 1,000 results.
const MAX_RESULTS: usize = 1000;
const MAX_PER_PAGE: usize = 100;

/// Crawl the result pages until `limit` items are collected or GitHub runs out.
fn crawl(per_page: usize, limit: usize, token: &str) -> GithubResult<Vec<SearchItem>> {
    let client = GithubClient::new(token);
    let per_page = per_page.clamp(1, MAX_PER_PAGE);
    let mut items: Vec<SearchItem> = Vec::new();
    let mut seen: HashSet<(String, String)> = HashSet::new();
    let mut fetched = 0;
    let mut number = 1;

    while fetched < MAX_RESULTS {
        let body = client.get_api(
            SEARCH_URL,
            &[
                ("q", SEARCH_QUERY.to_string()),
                ("per_page", per_page.to_string()),
                ("page", number.to_string()),
            ],
        )?;
        let page = parse::search_page(&body).map_err(GithubError::new)?;
        if page.items.is_empty() {
            break;
        }
        fetched += page.items.len();

        for item in page.items {
            if !parse::is_standalone_name(&item.name) {
                continue;
            }
            if seen.insert((item.repo.clone(), item.path.clone())) {
                items.push(item);
            }
            if items.len() >= limit {
                break;
            }
        }

        if items.len() >= limit || fetched >= page.total_count {
            break;
        }
        number += 1;
    }

    items.truncate(limit);
    Ok(items)
}

fn items_to_list(items: &[SearchItem]) -> List {
    List::from_pairs([
        ("repo", columns::text(items.iter().map(|i| i.repo.clone()))),
        ("name", columns::text(items.iter().map(|i| i.name.clone()))),
        ("path", columns::text(items.iter().map(|i| i.path.clone()))),
        ("sha", columns::text(items.iter().map(|i| i.sha.clone()))),
        ("url", columns::text(items.iter().map(|i| i.url.clone()))),
        (
            "html_url",
            columns::text(items.iter().map(|i| i.html_url.clone())),
        ),
        (
            "git_url",
            columns::text(items.iter().map(|i| i.git_url.clone())),
        ),
        (
            "repo_url",
            columns::text(items.iter().map(|i| i.repo_url.clone())),
        ),
        (
            "repo_description",
            columns::optional_text(items.iter().map(|i| i.repo_description.clone())),
        ),
    ])
}

/// Search GitHub for standalone files, at most `limit` of them.
///
/// `per_page` is the page size of the underlying search (1 to 100), `limit` the
/// number of rows to return and `token` an empty string for an unauthenticated
/// client. Returns one named column per field of the search hit.
/// @keywords internal
#[extendr]
pub fn browse_standalone_rs(per_page: i32, limit: f64, token: &str) -> Result<List> {
    let limit = if limit.is_finite() {
        limit.max(1.0) as usize
    } else {
        MAX_RESULTS
    };
    let items = crawl(per_page.max(1) as usize, limit, token)
        .map_err(|error| Error::Other(error.to_string()))?;
    Ok(items_to_list(&items))
}

extendr_module! {
    mod browse_standalone;
    fn browse_standalone_rs;
}
