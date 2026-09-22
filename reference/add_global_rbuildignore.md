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
add_global_rbuildignore(
  ...,
  pattern = GLOBAL_RBUILDIGNORE_PATTERN,
  replace_default = FALSE,
  path = NULL
)
```

## Arguments

- ...:

  Additional regex patterns (character strings) to add beyond the
  selected patterns. Each must already be in `.Rbuildignore` regex
  format (e.g. `"^\\.myfile$"`).

- pattern:

  Character vector of `.Rbuildignore` patterns. By default, uses
  [GLOBAL_RBUILDIGNORE_PATTERN](https://wanglabcsu.github.io/rpkgkit/reference/GLOBAL_RBUILDIGNORE_PATTERN.md).

- replace_default:

  Logical. If `FALSE` (the default), `pattern` is appended to
  [GLOBAL_RBUILDIGNORE_PATTERN](https://wanglabcsu.github.io/rpkgkit/reference/GLOBAL_RBUILDIGNORE_PATTERN.md).
  If `TRUE`, `pattern` is used instead of the defaults.

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

# Use only a custom pattern set
add_global_rbuildignore(
  pattern = c("^\\.github$", "^docs$"),
  replace_default = TRUE
)
} # }
```
