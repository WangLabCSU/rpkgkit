# Rewrite `text`, qualifying package calls and exported datasets.

`fun_exports` / `fun_packages` are parallel vectors of namespace exports
and their packages; `data_exports` / `data_packages` do the same for
exported datasets. `use_packages` is only reported back so callers can
describe the operation.

## Usage

``` r
mfce_make_calls_explicit_rs(
  text,
  use_packages,
  ignore_functions,
  fun_exports,
  fun_packages,
  data_exports,
  data_packages,
  base_pkg
)
```

## Details

Character vectors are taken as `Vec<String>` (not `Strings`): iterating
a zero-length `Strings` aborts in debug builds, and a package may well
export no dataset at all.
