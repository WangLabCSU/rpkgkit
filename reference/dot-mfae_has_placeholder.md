# Does a placeholder occur anywhere inside this expression?

Magrittr substitutes its left-hand side at every `.` in the whole
right-hand side call, including nested ones, so the search is recursive.
`.data` and `..1` are different symbols and do not match.

## Usage

``` r
.mfae_has_placeholder(pd, id, placeholder)
```
