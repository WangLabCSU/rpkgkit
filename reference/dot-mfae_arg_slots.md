# Split a call node's children into its argument slots

Each slot records the argument's name (empty when positional), the
source position of its first token, and whether it is a literal `...`.

## Usage

``` r
.mfae_arg_slots(pd, kids)
```

## Details

Named arguments appear as three sibling tokens (`SYMBOL_SUB`, `EQ_SUB`,
`expr`) rather than one wrapping expression. Empty arguments
(`f(a, , b)`) produce no token at all — only an extra `,` — which is why
slots are accumulated per comma so that positional matching still lines
up with R's.
