# `TRUE` when the last byte of `path` is a newline

[`readLines()`](https://rdrr.io/r/base/readLines.html) drops that
information, but the rewrite must neither add nor remove the final
newline of the file it touches.

## Usage

``` r
mfce_has_final_newline(path)
```
