# Detect Lost Glue Brace in `glue` and `cli` Expressions

Check whether `{` and `}` are balanced in all `glue()` / `glue_data()`
and `cli_*()` string arguments within R source files. Each file is
parsed into an AST, then every string literal passed to a target
function is checked with a stack-based brace matcher. Any mismatch is
reported with its line number and a visual caret (`^^^^`) marker under
the problematic region.

## Usage

``` r
package_lost_glue_brace(
  path = NULL,
  dirs = c("R", file.path("tests", "testthat")),
  test_included = lifecycle::deprecated(),
  ...
)

detect_lost_glue_brace(path = NULL, verbose = TRUE, ...)
```

## Arguments

- path:

  For `detect_lost_glue_brace()`: path to an R file. If `NULL` and
  RStudio is available, the active document path is used.

  For `package_lost_glue_brace()`: path to the root directory of an R
  package. Defaults to the current directory.

- dirs:

  Character vector of package-relative directories scanned by
  `package_lost_glue_brace()`. Defaults to `"R"` and `"tests/testthat"`.

- test_included:

  **\[deprecated\]**. Logical indicating whether to scan
  `tests/testthat/` in addition to `R/`. Use `dirs` instead. When
  supplied, `FALSE` scans only `R/`; `TRUE` scans both default
  directories.

- ...:

  Unused.

- verbose:

  Whether to emit detection results to the console. Package scanning
  disables this and supplies its own progress and summary output.

## Value

Invisibly returns `TRUE` if all expressions are balanced, `FALSE`
otherwise.

## Single file vs package scope

- `detect_lost_glue_brace()`:

  Operates on one R file. When `path` is `NULL` and RStudio is
  available, the currently active document path is used.

- `package_lost_glue_brace()`:

  Scans `.R` files under the configured package-relative directories. By
  default, these are `R/` and `tests/testthat/`.

## Examples

``` r
# \donttest{
file <- tempfile(fileext = ".R")
writeLines('glue("{a")', file)
detect_lost_glue_brace(file)
#> glue("{a")
#>       ^^
#> ✖ Found 1 line with mismatched braces: 1
# }
```
