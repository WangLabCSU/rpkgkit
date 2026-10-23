# Get the version of the Positron IDE

Get the version of the Positron IDE

## Usage

``` r
get_positron_version(long = FALSE)
```

## Arguments

- long:

  Whether to return the full version including the build number (e.g.
  "2025.01.0-123"). Defaults to FALSE.

## Value

A character string with the version number, or NA_character\_ if not
running inside Positron and the version cannot be located.
