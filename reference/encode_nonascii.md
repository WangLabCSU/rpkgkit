# Encode Non-ASCII Characters to \uXXXX Escape Sequences

For each character in `x`, if its Unicode code point is outside the
ASCII range (0-127), it is replaced with a `\\uXXXX` escape. ASCII
characters are left unchanged.

## Usage

``` r
encode_nonascii(x)
```

## Arguments

- x:

  A character string.

## Value

A character string with non-ASCII characters escaped.
