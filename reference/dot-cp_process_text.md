# Internal: pipe rewrite that preserves strings and comments

`text` is a character vector of lines. A line whose first non-whitespace
character is `#` is a comment and is returned untouched; within the
remaining lines, pipes inside string literals, raw strings, and trailing
comments are left unchanged.

## Usage

``` r
.cp_process_text(text, direction)
```
