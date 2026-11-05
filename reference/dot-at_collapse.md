# Internal: insert the directive and re-flow the elements

Internal: insert the directive and re-flow the elements

## Usage

``` r
.at_collapse(lines, targets, ncol, marker)
```

## Arguments

- lines:

  Character vector of the file contents.

- targets:

  Data frame returned by
  [`.at_targets()`](https://wanglabcsu.github.io/rpkgkit/reference/dot-at_targets.md).

- ncol:

  Number of elements per row.

- marker:

  The air table directive to insert.

## Value

A character vector with the modified file contents.
