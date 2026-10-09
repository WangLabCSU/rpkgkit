# Built-in R operators that are never transformed into named-arg calls.

These are pure operators/syntax, not control flow. Control flow is
excluded structurally: `if`, `for`, `while`, `repeat`, `function`, `{`
and `(` never look like a `name(...)` call node in the parse data, so
they need no entry here.

## Usage

``` r
.mfae_operators
```
