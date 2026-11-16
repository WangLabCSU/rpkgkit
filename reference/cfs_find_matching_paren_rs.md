# Index (1-based) of the `)` closing the `(` at `open_pos`, `NA` when none.

Rust rewrite of `rpkgkit:::.cfs_find_matching_paren()`. Like the R
helper it counts only parentheses: the character vector is the raw
source, so brackets inside strings are counted too. `text` is the
characters joined back into one string.

## Usage

``` r
cfs_find_matching_paren_rs(text, open_pos)
```
