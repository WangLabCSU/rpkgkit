# Base-R features that need a recent R version in one source text.

Returns one row per feature, with `feature`, `version`, `label`, `file`,
`line`, `col`, `count`, `local`, `min_version` and `files`. `local`
marks a name that the scanned sources define themselves; those hits do
not raise `min_version`.

## Usage

``` r
ur_scan_text_rs(text)
```
