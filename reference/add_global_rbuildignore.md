# Add global .Rbuildignore patterns

Appends a curated set of common files and directories to `.Rbuildignore`
to exclude them from R package builds. This supplements the
auto-generated `.Rbuildignore` created by
[`usethis::create_package()`](https://usethis.r-lib.org/reference/create_package.html).

Already-present patterns are silently skipped. The curated set covers: R
build artifacts, Git files, IDE/dev tool directories, CI/CD config,
documentation build artifacts, CRAN/development files, and other common
files that should not be shipped with a package.

## Usage

``` r
add_global_rbuildignore(..., path = NULL)
```

## Arguments

- ...:

  Additional regex patterns (character strings) to add beyond the
  curated defaults. Each must already be in `.Rbuildignore` regex format
  (e.g. `"^\\.myfile$"`).

- path:

  Character. Path to the package root directory. If `NULL` (the
  default), uses the current working directory.

## Value

Invisibly returns the path to `.Rbuildignore`.

## Examples

``` r
if (FALSE) { # \dontrun{
add_global_rbuildignore()

# With additional custom patterns
add_global_rbuildignore("^\\.myconfig$", "^data-raw$")
} # }
```
