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
package_print_and_cat(
  path = NULL,
  dirs = c("R", file.path("tests", "testthat")),
  test_included = lifecycle::deprecated(),
  fix = FALSE,
  ...
)

detect_print_and_cat(
  path = NULL,
  fix = FALSE,
  pattern_fn_names = DEFAULT_PATTERN_FN_NAMES,
  replace_default_pattern = FALSE,
  include_s3 = TRUE,
  include_refs = FALSE,
  verbose = TRUE,
  ...
)
```

## Arguments

- path:

  For `detect_print_and_cat()`: path to an R file. If `NULL` and RStudio
  is available, the active document path is used.

  For `package_print_and_cat()`: path to the root directory of an R
  package. If `NULL`, the function walks up from the active document to
  find the package root.

- dirs:

  Character vector of package-relative directories scanned by
  `package_print_and_cat()`. Defaults to `"R"` and `"tests/testthat"`.

- test_included:

  **\[deprecated\]**. Logical indicating whether to scan
  `tests/testthat/` in addition to `R/`. Use `dirs` instead. When
  supplied, `FALSE` scans only `R/`; `TRUE` scans both default
  directories.

- fix:

  Logical. If `TRUE`, replace `print(`/`cat(` with `message(` directly
  in the source file(s). Default is `FALSE`.

- ...:

  Additional arguments passed to utils::methods (currently unused).

- pattern_fn_names:

  Character vector of regular expressions matching function names whose
  return value is treated as a diagnostic string. A
  [`print()`](https://rdrr.io/r/base/print.html) whose first argument is
  a string literal or calls a matching function is flagged as a message.
  Extra patterns are appended to the default set unless
  `replace_default_pattern = TRUE`.

  To obtain the default patterns, use
  `rpkgkit:::DEFAULT_PATTERN_FN_NAMES`.

- replace_default_pattern:

  Logical. If `TRUE`, `pattern_fn_names` fully replaces the default set
  instead of extending it.

- include_s3:

  Logical. If `TRUE`, report
  [`print()`](https://rdrr.io/r/base/print.html) calls whose first
  argument is not string-like (S3 object printing). Default `TRUE`.

- include_refs:

  Logical. If `TRUE`, also report bare `print`/`cat` symbols (e.g.
  `lapply(x, print)`). Default `FALSE`.

- verbose:

  Whether to output information in console

## Value

Invisibly returns `TRUE` if no calls were found, `FALSE` otherwise.
Side-effect messages and caret markers are emitted via cli and
[`message`](https://rdrr.io/r/base/message.html).

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
#> print("hello") [message]
#> ^^^^^^
#> ✖ Found 1 unsupported call on line 1.

# --- With auto-fix ---
detect_print_and_cat(tmp, fix = TRUE)
#> ✔ Fixed 1 line in file1a6e206d00c8.R.
#> print("hello") [message]
#> ^^^^^^
#> ✖ Found 1 unsupported call on line 1.

# --- Entire package ---
pkg <- tempfile()
dir.create(file.path(pkg, "R"), recursive = TRUE)
writeLines('cat("debug\\n")', file.path(pkg, "R", "example.R"))
writeLines(c("Package: example", "Version: 0.0.1"),
           file.path(pkg, "DESCRIPTION"))
package_print_and_cat(pkg)
#> R/example.R: 1:
#> cat("debug\n") [message]
#> ^^^^
#> ✖ Found `print()`/`cat()` calls in 1 of 1 file.
# }
```
