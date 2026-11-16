# Trace the expression that produces a variable inside a function.

Rust rewrite of the extraction half of `rpkgkit:::get_var_value()`: the
definition environment is built from the formals of the function, its
body is walked to record every assignment, and the target expression is
resolved by substituting the known variables. The resolved expression is
returned instead of its value, so that the final
[`eval()`](https://rdrr.io/r/base/eval.html) runs in R and a failing
evaluation keeps its original condition.

## Usage

``` r
gvv_trace_rs(var_name, fmls, body, env)
```

## Arguments

- var_name:

  Name of the target variable.

- fmls:

  Formals of the function, as returned by
  [`formals()`](https://rdrr.io/r/base/formals.html).

- body:

  Body of the function, as returned by
  [`body()`](https://rdrr.io/r/base/body.html).

- env:

  Environment used to evaluate conditions and loop sequences.

## Details

Returns a list with `found` (whether `var_name` is a parameter with a
default or is assigned in the body) and `expr` (the resolved expression,
`NULL` when it was not found).
