# Split an Rmd file into YAML header lines and body lines.

Rust rewrite of `rpkgkit:::.ory_read_rmd()`. Character arguments are
taken as `Vec<String>` (not `Strings`): iterating a zero-length
`Strings` aborts the R session, and an empty YAML header is a valid
input.

## Usage

``` r
ory_read_rmd_rs(lines)
```
