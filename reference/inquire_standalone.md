# Inquire Standalone Files from a GitHub Repository

Retrieve information about all standalone R files in the R/ directory of
a GitHub repository. Standalone files are identified by the
"standalone-" prefix in their filename.

## Usage

``` r
inquire_standalone(owner, repo, ...)
```

## Arguments

- owner:

  A character string specifying the repository owner's username.

- repo:

  A character string specifying the repository name.

- ...:

  No arguments.

## Value

A tibble with three columns:

- `owner/repo`:

  Character string, the repository identifier in "owner/repo" format.

- description:

  Character string, the description extracted from the file's YAML
  header or roxygen documentation.

- usage:

  Character string, the code to import the standalone file using
  [`usethis::use_standalone()`](https://usethis.r-lib.org/reference/use_standalone.html).

## Details

This function queries the GitHub API to list files in the R/ directory,
filters for files starting with "standalone-", parses each file's YAML
metadata (delimited by "# —") and roxygen tags to extract descriptions,
and generates usage code for importing each standalone file.

## Examples

``` r
if (FALSE) { # \dontrun{
inquire_standalone("r-lib", "rlang")
} # }
```
