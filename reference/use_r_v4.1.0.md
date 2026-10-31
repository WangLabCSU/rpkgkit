# Add a minimum `R` version dependency to a package

Adds `R (>= 4.1.0)` to the `Depends` field of a package's `DESCRIPTION`
file. This sets a minimum R version requirement for your package. Then
you can use `\()` and `|>` syntax in your package.

- Requires that the target directory is an R package root (contains a
  `DESCRIPTION` file).

- Calls
  [`usethis::use_package()`](https://usethis.r-lib.org/reference/use_package.html)
  to add the dependency.

## Usage

``` r
use_r_v4.1.0(path = NULL, ...)
```

## Arguments

- path:

  Path to the package root. If `NULL` (the default), the current working
  directory is used.

- ...:

  Must be empty. Reserved for future arguments.

## Value

Invisibly returns `NULL`, called for side effects.

## Examples

``` r
if (FALSE) { # \dontrun{
tmpdir <- tempdir()
usethis::create_package(path = tmpdir)
use_r_v4.1.0(path = tmpdir)
} # }
```
