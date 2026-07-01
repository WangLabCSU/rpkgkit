# Helper: extract package names from vendored code for the Imports header field

Scans file content for:

- Roxygen `@import pkg` and `@importFrom pkg ...` tags

- `pkg::function()` calls in non-roxygen lines

## Usage

``` r
.vendor_extract_imports(content_lines)
```

## Arguments

- content_lines:

  Character vector of file lines.

## Value

Sorted, unique character vector of package names.
