# Assign the formal names that positional arguments match

Mirrors R's argument matching on names alone, and returns one name per
argument *in source order* (empty string when the argument is not
matched to a named formal). Named arguments first claim the formal they
match (exact, then partial); positional arguments then fill the
remaining formals in formal order and stop permanently once `...` is
reached, since positional matching never reaches formals that follow
`...`.

## Usage

``` r
.mfae_assign_arg_names(arg_nms, fml_nms)
```
