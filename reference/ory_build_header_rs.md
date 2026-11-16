# Build the new YAML header lines, fences excluded.

Rust rewrite of `rpkgkit:::.ory_build_header()`. `extra` is a named list
of extra YAML fields, added only when the key is missing from the
header.

## Usage

``` r
ory_build_header_rs(header, path, type_, meta, readme_format, date, extra)
```
