# Internal: is the call nested inside another call?

Internal: is the call nested inside another call?

## Usage

``` r
.at_has_call_ancestor(pd, call_id, call_ids)
```

## Arguments

- pd:

  Parse data as returned by
  [`getParseData()`](https://rdrr.io/r/utils/getParseData.html).

- call_id:

  Id of the call expression.

- call_ids:

  Ids returned by
  [`.at_call_ids()`](https://wanglabcsu.github.io/rpkgkit/reference/dot-at_call_ids.md).

## Value

A single logical.
