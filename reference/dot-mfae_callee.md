# Resolve the callee of a call from its head parse-data row

Returns `NULL` when the head is not a plain function name (for example
an anonymous function, a grouping parenthesis, or the result of another
call). Otherwise returns the bare name plus the equivalent language
object, which `.mfae_resolve_function()` can resolve.

## Usage

``` r
.mfae_callee(pd, head_row)
```
