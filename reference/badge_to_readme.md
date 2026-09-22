# Insert a badge into README badges block

Adds a markdown badge (typically from badger) to the
`<!-- badges: start -->` ... `<!-- badges: end -->` block in
`README.Rmd` or `README.md`.

If both files exist, only `README.Rmd` is updated.

## Usage

``` r
badge_to_readme(badge, path = NULL, ...)
```

## Arguments

- badge:

  Character. Badge markdown, e.g. the output of
  [`badger::badge_code_size()`](https://rdrr.io/pkg/badger/man/badge_code_size.html).

- path:

  Character. Path to the package root. If `NULL` (the default), uses the
  current working directory.

- ...:

  Not used.

## Value

Invisibly returns the path to the modified README file.

## Examples

``` r
if (FALSE) { # \dontrun{
try({
  tmpdir <- tempdir()
  usethis::create_package(path = tmpdir, open = FALSE)
  usethis::proj_set(path = tmpdir)
  badger::badge_last_commit(alt = "last-commit") |> badge_to_readme(path = tmpdir)
})
} # }
```
