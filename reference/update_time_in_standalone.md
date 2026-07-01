# Update the last-updated field in standalone R files

Updates the `last-updated` field in the YAML header of standalone files
to today's date. Supports single file or batch update for all standalone
files in a directory.

## Usage

``` r
update_time_in_standalone(path = NULL)
```

## Arguments

- path:

  Character. Path to a standalone file or a directory. If `NULL` and
  `rstudioapi` is available, uses the currently active document.
  Defaults to NULL.

## Value

Invisibly returns a character vector of updated file paths.

## Examples

``` r
# \donttest{
update_time_in_standalone(tempdir())
#> ✔ Updated last-updated to "2026-07-01" in 1 file.
# }
```
