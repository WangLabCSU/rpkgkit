# Add a minimum `R` version dependency to a package

Adds `R (>= 4.1.0)` to the `Depends` field of a package's `DESCRIPTION`
file. This sets a minimum R version requirement for your package. Then
you can use `\()` and `|>` syntax in your package.

- Requires that the target directory is an R package root (contains a
  `DESCRIPTION` file).

- Calls
  [`usethis::use_package()`](https://usethis.r-lib.org/reference/use_package.html)
  to add the dependency.

## Usage

``` r
use_r_v4.1.0(path = NULL, ...)
```

## Arguments

- path:

  Path to the package root. If `NULL` (the default), the current working
  directory is used.

- ...:

  Must be empty. Reserved for future arguments.

## Value

Invisibly returns `NULL`, called for side effects.

## Examples

``` r
# \donttest{
tmpdir <- tempdir()
usethis::create_package(path = tmpdir)
#> ✔ Setting active project to "/tmp/Rtmp88Qrsk".
#> ✔ Creating R/.
#> ✔ Writing DESCRIPTION.
#> Package: Rtmp88Qrsk
#> Title: What the Package Does (One Line, Title Case)
#> Version: 0.0.0.9000
#> Authors@R (parsed):
#>     * First Last <first.last@example.com> [aut, cre]
#> Description: What the package does (one paragraph).
#> License: `use_mit_license()`, `use_gpl3_license()` or friends to
#>     pick a license
#> Encoding: UTF-8
#> Roxygen: list(markdown = TRUE)
#> RoxygenNote: 8.0.0
#> ✔ Writing NAMESPACE.
#> ✔ Setting active project to "<no active project>".
use_r_v4.1.0(path = tmpdir)
#> ✔ Setting active project to "/tmp/Rtmp88Qrsk".
#> ✔ Adding R to Depends field in DESCRIPTION.
# }
```
