# Make function calls explicit

This function takes a block of code and seeks to make all function calls
'explicit' through the use of the double-colon operator `::`. This
function is bound to the RStudio addin `"Make function calls explicit"`.
See examples for usage.

## Usage

``` r
add_double_colons(
  code = NULL,
  use_packages = current_packages(),
  ignore_functions = imported_functions()
)
```

## Arguments

- code:

  Code to transform. Either a character vector or `NULL`, in which case
  any highlighted code (in RStudio) will be used.

- use_packages:

  A character vector of package names. The order is important here - see
  examples for details.

- ignore_functions:

  Functions to ignore when applying the transformation

## Value

The transformed `code` as a character string

## Details

This function behaves differently depending on the context.

- **Not package development**: If the current context is not package
  development, then it will make function calls explicit using the
  currently attached packages (i.e. the ones attached by calls to
  [`library()`](https://rdrr.io/r/base/library.html)).

- **Package development**: If it detects that the current context is
  package development it will make function calls explicit using
  packages in the 'Imports' field of the package `DESCRIPTION`. If the
  package being developed imports any packages in their entirety (i.e if
  `Import pkg` appears in the `NAMESPACE` file), calls to functions from
  these packages will be left unchanged. See
  [`current_packages()`](https://wanglabcsu.github.io/rpkgkit/reference/current_packages.md)
  for more information.

## Examples

``` r
code <- "
  cars <- as_tibble(mtcars)
  cars %>%
    filter(mpg > 20) %>%
    summarise(across(everything(), n_distinct))
"

# Code will be transformed to use the double-colon operator, but notice
# that `n_distinct` is not transformed as it is not followed by `()`
cat(add_double_colons(code, "dplyr"))
#> 
#>   cars <- dplyr::as_tibble(mtcars)
#>   cars %>%
#>     dplyr::filter(mpg > 20) %>%
#>     dplyr::summarise(dplyr::across(dplyr::everything(), n_distinct))

# You can specify functions that shouldn't be transformed:
cat(add_double_colons(code, "dplyr", ignore_functions = "across"))
#> 
#>   cars <- dplyr::as_tibble(mtcars)
#>   cars %>%
#>     dplyr::filter(mpg > 20) %>%
#>     dplyr::summarise(across(dplyr::everything(), n_distinct))

# Beware namespace conflicts! The following are not the same, mimicking
# the effects of reordering calls to `library()`:
cat(add_double_colons(code, c("dplyr", "stats")))
#> 
#>   cars <- dplyr::as_tibble(mtcars)
#>   cars %>%
#>     dplyr::filter(mpg > 20) %>%
#>     dplyr::summarise(dplyr::across(dplyr::everything(), n_distinct))

cat(add_double_colons(code, c("stats", "dplyr")))
#> 
#>   cars <- dplyr::as_tibble(mtcars)
#>   cars %>%
#>     stats::filter(mpg > 20) %>%
#>     dplyr::summarise(dplyr::across(dplyr::everything(), n_distinct))
```
