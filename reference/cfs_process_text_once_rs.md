# One character-level pass over the source text.

Rust rewrite of `rpkgkit:::.cfs_process_text_once()`. Strings (with
escapes) and comments are copied verbatim; `function(...)` becomes
`\(...)` for `direction = "to_lambda"`, and `\(...)` becomes
`function(...)` otherwise. Only one level of nesting is rewritten per
call.

## Usage

``` r
cfs_process_text_once_rs(text, direction)
```
