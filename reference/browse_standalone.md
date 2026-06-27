# Browse Standalone R Files Across GitHub

Search GitHub for all `standalone-*.R` files and filter to only include
repositories that are R packages (contain a `DESCRIPTION` file in their
root directory). Results are returned as a tibble with file and
repository metadata.

## Usage

``` r
browse_standalone(per_page = 100L, limit = 200L, ...)
```

## Arguments

- per_page:

  Number of items to return per page. If omitted, will be substituted by
  max(.limit, 100) if .limit is set, otherwise determined by the API
  (never greater than 100).

- limit:

  Number of records to return. This can be used instead of manual
  pagination. By default it is NULL, which means that the defaults of
  the GitHub API are used. You can set it to a number to request more
  (or less) records, and also to Inf to request all records. Note, that
  if you request many records, then multiple GitHub API calls are used
  to get them, and this can take a potentially long time.

- ...:

  pass to [`gh::gh()`](https://gh.r-lib.org/reference/gh.html)

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

This function uses the GitHub Code Search API (`GET /search/code`) to
find all files matching the pattern `standalone-*.R` across all public
repositories. It then checks each unique repository for the presence of
a `DESCRIPTION` file in the repository root, confirming it is an R
package. Only files from R package repositories are returned.

GitHub Search API returns at most 1,000 results, which covers the vast
majority of standalone files on GitHub.

## Note

Requires GitHub API authentication via the `gh` package. Run
[`gh::gh_whoami()`](https://gh.r-lib.org/reference/gh_whoami.html) to
check your current authentication status. Unauthenticated requests are
subject to strict rate limits (60 requests/hour).

## Examples

``` r
if (FALSE) { # \dontrun{
  browse_standalone()
} # }
```
