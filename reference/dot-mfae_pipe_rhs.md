# Locate the right-hand side of every pipe expression

Returns a logical vector `rhs` that is `TRUE` at the row of every
expression a pipe feeds, plus `op`, the pipe operator used there. The
parse tree of `a %>% b()` nests that expression as the last child of the
pipe expression, so it is the last `expr` child after the pipe token.
Comments are children of the pipe expression too, but they are not
`expr` nodes and are skipped by the same filter.

## Usage

``` r
.mfae_pipe_rhs(pd)
```
