# Collect the names of the function definitions found in source lines.

Rust rewrite of `rpkgkit:::detect_func_defs()`. Matches
`name <- function(` / `name = function(` and the R 4.1 lambda shorthand
`name <- \(`, with optional backtick quoting of the name. Only the first
definition of each line is reported, and duplicates are dropped.

## Usage

``` r
rf_detect_func_defs_rs(lines)
```
