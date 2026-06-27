# Check that all exported functions are listed in pkgdown reference

Parses the `NAMESPACE` and `_pkgdown.yml` (if present) and reports any
exported functions that are missing from the pkgdown reference index.

## Usage

``` r
check_pkgdown_reference(pkg = ".")
```

## Arguments

- pkg:

  Character. Path to the package root directory. Defaults to the current
  RStudio project or `"."`.

## Value

Invisibly returns a character vector of missing function names, or
`NULL` if `_pkgdown.yml` does not exist. Prints a summary via `cli`.

## Examples

``` r
if (FALSE) { # \dontrun{
dir <- tempdir()
usethis::create_package(dir)
usethis::proj_set(dir)
usethis::use_pkgdown()
check_pkgdown_reference(dir)
} # }
```
