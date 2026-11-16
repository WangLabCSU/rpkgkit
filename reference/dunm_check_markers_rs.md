# Check the markers against the `nocov` rules.

Rust rewrite of `rpkgkit:::check_nocov_markers()`. Returns one list per
problem with `index` (1-based position in `markers`), `reason`,
`reference` (1-based, `NA` when the problem has no reference marker) and
`text`, the sentence built by `rpkgkit:::nocov_problem_text()`.

## Usage

``` r
dunm_check_markers_rs(markers)
```
