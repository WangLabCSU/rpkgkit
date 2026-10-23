# Check the format of a custom standalone file

Checks a standalone file against the layout used by r-lib/rlang (as
consumed by
[`usethis::use_standalone()`](https://usethis.r-lib.org/reference/use_standalone.html)).
Three points are checked:

1.  the header format, and whether each slot has a value;

2.  every documented function carries `@noRd` (undocumented functions
    are skipped);

3.  a `# nocov start` marker exists and precedes all functions
    (`# nocov end` is optional).

## Usage

``` r
check_standalone(path = NULL, ...)
```

## Arguments

- path:

  Path to the standalone file (a single string).

- ...:

  Unused

## Value

Invisibly, `list(error = , warning = , note = )`, where each element is
an integer.

## Details

Each check point that reports nothing is announced as a success.
Warnings and notes never stop the run, but an error does: the remaining
check points are then skipped.

Results are printed in the style of
[`devtools::check()`](https://devtools.r-lib.org/reference/check.html).

## Examples

``` r
if (FALSE) { # \dontrun{
check_standalone("R/standalone-purrr.R")
} # }
```
