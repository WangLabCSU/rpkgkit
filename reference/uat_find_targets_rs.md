# Locate the long, unnamed `c()` / `list()` calls of a source text.

The AST is replaced by the tokenizer of `crate::r_syntax`: a call is
kept when it is the outermost call of a statement, carries no named
element and holds more than `min_length` elements. Returns one list per
call with `line1`, `line2`, `col1`, `n`, `multiline` and `elements`, the
latter being one integer vector `c(line1, col1, line2, col2)` per
element.

## Usage

``` r
uat_find_targets_rs(text, min_length, marker)
```
