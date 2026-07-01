# Detect Lost Glue Brace in `glue` and `cli` Expressions

Check whether `{` and `}` are balanced in all `glue()` / `glue_data()`
and `cli_*()` string arguments within an R file. The file is parsed into
an AST, then each string literal that is an argument to a target
function is checked with a stack-based brace matcher. Any mismatches are
reported with line number and a visual caret (`^^^^`) marker under the
problematic region.

## Usage

``` r
package_lost_glue_brace(path = NULL, test_included = TRUE, ...)

detect_lost_glue_brace(path = NULL, ...)
```

## Arguments

- path:

  A character string specifying the path to the R file to inspect. If
  `NULL` and RStudio is available, the currently active document path is
  used.

- test_included:

  Whether to include test (`test/testthat/*`) files in the check.

- ...:

  unused

## Value

Invisibly returns `TRUE` if all expressions are balanced, `FALSE`
otherwise. Side-effect messages are emitted via
[cli::cli](https://cli.r-lib.org/reference/cli.html).

## Functions

- `package_lost_glue_brace()`: Scans all `.R` files in an R package (and
  optionally `tests/testthat/`), aggregated with per-file reporting.

## Examples

``` r
# \donttest{
file <- tempfile()
writeLines("glue(\"{a\")", file)
detect_lost_glue_brace(file)
#> glue("{a")
#>       ^^
#> ✖ Found 1 line with mismatched braces: 1
# }
```
