# Rename Function Definitions in an R File

Renames function definitions in an R file to follow a consistent naming
convention. Supports `"snake_case"`, `"camelCase"`, `"PascalCase"`, and
`"google"` (dot-separated) naming styles. All references to the renamed
functions within the file are also updated.

## Usage

``` r
rename_func(
  path = NULL,
  style = c("snake_case", "camelCase", "PascalCase", "google"),
  ...
)
```

## Arguments

- path:

  A character string specifying the path to the R file to modify. If
  `NULL` and RStudio is available, the currently active document path is
  used.

- style:

  Naming convention to apply. One of:

  - `"snake_case"`: all lowercase with underscores (e.g., `my_function`)

  - `"camelCase"`: lower camel case (e.g., `myFunction`)

  - `"PascalCase"`: upper camel case (e.g., `MyFunction`)

  - `"google"`: dot-separated lowercase (e.g., `my.function`)

- ...:

  Additional arguments. Currently unused and must be empty.

## Value

Invisibly returns the path to the modified file.

## Details

Function definitions are identified using the pattern
`name <- function(`, `name = function(`, or the R 4.1+ shorthand
`name <- \\(` / `name = \\(`. Both the definition site and all call
sites / references within the file are updated. The conversion handles
mixed existing styles (snake_case, camelCase, PascalCase, dot.separated)
and normalizes function names to the target style.

## Examples

``` r
# \donttest{
temp <- tempfile(fileext = ".R")
writeLines("foo_bar <- function(){message('foo_bar')}", temp)
rename_func(temp, style = "camelCase")
#> ✔ Renamed 1 function to "camelCase" style in /tmp/Rtmp88Qrsk/file1b19245c9e8f.R
readLines(temp)
#> [1] "fooBar <- function(){message('fooBar')}"
rename_func(temp, style = "snake_case")
#> ✔ Renamed 1 function to "snake_case" style in /tmp/Rtmp88Qrsk/file1b19245c9e8f.R
readLines(temp)
#> [1] "foo_bar <- function(){message('foo_bar')}"
# }
```
