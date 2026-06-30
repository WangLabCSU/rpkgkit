# Built-in R operators that are never transformed into named-arg calls.

These are pure operators/syntax, not control flow (`if`, `for`, `while`,
`repeat`, `function`, `{`, `(`) — those are dispatched by dedicated
handlers in `.mfae_walk`. This list is used for the remaining operators
where simply walking children suffices.

## Usage

``` r
.mfae_operators
```

## Format

An object of class `character` of length 28.
