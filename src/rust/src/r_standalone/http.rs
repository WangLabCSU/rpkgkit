//! Blocking GitHub transport for the standalone crawlers.
//!
//! Only two shapes are needed: a JSON `GET` against `api.github.com` and a
//! plain `GET` of a raw file. Pagination, filtering and parsing live in the
//! callers, so this layer stays small enough to audit: one agent, one optional
//! bearer token, and errors that already read like a message for R.

use std::time::Duration;

use serde_json::Value;
use ureq::Agent;

const API_ACCEPT: &str = "application/vnd.github+json";
const API_VERSION: &str = "2022-11-28";
const TIMEOUT: Duration = Duration::from_secs(30);
/// GitHub rejects a request without a `User-Agent`.
const USER_AGENT: &str = concat!("rpkgkit/", env!("CARGO_PKG_VERSION"));
/// Longest slice of a non-JSON error body kept in the message.
const BODY_TAIL: usize = 200;

/// A failed crawl, formatted for `stop()` in R.
#[derive(Debug)]
pub(super) struct GithubError(String);

impl GithubError {
    pub(super) fn new(message: impl Into<String>) -> Self {
        Self(message.into())
    }
}

impl std::fmt::Display for GithubError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(&self.0)
    }
}

pub(super) type GithubResult<T> = std::result::Result<T, GithubError>;

pub(super) struct GithubClient {
    agent: Agent,
    token: Option<String>,
}

impl GithubClient {
    /// An empty `token` builds an unauthenticated client, which GitHub limits
    /// to 60 requests per hour.
    pub(super) fn new(token: &str) -> Self {
        let agent = Agent::config_builder()
            .user_agent(USER_AGENT)
            .http_status_as_error(false)
            .timeout_global(Some(TIMEOUT))
            .build()
            .new_agent();
        let token = (!token.is_empty()).then(|| token.to_string());
        Self { agent, token }
    }

    /// `GET` a JSON endpoint of the REST API.
    ///
    /// `url` carries no query string; every `params` pair is percent-encoded by
    /// `ureq`, which matters for the spaces of the code-search query.
    pub(super) fn get_api(&self, url: &str, params: &[(&str, String)]) -> GithubResult<String> {
        let mut request = self
            .agent
            .get(url)
            .header("Accept", API_ACCEPT)
            .header("X-GitHub-Api-Version", API_VERSION);
        for (key, value) in params {
            request = request.query(*key, value);
        }
        if let Some(token) = &self.token {
            request = request.header("Authorization", format!("Bearer {token}"));
        }
        let mut response = request.call().map_err(|error| {
            GithubError::new(format!("GitHub request to {url} failed: {error}"))
        })?;
        let status = response.status().as_u16();
        let body = response.body_mut().read_to_string().map_err(|error| {
            GithubError::new(format!(
                "Could not read the GitHub response from {url}: {error}"
            ))
        })?;
        if (200..300).contains(&status) {
            return Ok(body);
        }
        Err(GithubError::new(status_message(status, url, &body)))
    }

    /// `GET` a raw file, without the API headers of [`GithubClient::get_api`].
    pub(super) fn get_raw(&self, url: &str) -> GithubResult<String> {
        let mut response = self
            .agent
            .get(url)
            .call()
            .map_err(|error| GithubError::new(format!("Download of {url} failed: {error}")))?;
        let status = response.status().as_u16();
        let body = response.body_mut().read_to_string().map_err(|error| {
            GithubError::new(format!("Could not read the download of {url}: {error}"))
        })?;
        if (200..300).contains(&status) {
            return Ok(body);
        }
        Err(GithubError::new(status_message(status, url, &body)))
    }
}

/// Turn an unsuccessful response into one sentence, keeping the `message` field
/// that explains 404 (missing repository) and 403 (rate limit).
fn status_message(status: u16, url: &str, body: &str) -> String {
    let detail = serde_json::from_str::<Value>(body)
        .ok()
        .and_then(|value| {
            value
                .get("message")
                .and_then(Value::as_str)
                .map(str::to_owned)
        })
        .unwrap_or_else(|| body.trim().chars().take(BODY_TAIL).collect());

    let mut message = if detail.is_empty() {
        format!("GitHub returned HTTP {status} for {url}")
    } else {
        format!("GitHub returned HTTP {status} for {url}: {detail}")
    };
    if status == 401 || status == 403 {
        message.push_str(
            " (authenticate with a token, for example by setting GITHUB_PAT, to raise the rate limit)",
        );
    }
    message
}

#[cfg(test)]
mod tests {
    use super::status_message;

    #[test]
    fn status_message_keeps_the_github_message() {
        let body = r#"{"message":"API rate limit exceeded for 1.2.3.4.","documentation_url":"x"}"#;
        let message = status_message(403, "https://api.github.com/search/code", body);
        assert!(message.contains("HTTP 403"));
        assert!(message.contains("API rate limit exceeded"));
        assert!(message.contains("GITHUB_PAT"));
    }

    #[test]
    fn status_message_falls_back_to_the_body() {
        let message = status_message(502, "https://api.github.com/x", "  bad gateway\n");
        assert!(message.contains("HTTP 502"));
        assert!(message.contains("bad gateway"));
    }

    #[test]
    fn status_message_survives_an_empty_body() {
        let message = status_message(401, "https://api.github.com/x", " \n");
        assert!(message.starts_with("GitHub returned HTTP 401 for https://api.github.com/x"));
        assert!(message.contains("GITHUB_PAT"));
    }
}
