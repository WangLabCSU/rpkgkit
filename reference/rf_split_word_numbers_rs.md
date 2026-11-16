# Expand mapped digit runs of one word into separate words.

Rust rewrite of `rpkgkit:::split_word_numbers()`. Returns a character
vector. A word with any unmapped digit run is returned unchanged, as a
single element, so `log10` and `x10y` survive.

## Usage

``` r
rf_split_word_numbers_rs(word, num_lookup)
```
