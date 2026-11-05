# Internal: flag the line breaks that disappear when rows are collapsed

Internal: flag the line breaks that disappear when rows are collapsed

## Usage

``` r
.at_join_flags(join, elements, ncol, lines)
```

## Arguments

- join:

  Logical vector of line-break flags to update.

- elements:

  Data frame of element positions.

- ncol:

  Number of elements per row.

- lines:

  Character vector of the file contents.

## Value

The updated `join` vector.

## Details

A line ending in a comment is never joined with the next one: the joined
element would be swallowed by the comment and silently disappear.
