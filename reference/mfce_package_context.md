# Build the package lookups used to qualify names

Resolves each package in `use_packages` once, so a whole package can be
processed without re-reading namespace exports for every file.

## Usage

``` r
mfce_package_context(
  use_packages = current_packages(),
  ignore_functions = c(imported_functions(), get_defined_fn())
)
```
