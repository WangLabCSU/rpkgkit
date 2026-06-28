# Detect `print()` and `cat()` Calls (CRAN-Unsafe)

Check whether R source files contain direct calls to
[`print()`](https://rdrr.io/r/base/print.html) or
[`cat()`](https://rdrr.io/r/base/cat.html), which are generally not
permitted by CRAN policies. Output should use
[`message`](https://rdrr.io/r/base/message.html) instead.

These functions parse R source code into an AST and identify every
`SYMBOL_FUNCTION_CALL` token whose text is `"print"` or `"cat"`. Each
match is reported with the line number, the full source line, and a
caret marker pointing at the offending call.

When `fix = TRUE`, the function performs a simple text replacement of
`print(` and `cat(` with `message(` on the affected lines. The
replacement uses word-boundary matching to avoid false positives inside
other identifiers (e.g. `sprintf` or `print.myclass`).

## Usage

``` r
package_print_and_cat(path = ".", test_included = TRUE, fix = FALSE, ...)

detect_print_and_cat(path = NULL, fix = FALSE, ...)
```

## Arguments

- path:

  For `detect_print_and_cat()`: path to an R file. If `NULL` and RStudio
  is available, the active document path is used.

  For `package_print_and_cat()`: path to the root directory of an R
  package. If `NULL`, the function walks up from the active document to
  find the package root.

- test_included:

  Logical, used only by `package_print_and_cat()`. If `TRUE` (the
  default), `.R` files under `tests/testthat/` are also scanned.

- fix:

  Logical. If `TRUE`, replace `print(`/`cat(` with `message(` directly
  in the source file(s). Default is `FALSE`.

- ...:

  Additional arguments passed to utils::methods (currently unused).

## Value

Invisibly returns `TRUE` if no calls were found, `FALSE` otherwise.
Side-effect messages and caret markers are emitted via cli and
[`message`](https://rdrr.io/r/base/message.html).

## Functions

- `package_print_and_cat()`: Scans all `.R` files in an R package (and
  optionally `tests/testthat/`), aggregated with per-file reporting.

## Single file vs package scope

- `detect_print_and_cat()`:

  Operates on one R file. When `path` is `NULL` and RStudio is
  available, the currently active document is used automatically.

- `package_print_and_cat()`:

  Scans all `.R` files in a package's `R/` directory, plus
  `tests/testthat/` when `test_included = TRUE`. Results are aggregated
  into a single report showing per-file summaries.

## Examples

``` r
# \donttest{
# --- Single file ---
tmp <- tempfile(fileext = ".R")
writeLines('print("hello")', tmp)
detect_print_and_cat(tmp)
#> print("hello")
#> ^^^^^^
#> ✖ Found 1 unsupported call on line 
#> 1.

# --- With auto-fix ---
detect_print_and_cat(tmp, fix = TRUE)
#> ✔ Fixed 1 line in file1a551f81bdc6.R.
#> print("hello")
#> ^^^^^^
#> ✖ Found 1 unsupported call on line 
#> 1.

# --- Entire package ---
pkg <- tempfile()
dir.create(file.path(pkg, "R"), recursive = TRUE)
writeLines('cat("debug\\n")', file.path(pkg, "R", "example.R"))
writeLines(c("Package: example", "Version: 0.0.1"),
           file.path(pkg, "DESCRIPTION"))
package_print_and_cat(pkg)
#> ℹ Scanning 1 file...
#> ✖ Found `print()`/`cat()` calls in 1 of 1 file:
#> example.R
#> Line 1:
#>     cat("debug\n")
#> ^^^^
#> 
# }
```
