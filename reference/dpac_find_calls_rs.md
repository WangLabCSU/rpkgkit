# Locate unsupported `print()` / `cat()` calls in R source text.

Tokenizer of `crate::r_syntax` is used, so R's parser is not needed.
Each hit is a list with `line1`, `col1`, `col2`, `text`, `type` and
`kind`.

## Usage

``` r
dpac_find_calls_rs(text, pattern_fn_names, include_s3, include_refs)
```
