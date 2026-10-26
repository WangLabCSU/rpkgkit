# Helper: resolve the path of a vendored file inside the source repository

Files given without a directory component are looked up in the
conventional directory of their language (`R/` for R, `src/` for C and
C++, `src/rust/src/` for Rust).

## Usage

``` r
vendor_source_path(file, dir = "R")
```
