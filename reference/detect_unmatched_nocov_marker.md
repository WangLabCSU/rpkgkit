# Detect Unmatched `nocov` Markers

Check whether the `nocov start` and `nocov end` comment markers in R
source files are consistent.

Every marker is first located on its own line and column, and the
markers are then checked against the rules below.

Detection is purely textual: every line is scanned for a marker comment,
so a marker that hides inside a string literal or inside a documentation
comment (a roxygen `#'` line) is reported as well. This is intentional –
such a marker has no effect on coverage, which usually means it is a
leftover that should be removed by hand.

## Usage

``` r
package_unmatched_nocov_marker(path = NULL, dirs = "R", verbose = TRUE)

detect_unmatched_nocov_marker(path = NULL, verbose = TRUE, ...)
```

## Arguments

- path:

  For `detect_unmatched_nocov_marker()`: path to an R file. If `NULL`
  and RStudio is available, the active document path is used.

  For `package_unmatched_nocov_marker()`: path to the root directory of
  an R package. Defaults to the current directory.

- dirs:

  Character vector of package-relative directories scanned by
  `package_unmatched_nocov_marker()`. Defaults to `"R"`.

- verbose:

  Whether to emit detection results to the console.

- ...:

  Unused.

## Value

Invisibly returns `TRUE` when the markers of the file follow the rules
above, and `FALSE` otherwise. Each problem is printed with its line and
column, the source line and a caret marker pointing at the offending
comment, so that the fix is left to the user.

## Marker rules

A file may contain at most one `nocov start` and at most one `nocov end`
marker, so the two counts must be equal: either both are present or
neither is.

- Second and later `nocov start`:

  Reported as a problem: only the first start is meaningful, so every
  further start is echoed with its line and column.

- Second and later `nocov end`:

  Reported as a problem for the same reason.

- `nocov start` without `nocov end`:

  Reported as a problem: `covr::package_coverage()` aborts with a "range
  start but only range ends" error when a start is never closed, so a
  lone start must be fixed.

- `nocov end` without `nocov start`:

  Reported as a problem: the block it closes does not exist.

- `nocov end` before `nocov start`:

  Reported as a problem: the end must come after the start. Markers are
  compared by line first and then by column, so an end placed later on
  the same line is accepted.

## Single file vs package scope

- `detect_unmatched_nocov_marker()`:

  Operates on one R file. When `path` is `NULL` and RStudio is
  available, the currently active document path is used.

- `package_unmatched_nocov_marker()`:

  Scans the `.R` files under the configured package-relative
  directories, by default `R/`, and reports every problem together with
  its file name and line number.

## Examples

``` r
# \donttest{
file <- tempfile(fileext = ".R")
writeLines(c("f <- function() 1", paste0("# nocov", " end")), file)
detect_unmatched_nocov_marker(file)
#> ✖ `nocov end` at line 2, column 1 has no matching `nocov start`.
#> # nocov end
#> ^^^^^^^^^^^
#> ✖ Found 1 mismatched `nocov` marker on line 2.
# }
```
