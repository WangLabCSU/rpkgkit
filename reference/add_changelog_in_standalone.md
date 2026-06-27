# Add or update a changelog entry in a standalone R file

Appends a new changelog entry at the top of the `Changelog` section in a
standalone file. Also updates the `last-updated` field in the YAML
header to today's date. If no `Changelog` section exists, one is created
after the YAML header.

## Usage

``` r
add_changelog_in_standalone(path = NULL, description = NULL, date = NULL)
```

## Arguments

- path:

  Character. Path to a standalone file, a directory, or `NULL`. If
  `NULL` and `rstudioapi` is available, uses the currently active
  document. If a directory, searches for standalone files matching the
  pattern.

- description:

  Character. Description of the changelog entry. If `NULL`, an
  interactive prompt is used (not yet implemented).

- date:

  Character. Date string in `YYYY-MM-DD` format. Defaults to today.

## Value

Invisibly returns the path to the updated file.

## Examples

``` r
# \donttest{
add_changelog_in_standalone(tempdir(), "Added new feature")
#> No standalone files found.
# }
```
