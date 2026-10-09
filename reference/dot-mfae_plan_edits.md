# Plan the insertions that make function arguments explicit

Returns a list of insertions, each a list with `line`, `col` and `text`,
describing an `argument = ` prefix to insert at that source position.

## Usage

``` r
.mfae_plan_edits(exprs, skip_fns = NULL)
```
