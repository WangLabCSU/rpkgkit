# Switch Between Explicit `function()` and Implicit `\()` Syntax

Converts all function definitions in an R file between the explicit
`function()` syntax and the R 4.1+ concise lambda `\()` syntax. Handles
strings and comments correctly, and supports nested function definitions
via iterative passes.

## Usage

``` r
convert_func_syntax(
  path = NULL,
  direction = c("to_lambda", "to_explicit"),
  ...
)
```

## Arguments

- path:

  A character string specifying the path to the R file to modify. If
  `NULL` and RStudio is available, the currently active document path is
  used.

- direction:

  Conversion direction. One of:

  - `"to_lambda"`: convert `function(...)` to `\(...)`

  - `"to_explicit"`: convert `\(...)` to `function(...)`

- ...:

  Additional arguments. Currently unused and must be empty.

## Value

Invisibly returns the path to the modified file.

## Details

The conversion correctly handles strings, comments, and nested
parentheses in default argument values (e.g., `function(x = foo(y))`).

Nested function definitions (e.g., `function(x, f = function(y) ...)`)
are converted in multiple iterative passes, so all nesting levels are
reached.

## Examples

``` r
# \donttest{
temp <- tempfile(fileext = ".R")
writeLines("add_one <- function(x) x + 1", temp)
convert_func_syntax(temp, direction = "to_lambda")
#> ✔ Converted function definitions in /tmp/RtmpSQrRz1/file1a4338bafe63.R to "to_lambda"
readLines(temp)
#> [1] "add_one <- \\(x) x + 1"
# "add_one <- \(x) x + 1"
convert_func_syntax(temp, direction = "to_explicit")
#> ✔ Converted function definitions in /tmp/RtmpSQrRz1/file1a4338bafe63.R to "to_explicit"
readLines(temp)
#> [1] "add_one <- function(x) x + 1"
# "add_one <- function(x) x + 1"
# }
```
