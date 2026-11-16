# Recursively scan the `.R` files below `root` for base-R features that need a recent R version.

`dirs` holds paths relative to `root`; missing directories are skipped.
The returned `file` column is relative to `root`, and `min_version` is
`""` when no feature (or only locally defined names) was found.

## Usage

``` r
ur_scan_rs(root, dirs)
```
