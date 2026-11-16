# Convert one R identifier to a target naming style.

Rust rewrite of `rpkgkit:::to_style()`. `num_lookup` is a named list
whose names are digit abbreviations and whose values are the words they
stand for (`list("2" = "to", "4" = "for")`); `NULL` disables the
expansion.

## Usage

``` r
rf_to_style_rs(name, style, num_lookup)
```
