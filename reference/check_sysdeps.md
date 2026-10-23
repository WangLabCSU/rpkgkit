# Check whether system development dependencies are installed

Detects the system package manager, checks each system dependency, and
reports the result with cli. Argument validation uses rlang.

## Usage

``` r
check_sysdeps(deps = NULL, manager = NULL, verbose = TRUE)
```

## Arguments

- deps:

  A character vector of system package names to check. Names must match
  the naming convention of the package manager in use. If `NULL`, a
  built-in list of graphics and font related dependencies is used.

- manager:

  The package manager: one of `"dpkg"`, `"rpm"`, `"pacman"`, `"apk"`, or
  `"brew"`. If `NULL`, it is detected automatically.

- verbose:

  Logical. If `TRUE` (the default), print the check results. If `FALSE`,
  no messages are printed.

## Value

A named logical vector (package name -\> installed or not), returned
invisibly.

## Examples

``` r
# \donttest{
check_sysdeps()
#> Package manager: dpkg
#> ✔ libfreetype-dev
#> ✔ libjpeg-dev
#> ✔ libpng-dev
#> ✔ libtiff-dev
#> ✔ libwebp-dev
#> ✔ libharfbuzz-dev
#> ✔ libfribidi-dev
#> ✔ libfontconfig1-dev
#> ✔ All 8 system dependencies installed.
check_sysdeps(c("freetype-devel", "libwebp-devel"), manager = "rpm")
#> Package manager: rpm
#> ✖ freetype-devel
#> ✖ libwebp-devel
#> ! Missing 2 dependencies: freetype-devel and libwebp-devel
#> ℹ Try installing with: `sudo dnf install -y freetype-devel libwebp-devel`
ok <- check_sysdeps(verbose = FALSE)
ok[!ok]
#> named logical(0)
# }
```
