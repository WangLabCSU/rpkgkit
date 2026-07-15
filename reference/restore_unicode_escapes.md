# Restore \uXXXX Escape Sequences Back to Unicode Characters

Matches patterns like `\\uXXXX` (where X is a hex digit) and replaces
them with the corresponding Unicode character.

## Usage

``` r
restore_unicode_escapes(x)
```

## Arguments

- x:

  A character string potentially containing `\\uXXXX` escapes.

## Value

A character string with escapes resolved.
