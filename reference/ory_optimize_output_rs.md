# Keep the user's `output` block, or return `NULL` to use the enriched one.

Rust rewrite of `rpkgkit:::.ory_optimize_output()`: `NULL` means "the
block is still the usethis default", otherwise the lines to keep.

## Usage

``` r
ory_optimize_output_rs(chunk, type_)
```
