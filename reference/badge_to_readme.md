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
# \donttest{
tmpdir <- tempdir()
usethis::create_package(path = tmpdir, open = FALSE)
#> ✔ Setting active project to "/tmp/RtmpoUhW6Z".
#> ✔ Creating R/.
#> ✔ Writing DESCRIPTION.
#> Package: RtmpoUhW6Z
#> Title: What the Package Does (One Line, Title Case)
#> Version: 0.0.0.9000
#> Authors@R (parsed):
#>     * First Last <first.last@example.com> [aut, cre]
#> Description: What the package does (one paragraph).
#> License: `use_mit_license()`, `use_gpl3_license()` or friends to
#>     pick a license
#> Config/roxygen2/version: 8.1.0
#> Encoding: UTF-8
#> Roxygen: list(markdown = TRUE)
#> ✔ Writing NAMESPACE.
#> ✔ Setting active project to "<no active project>".
usethis::proj_set(path = tmpdir)
#> ✔ Setting active project to "/tmp/RtmpoUhW6Z".
badger::badge_last_commit(alt = "last-commit") |> badge_to_readme(path = tmpdir)
#> Error in check_uses_git(): ✖ Cannot detect that project is already a Git repository.
#> ℹ Do you need to run `usethis::use_git()`?
# }
```
