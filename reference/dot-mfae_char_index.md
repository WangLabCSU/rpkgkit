# Translate a parse-data column into a character index on the source line

The parser reports columns with tabs expanded to the next multiple of 8
(so the character after a leading tab is at column 9), while
[`substr()`](https://rdrr.io/r/base/substr.html) counts every character
as one. Tab-indented lines therefore need this mapping before a
parse-data column can be used as a substring index.

## Usage

``` r
.mfae_char_index(line, col)
```
