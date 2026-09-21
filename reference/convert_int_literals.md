# Add Explicit Integer Suffix `L` to Integer Literals

Converts bare integer literals to explicit integer form with an `L`
suffix, e.g. `seq_len(10)` becomes `seq_len(10L)`. Strings and comments
are left unchanged.

`convert_int_literals()` operates on one R file. When `path` is `NULL`
and RStudio is available, it uses the currently active document.
`package_convert_int_literals()` walks selected directories of an R
package and applies the same conversion to every `.R` / `.r` file found.

## Usage

``` r
package_convert_int_literals(
  path = NULL,
  dirs = c("R", "tests"),
  recursive = TRUE,
  ...
)

convert_int_literals(path = NULL, verbose = TRUE, ...)
```

## Arguments

- path:

  For `convert_int_literals()`, a character string specifying the R file
  to modify. If `NULL` and RStudio is available, the currently active
  document path is used.

  For `package_convert_int_literals()`, a character string specifying
  the package root. If `NULL`, the current working directory is used.

- dirs:

  Character vector of subdirectories relative to `path` to search. Used
  only by `package_convert_int_literals()`. Defaults to
  `c("R", "tests")`.

- recursive:

  Logical; recurse into subdirectories. Used only by
  `package_convert_int_literals()`. Default `TRUE`.

- ...:

  Additional arguments. Currently unused and must be empty.

- verbose:

  Logical; enable or disable per-file messages. Used only by
  `convert_int_literals()`. Default `TRUE`.

## Value

`convert_int_literals()` invisibly returns the modified file path.
`package_convert_int_literals()` invisibly returns a character vector of
modified file paths.

## Details

A token is treated as an integer literal when it is:

- a decimal integer (`10`, `0`, `-` is not part of the token), or

- a hexadecimal integer (`0xFF`, `0X10`),

and it is **not**:

- already suffixed with `L` / `l`,

- a floating-point number (`10.`, `1.0`, `.5`),

- scientific notation (`1e5`, `1E-3`),

- a complex literal (`10i`),

- adjacent to an identifier character (`a-zA-Z0-9._`).

## Examples

``` r
# \donttest{
# --- Single file ---
temp <- tempfile(fileext = ".R")
writeLines("tmp <- seq_len(10)", temp)
convert_int_literals(temp)
#> ✔ Added explicit integer suffixes in /tmp/Rtmp2FpQDd/file19221995e0b2.R
readLines(temp)
#> [1] "tmp <- seq_len(10L)"
# "tmp <- seq_len(10L)"

# --- Entire package ---
tmp_pkg <- tempdir()
usethis::create_package(tmp_pkg, open = FALSE)
#> ✔ Setting active project to "/tmp/Rtmp2FpQDd".
#> ✔ Creating R/.
#> ✔ Writing DESCRIPTION.
#> Package: Rtmp2FpQDd
#> Title: What the Package Does (One Line, Title Case)
#> Version: 0.0.0.9000
#> Authors@R (parsed):
#>     * First Last <first.last@example.com> [aut, cre]
#> Description: What the package does (one paragraph).
#> License: `use_mit_license()`, `use_gpl3_license()` or friends to
#>     pick a license
#> Config/roxygen2/version: 8.1.0
#> Encoding: UTF-8
#> Roxygen: list(markdown = TRUE)
#> ✔ Writing NAMESPACE.
#> ✔ Setting active project to "<no active project>".
writeLines("foo <- seq_len(42)", file.path(tmp_pkg, "R/foo.R"))
package_convert_int_literals(tmp_pkg)
#> ✔ Processed 1 file, updated 1
readLines(file.path(tmp_pkg, "R/foo.R"))
#> [1] "foo <- seq_len(42L)"
# }
```
