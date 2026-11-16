# Names of the functions defined by the code being rewritten —————–

Only `path` itself is inspected: no walk through parent directories.

- a package root -\> every function defined under its R/ directory

- anything else -\> the functions defined in that one file Plain values
  are not functions and are left out. The result is always a character
  vector, never NULL, so it can be combined with
  [`imported_functions()`](https://wanglabcsu.github.io/rpkgkit/reference/current_packages.md)
  (which may return NULL).

## Usage

``` r
get_defined_fn(path = NULL)
```

## Arguments

- path:

  Path to the R file.

## Value

A character vector of function names.

## Examples

``` r
if (FALSE) { # \dontrun{
get_defined_fn(".")
} # }
```
