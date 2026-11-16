# Find every `nocov` marker of a character vector of source lines.

Rust rewrite of `rpkgkit:::find_nocov_markers()`. Detection is purely
textual, so a marker hidden in a string literal or in a roxygen comment
is reported as well, on purpose. `lines` is a `Vec<String>` because
iterating a zero-length `Strings` panics in debug builds (empty files
are common).

## Usage

``` r
dunm_find_markers_rs(lines)
```
