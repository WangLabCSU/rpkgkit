# Use a Vendor Package

Reference a permissively-licensed R package from GitHub for inclusion in
your own R package. This function:

- Creates `inst/vendor/<pkg>/` with LICENSE files and a README

- Creates `R/vendor-<pkg>.R` with attribution header and optional
  vendored code

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

  File paths within the vendor package to copy into your package and
  append to the vendor R file. If empty (default), only the
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
use_vendor("wurli/pedant")
use_vendor("https://github.com/wurli/pedant", "R/add_double_colons.R")
} # }
```
