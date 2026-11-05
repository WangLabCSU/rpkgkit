# Internal: describe one `c()` / `list()` call

Internal: describe one [`c()`](https://rdrr.io/r/base/c.html) /
[`list()`](https://rdrr.io/r/base/list.html) call

## Usage

``` r
.at_call_info(pd, sym_id, call_ids, min_length)
```

## Arguments

- pd:

  Parse data as returned by
  [`getParseData()`](https://rdrr.io/r/utils/getParseData.html).

- sym_id:

  Id of the `SYMBOL_FUNCTION_CALL` row.

- call_ids:

  Ids returned by
  [`.at_call_ids()`](https://wanglabcsu.github.io/rpkgkit/reference/dot-at_call_ids.md).

- min_length:

  Minimum number of elements (exclusive).

## Value

`NULL` when the call does not qualify, otherwise a list with `line1`,
`line2`, `col1`, `n`, `multiline` and `elements`.
