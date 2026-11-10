# Detect Default Paths in Exported Function Arguments

CRAN does not allow exported functions to default a path-like argument
to a concrete location. This checker parses R source, finds exported
functions, and reports every argument whose name matches `arg_pattern`
and whose default value is not in `allow` (by default only `NULL`; an
argument with no default is always fine). Each hit is reported with
file, line, column and a caret (`^^^^`) marker under `arg = default`.

## Usage

``` r
package_fn_arg_path(
  path = NULL,
  arg_pattern = "path|file|filename",
  allow = "NULL",
  dirs = "R",
  verbose = TRUE,
  ...
)

detect_fn_arg_path(
  path = NULL,
  arg_pattern = "path|file|filename",
  exports = NULL,
  export_patterns = character(),
  allow = "NULL",
  verbose = TRUE,
  ...
)
```

## Arguments

- path:

  For `detect_fn_arg_path()`: path to an R file. If `NULL` and RStudio
  is available, the active document is used.

  For `package_fn_arg_path()`: root directory of an R package. Defaults
  to the current directory.

- arg_pattern:

  Regular expression matched (unanchored) against argument names. Use
  e.g. `"^(path|file|filename)$"` to avoid matching `profile`.

- allow:

  Character vector of default-value expressions (as written in the
  source, whitespace trimmed) that are acceptable. Defaults to `"NULL"`.

- dirs:

  Package-relative directories scanned by `package_fn_arg_path()`.

- verbose:

  Whether to emit results to the console.

- ...:

  Unused.

- exports:

  Character vector of exported function names.

- export_patterns:

  Character vector of regular expressions, as in `exportPattern()` in
  `NAMESPACE`.

## Value

Invisibly returns `TRUE` if no offending defaults are found, `FALSE`
otherwise.

## Single file vs package scope

- `detect_fn_arg_path()`:

  Operates on one R file. Use `exports` / `export_patterns` to say which
  top-level functions count as exported; when `exports` is `NULL` and no
  patterns are given, every top-level function in the file is checked.

- `package_fn_arg_path()`:

  Checks that `path` is an R package, reads exports from `NAMESPACE`,
  then scans `.R` files under `dirs` (default `"R"`).

## Examples

``` r
# \donttest{
file <- tempfile(fileext = ".R")
writeLines('read_it <- function(path = "~/data.csv", n = 1) NULL', file)
detect_fn_arg_path(file)
#> /tmp/RtmpWnqw2p/file1aa5b2791c0.R:1:21 read_it(): `path` defaults to
#> "~/data.csv"
#> read_it <- function(path = "~/data.csv", n = 1) NULL
#>                     ^^^^^^^^^^^^^^^^^^^
#> ✖ Found 1 argument with a default path in /tmp/RtmpWnqw2p/file1aa5b2791c0.R
# }
```
