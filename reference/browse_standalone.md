# Browse Standalone R Files Across GitHub

Search GitHub for all `standalone-*.R` files and return the file and
repository metadata of the matches as a tibble.

## Usage

``` r
browse_standalone(per_page = 100L, limit = 200L, ..., token = NULL)
```

## Arguments

- per_page:

  Number of items to request per page, between 1 and 100. Defaults to
  `100L`, the largest page GitHub serves.

- limit:

  Number of records to return. Defaults to `200L`; use `Inf` to request
  every record GitHub exposes. Each page of `per_page` records costs one
  search request, so a large `limit` can take a while.

- ...:

  No arguments.

- token:

  A GitHub personal access token. When `NULL` (the default) the token is
  read from the `GITHUB_PAT` or `GITHUB_TOKEN` environment variable;
  without a token GitHub only allows 60 requests per hour.

## Value

A tibble with columns:

- repo:

  Character. Repository identifier in "owner/repo" format.

- name:

  Character. File name (e.g. "standalone-utils.R").

- path:

  Character. File path within the repository (e.g.
  "R/standalone-utils.R").

- sha:

  Character. File SHA.

- url:

  Character. GitHub API URL for the file.

- html_url:

  Character. GitHub HTML URL for the file.

- git_url:

  Character. Git blob URL for the file.

- repo_url:

  Character. Repository URL on GitHub.

- repo_description:

  Character. Repository description from GitHub.

## Details

The crawl runs in Rust. It queries the GitHub Code Search API
(`GET /search/code`) with
`filename:standalone- language:R -filename:import-`, pages through the
results until `limit` rows are collected, drops the hits whose name does
not start with "standalone-" and removes duplicates. The search API
ranks by relevance and exposes at most 1,000 results, which covers the
vast majority of standalone files on GitHub.

## Note

Without a token GitHub applies strict rate limits (60 requests per
hour). Set `GITHUB_PAT` in `~/.Renviron` to lift them.

## Examples

``` r
if (FALSE) { # \dontrun{
  browse_standalone()
} # }
```
