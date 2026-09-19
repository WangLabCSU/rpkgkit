# Apply `convert_int_literals()` to an R Package

Walks the `R/` and `tests/` directories of an R package and runs
[`convert_int_literals()`](https://wanglabcsu.github.io/rpkgkit/reference/convert_int_literals.md)
on every `.R` / `.r` file.

## Usage

``` r
package_convert_int_literals(
  path = NULL,
  dirs = c("R", "tests"),
  recursive = TRUE,
  ...
)
```

## Arguments

- path:

  Character path to the package root. If `NULL` and RStudio is
  available, the active document's project / working directory is used
  only when it looks like a package root (`DESCRIPTION` present).

- dirs:

  Character vector of subdirectories relative to `path` to search.
  Defaults to `c("R", "tests")`.

- recursive:

  Logical; recurse into subdirectories. Default `TRUE`.

- ...:

  Additional arguments. Currently unused and must be empty.

## Value

Invisibly returns a character vector of modified file paths.

## Examples

``` r
# \donttest{
tmp_pkg <- tempdir()
usethis::create_package(tmp_pkg, open = FALSE)
#> ✔ Setting active project to "/tmp/RtmpM6i24U".
#> ✔ Creating R/.
#> ✔ Writing DESCRIPTION.
#> Package: RtmpM6i24U
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
message(readLines(file.path(tmp_pkg, "R/foo.R")))
#> foo <- seq_len(42L)
# }
```
