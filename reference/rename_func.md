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
  num_to_word = c(`for` = 4, to = 2),
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

- num_to_word:

  An optional named vector used to expand digit abbreviations inside
  function names into words. Names give the replacement word and values
  give the digit abbreviation, defaulting to `c("for" = 4, "to" = 2)`.
  Any input other than a named vector, `NULL`, or `FALSE` is an error.
  Supply `NULL` or `FALSE` to disable the expansion.

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

Digit abbreviations are expanded into words before the target style is
applied, so [`list2env()`](https://rdrr.io/r/base/list2env.html) becomes
`list_to_env()` and `wait4result()` becomes `wait_for_result()` under
`style = "snake_case"`. The expanded words are formatted following
`style`, e.g. [`list2env()`](https://rdrr.io/r/base/list2env.html)
becomes `listToEnv()` under `style = "camelCase"` and `ListToEnv()`
under `style = "PascalCase"`. Only digit runs that appear in
`num_to_word` are expanded: an identifier that contains an unmapped
digit run (for example `scale_x_log10()`) is left untouched.

## Examples

``` r
# \donttest{
temp <- tempfile(fileext = ".R")
writeLines("foo_bar <- function(){message('foo_bar')}", temp)
rename_func(temp, style = "camelCase")
#> ✔ Renamed 1 function to "camelCase" style in /tmp/RtmpdKv0Cw/file195257d8b1ce.R
readLines(temp)
#> [1] "fooBar <- function(){message('fooBar')}"
rename_func(temp, style = "snake_case")
#> ✔ Renamed 1 function to "snake_case" style in /tmp/RtmpdKv0Cw/file195257d8b1ce.R
readLines(temp)
#> [1] "foo_bar <- function(){message('foo_bar')}"

writeLines("list2env <- function(x) x", temp)
rename_func(temp, style = "snake_case")
#> ✔ Renamed 1 function to "snake_case" style in /tmp/RtmpdKv0Cw/file195257d8b1ce.R
readLines(temp)
#> [1] "list_to_env <- function(x) x"
# "list_to_env <- function(x) x"
# }
```
