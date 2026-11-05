# Internal: locate long vector and list definitions

Internal: locate long vector and list definitions

## Usage

``` r
.at_targets(lines, path, min_length, marker)
```

## Arguments

- lines:

  Character vector of the file contents.

- path:

  Path of the file, used in error messages.

- min_length:

  Minimum number of elements (exclusive).

- marker:

  The air table directive.

## Value

A data frame with one row per target and the list-column `elements`
(position of every element), or an empty data frame with the same
columns when nothing qualifies.
