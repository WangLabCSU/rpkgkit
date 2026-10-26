# Use a Vendor Package

Reference a permissively-licensed R package from GitHub for inclusion in
your own R package. This function:

- Creates `inst/vendor/pkg/` with LICENSE files and a README

- Creates `R/vendor-pkg.R` with attribution header and optional vendored
  code

- Creates `src/vendor-pkg.c`, `src/vendor-pkg.cpp` or
  `src/rust/src/vendor-pkg.rs` for vendored C, C++ or Rust sources

- Updates `DESCRIPTION` (`Authors@R` and `Copyright` fields)

- Prints an acknowledgement snippet for your README

## Usage

``` r
use_vendor(pkg, ..., branch = "main", path = NULL)
```

## Arguments

- pkg:

  GitHub repository specification in `"owner/repo"` form or a full
  GitHub URL (e.g. `"https://github.com/owner/repo"`).

- ...:

  File paths within the vendor package to copy into your package. Files
  are routed by extension: `.R` files are appended to `R/vendor-pkg.R`,
  `.c` files to `src/vendor-pkg.c`, `.cpp` files to
  `src/vendor-pkg.cpp`, and `.rs` files to `src/rust/src/vendor-pkg.rs`.
  Paths without a directory component are looked up in the conventional
  directory of their language. If empty (default), only the
  infrastructure is set up.

- branch:

  Github repository branch name. Defaults to `"main"`

- path:

  Path to the target package directory. If `NULL` (the default), uses
  the current working directory.

## Value

Invisibly returns `NULL`, called for side effects.

## Examples

``` r
if (FALSE) { # \dontrun{
use_vendor("hadley/emo", "R/zzz.R")
# C++ and Rust sources are routed to src/ and src/rust/src/
use_vendor("wurli/pedant", "R/utils.R", "src/foo.cpp", "src/lib.rs")
} # }
```
