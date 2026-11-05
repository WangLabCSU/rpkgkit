# Internal: rewrite a single-line definition as a table

Internal: rewrite a single-line definition as a table

## Usage

``` r
.at_split_lines(line, call_col1, elements, ncol)
```

## Arguments

- line:

  The source line holding the whole call.

- call_col1:

  Column where the call starts.

- elements:

  Data frame of element positions.

- ncol:

  Number of elements per row.

## Value

A character vector of replacement lines, without the directive.
