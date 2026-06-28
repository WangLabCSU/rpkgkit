# Make Function Calls Explicit

Add double colons (`::`) to function calls from specified packages to
make package dependencies explicit in R code.

This function uses code adapted from the
[pedant](https://github.com/wurli/pedant) package by Jacob Scott et al.,
licensed under MIT.

## Usage

``` r
package_func_call_explicit(
  path = ".",
  use_packages = current_packages(),
  ignore_functions = imported_functions(),
  ...
)

make_func_call_explicit(
  path = NULL,
  use_packages = current_packages(),
  ignore_functions = imported_functions(),
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
  [`imported_functions()`](https://wanglabcsu.github.io/rpkgkit/reference/current_packages.md).

- ...:

  Additional arguments. Currently unused and must be empty.

## Value

Invisible `NULL`. This function is called for its side effect of
modifying the specified file in place.

## Details

This function reads the specified R file, identifies function calls from
the specified packages, and adds explicit namespace qualifiers (`::`) to
those calls. The modified code is written back to the original file.

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
#> ℹ Retrieving function calls from dplyr
#> ✔ Successfully made function call explicit in /tmp/RtmpFu9fmT/file1a355fbbe7f1.R
readLines(file) |> message()
#> starwars |> dplyr::mutate(name, bmi = mass / ((height / 100)^2)) |> dplyr::select(name:mass, bmi)
# }
```
