# Rewrite one file and write it back only when it changed

Rewrite one file and write it back only when it changed

## Usage

``` r
mfce_process_file(path, context)
```

## Arguments

- path:

  Path to the R file.

- context:

  Package lookups built by
  [`mfce_package_context()`](https://wanglabcsu.github.io/rpkgkit/reference/mfce_package_context.md).

## Value

A list with `changed` (logical) and `not_found` (character).
