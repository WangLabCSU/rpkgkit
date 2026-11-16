# Inquire Standalone Files from a GitHub Repository

Retrieve information about all standalone R files in the R/ directory of
a GitHub repository. Standalone files are identified by the
"standalone-" prefix in their filename.

## Usage

``` r
inquire_standalone(owner, repo, ..., token = NULL)
```

## Arguments

- owner:

  A character string specifying the repository owner's username.

- repo:

  A character string specifying the repository name.

- ...:

  No arguments.

- token:

  A GitHub personal access token. When `NULL` (the default) the token is
  read from the `GITHUB_PAT` or `GITHUB_TOKEN` environment variable;
  without a token GitHub only allows 60 requests per hour.

## Value

A tibble with one row per standalone file:

- name, path, sha, size, url, html_url, git_url, download_url, type:

  The fields of the GitHub contents API entry of the file.

- repo:

  Character string, the repository identifier in "owner/repo" format.

- description:

  Character string, the description extracted from the file's provenance
  header (the `# ---` block written by
  [`usethis::use_standalone()`](https://usethis.r-lib.org/reference/use_standalone.html))
  or from its roxygen documentation, `NA` when the file has neither.

- usage:

  Character string, the code to import the standalone file using
  [`usethis::use_standalone()`](https://usethis.r-lib.org/reference/use_standalone.html).

## Details

The crawl runs in Rust. One request lists the `R/` directory through the
GitHub contents API; the listing is then filtered on the "standalone-"
prefix, sorted by file name and deduplicated, and the provenance header
of each remaining file is read with one download of its raw contents.

## Examples

``` r
if (FALSE) { # \dontrun{
inquire_standalone("r-lib", "rlang")
} # }
```
