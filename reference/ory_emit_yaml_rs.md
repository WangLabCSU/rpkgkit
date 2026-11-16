# Serialize an R list to YAML lines.

Rust rewrite of `rpkgkit:::.ory_emit_yaml()`: logicals become `true` /
`false`, nested lists become nested mappings, and the indentation is two
spaces.

## Usage

``` r
ory_emit_yaml_rs(x)
```
