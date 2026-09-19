# Add Explicit Integer Suffix `L` to Integer Literals

Converts bare integer literals in an R file to the explicit integer form
with an `L` suffix, e.g. `seq_len(10)` becomes `seq_len(10L)`. Strings
and comments are left unchanged.

## Usage

``` r
convert_int_literals(path = NULL, verbose = TRUE, ...)
```

## Arguments

- path:

  A character string specifying the path to the R file to modify. If
  `NULL` and RStudio is available, the currently active document path is
  used.

- verbose:

  Logical; enable or disable per-file messages. Default `TRUE`.

- ...:

  Additional arguments. Currently unused and must be empty.

## Value

Invisibly returns the path to the modified file.

## Details

A token is treated as an integer literal when it is:

- a decimal integer (`10`, `0`, `-` is not part of the token), or

- a hexadecimal integer (`0xFF`, `0X10`),

and it is **not**:

- already suffixed with `L` / `l`,

- a floating-point number (`10.`, `1.0`, `.5`),

- scientific notation (`1e5`, `1E-3`),

- a complex literal (`10i`),

- adjacent to an identifier character (`a-zA-Z0-9._`).

## Examples

``` r
# \donttest{
temp <- tempfile(fileext = ".R")
writeLines("tmp <- seq_len(10)", temp)
convert_int_literals(temp)
#> ✔ Added explicit integer suffixes in /tmp/RtmpM6i24U/file19f072bef3b8.R
readLines(temp)
#> [1] "tmp <- seq_len(10L)"
# "tmp <- seq_len(10L)"
# }
```
