# Try to transform a single call expression

Resolves the function definition, matches arguments to formals, then
recursively walks the matched call's children.

## Usage

``` r
.mfae_transform_call(expr, skip_fns = NULL)
```
