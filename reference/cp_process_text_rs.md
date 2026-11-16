# Rewrite the pipes of a character vector of source lines.

Rust rewrite of `rpkgkit:::.cp_process_text()`. `direction = "to_base"`
turns `%>%` into `|>`; every other value turns `|>` into `%>%`. Lines
whose first non-whitespace character is `#` are returned untouched, and
occurrences inside strings, raw strings and trailing comments are
preserved.

## Usage

``` r
cp_process_text_rs(text, direction)
```
