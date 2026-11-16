# Replace whole R identifiers throughout the source text.

Rust rewrite of the [`gsub()`](https://rdrr.io/r/base/grep.html)
renaming loop of
[`rename_func()`](https://wanglabcsu.github.io/rpkgkit/reference/rename_func.md).
The R version used Perl look-around to ensure the old name is not part
of a longer identifier; Rust's regex engine has no look-around, so the
boundary check is done explicitly. Returns
`list(text = ..., n_renamed = ...)`.

## Usage

``` r
rf_rename_text_rs(text, old_names, new_names)
```
