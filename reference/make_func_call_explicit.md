# Make Function Calls Explicit

Add double colons (`::`) to function calls from specified packages to
make package dependencies explicit in R code.

## Usage

``` r
package_func_call_explicit(
  path = NULL,
  use_packages = current_packages(),
  ignore_functions = c(imported_functions(path), get_defined_fn(path)),
  ...
)

make_func_call_explicit(
  path = NULL,
  use_packages = current_packages(),
  ignore_functions = c(imported_functions(), get_defined_fn(path)),
  ...
)
```

## Arguments

- path:

  A character string specifying the path to the R file to modify. If
  `NULL` and RStudio is available, the currently active document path is
  used.

- use_packages:

  A character vector of package names to process. Defaults to
  [`current_packages()`](https://wanglabcsu.github.io/rpkgkit/reference/current_packages.md).

- ignore_functions:

  A character vector of function names to ignore. Defaults to
  `c(imported_functions(), get_defined_fn(path))`: the functions
  imported into `NAMESPACE` plus those defined in the target package, or
  in the target file when `path` is not a package root. Pass
  [`character()`](https://rdrr.io/r/base/character.html) to ignore
  nothing.

- ...:

  Additional arguments. Currently unused and must be empty.

## Value

Invisibly `TRUE` when the file was read successfully; the file is
modified in place as a side effect.

## Details

This function reads the specified R file, identifies function calls from
the specified packages, and adds explicit namespace qualifiers (`::`) to
those calls. Exported datasets from the same packages are qualified as
well (e.g. `penguins` becomes `palmerpenguins::penguins`). The modified
code is written back to the original file.

The file is tokenized in Rust, following R's lexical rules for strings,
raw strings, comments and backtick names. A name is qualified only when
it is actually a call or a dataset, so `pkg::fun`, `obj$fun`, `obj@fun`,
function definitions (`fun <- function(...)`), formal arguments and the
identifiers passed to [`data()`](https://rdrr.io/r/utils/data.html) are
left untouched. In particular, `l$select + 1` is not rewritten even when
[`dplyr::select`](https://dplyr.tidyverse.org/reference/select.html) is
in `use_packages`.

This function replaces the
[`add_double_colons()`](https://wanglabcsu.github.io/rpkgkit/reference/add_double_colons.md)
engine adapted from the [pedant](https://github.com/wurli/pedant)
package by Jacob Scott et al., licensed under MIT.

## Functions

- `package_func_call_explicit()`: Processes all `.R` files in a
  package's `R/` directory, adding explicit namespace qualifiers.

## Examples

``` r
# \donttest{
file <- tempfile(fileext = ".R")
writeLines("
starwars |>
 mutate(name, bmi = mass / ((height / 100)^2)) |>
 select(name:mass, bmi)
", file)
make_func_call_explicit(
  path = file,
  use_packages = c("dplyr"),
  ignore_functions = c("library", "require")
)
#> ✔ Successfully made function call explicit in /tmp/RtmphLetMC/file210233b03c5d.R
readLines(file) |> message()
#> dplyr::starwars |> dplyr::mutate(name, bmi = mass / ((height / 100)^2)) |> dplyr::select(name:mass, bmi)
# }
```
