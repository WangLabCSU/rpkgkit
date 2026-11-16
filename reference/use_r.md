# Set the minimum `R` version a package needs

`use_r()` scans the package sources for base R functions and syntax
introduced in recent R versions, then records the highest version it
finds in the `Depends` field of `DESCRIPTION` with
[`usethis::use_package()`](https://usethis.r-lib.org/reference/use_package.html).
`use_r_v4.1.0()` is a shortcut that always requires `R (>= 4.1.0)`, the
version that introduced `\()` and `|>`.

`use_r()` detects:

- `R (>= 4.1.0)`: `|>`, `\()`,
  [`isa()`](https://rdrr.io/r/base/class.html).

- `R (>= 4.2.0)`: the `_` pipe placeholder in a named argument,
  [`Sys.setLanguage()`](https://rdrr.io/r/base/gettext.html).

- `R (>= 4.3.0)`: the `_` pipe placeholder heading an extraction chain.

- `R (>= 4.4.0)`: `%||%`,
  [`sort_by()`](https://rdrr.io/r/base/sort_by.html),
  [`Tailcall()`](https://rdrr.io/r/base/Tailcall.html),
  [`Exec()`](https://rdrr.io/r/base/Tailcall.html).

- `R (>= 4.5.0)`: [`use()`](https://rdrr.io/r/base/use.html),
  [`grepv()`](https://rdrr.io/r/base/grep.html), the `penguins` dataset.

- `R (>= 4.6.0)`: `%notin%`,
  [`messageCondition()`](https://rdrr.io/r/base/conditions.html),
  `match.arg(several.ok = "all")`, `barplot(orderH =)`.

Names that the package defines itself, such as its own `%||%`, never
raise the requirement: they are reported and ignored. `|>`, `\()` and
the `_` placeholder are syntax rather than names, so they always count.
A `DESCRIPTION` that already requires a higher version is never
downgraded.

## Usage

``` r
use_r_v4.1.0(path = NULL, ...)

use_r(path = NULL, dirs = c("R", file.path("tests", "testthat")), ...)
```

## Arguments

- path:

  Path to the package root. If `NULL` (the default), the current working
  directory is used.

- ...:

  Must be empty. Reserved for future arguments.

- dirs:

  Package-relative directories scanned by `use_r()`. Defaults to `"R"`
  and `"tests/testthat"`; missing directories are ignored.

## Value

`use_r()` invisibly returns the detected minimum R version, or `NULL`
when nothing requires a recent R. `use_r_v4.1.0()` invisibly returns
`NULL`, called for side effects.

## Examples

``` r
if (FALSE) { # \dontrun{
tmpdir <- tempdir()
usethis::create_package(path = tmpdir)
use_r_v4.1.0(path = tmpdir)
use_r(path = tmpdir)
} # }
```
