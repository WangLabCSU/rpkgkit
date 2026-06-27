# Detect Lost Glue Brace in `glue` and `cli` Expressions

Check whether `{` and `}` are balanced in all `glue()` / `glue_data()`
and `cli_*()` string arguments within an R file. The file is parsed into
an AST, then each string literal that is an argument to a target
function is checked with a stack-based brace matcher. Any mismatches are
reported with line number and a visual caret (`^^^^`) marker under the
problematic region.

## Usage

``` r
detect_lost_glue_brace(path = NULL)
```

## Arguments

- path:

  A character string specifying the path to the R file to inspect. If
  `NULL` and RStudio is available, the currently active document path is
  used.

## Value

Invisibly returns `TRUE` if all expressions are balanced, `FALSE`
otherwise. Side-effect messages are emitted via
[cli::cli](https://cli.r-lib.org/reference/cli.html).

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
