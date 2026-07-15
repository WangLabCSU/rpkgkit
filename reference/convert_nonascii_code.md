# Convert Non-ASCII Code

Converts non-ASCII characters in R code to their ASCII escape sequences
(e.g., `\uXXXX`), or restores ASCII escape sequences back to readable
characters. Accepts either an R expression (via NSE) or a file path (as
a character string).

## Usage

``` r
convert_nonascii_code(code, ..., reverse = FALSE, overwrite = NULL)
```

## Arguments

- code:

  An R expression or a file path (character). When a bare expression is
  supplied, it is captured via NSE and deparsed. When a character string
  that points to an existing file is supplied, the file content is read
  and converted.

- ...:

  Additional arguments (must be empty).

- reverse:

  Logical. If `TRUE`, converts `\uXXXX` escape sequences back to
  readable Unicode characters. If `FALSE` (default), encodes non-ASCII
  characters to `\uXXXX` escapes.

- overwrite:

  Logical. Only used when `code` is a file path. If `TRUE`, overwrites
  the file with the converted content. Default is `NULL`, which prompts
  the user interactively.

## Value

Invisibly returns the converted code as a character string. If `code` is
a file path and `overwrite = TRUE`, the file is updated in place and the
function returns the path invisibly.

## Examples

``` r
# \donttest{
# Convert non-ASCII characters in a bare expression to \u escapes
convert_nonascii_code(print('\u4e2d\u6587'))
#> ℹ Converted code (copy from console):
#> print("\u4e2d\u6587")

# Reverse: restore \u escapes to readable characters
convert_nonascii_code(print('\u4e2d\u6587'), reverse = TRUE)
#> ℹ Converted code (copy from console):
#> print("中文")
# }
```
