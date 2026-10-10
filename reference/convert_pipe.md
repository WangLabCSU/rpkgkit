# Switch Between the Tidyverse Pipe `%>%` and the Base Pipe `|>`

Rewrites pipe operators in an R file between the magrittr pipe `%>%` and
the base pipe `|>`. Strings, comments, and raw strings are left
unchanged, so a mention of either operator in documentation or a
character literal is not rewritten.

`convert_pipe()` operates on one R file. When `path` is `NULL` and
RStudio is available, it uses the currently active document.
`package_convert_pipe()` walks selected directories of an R package and
applies the same conversion to every `.R` / `.r` file found, except
automatically generated `RcppExports.R` files.

The placeholder pipe `%<>%` and the exposition pipe `%$%` are not pipes
in this sense and are left untouched.

## Usage

``` r
package_convert_pipe(
  path = NULL,
  direction = c("to_base", "to_magrittr"),
  dirs = c("R"),
  recursive = TRUE,
  ...
)

convert_pipe(
  path = NULL,
  direction = c("to_base", "to_magrittr"),
  verbose = TRUE,
  ...
)
```

## Arguments

- path:

  For `convert_pipe()`, a character string specifying the R file to
  modify. If `NULL` and RStudio is available, the currently active
  document path is used.

  For `package_convert_pipe()`, a character string specifying the
  package root. If `NULL`, the current working directory is used.

- direction:

  Conversion direction. One of:

  - `"to_base"`: convert `%>%` to `|>`

  - `"to_magrittr"`: convert `|>` to `%>%`

- dirs:

  Character vector of subdirectories relative to `path` to search. Used
  only by `package_convert_pipe()`. Defaults to `c("R")`.

- recursive:

  Logical; recurse into subdirectories. Used only by
  `package_convert_pipe()`. Default `TRUE`.

- ...:

  Additional arguments. Currently unused and must be empty.

- verbose:

  Logical; enable or disable per-file messages. Used only by
  `convert_pipe()`. Default `TRUE`.

## Value

Both functions are called for their side effect and invisibly return
`TRUE` when they convert something. When there is nothing to convert,
`convert_pipe()` returns `path` unchanged and `package_convert_pipe()`
returns `character(0)`.

## Details

Rewriting is a literal match, so only a complete operator is converted:

- `%>%` becomes `|>`, and `|>` becomes `%>%`.

- Matching is literal, so `% > %` (whitespace inside the operator) is
  not converted, and `%<>%`, `%$%`, and longer operators such as
  `%myop%` are left unchanged.

- `|>` is matched only when `%` does not immediately precede it, so the
  tail of an operator such as `%|>%` is not treated as a base pipe.

- Occurrences inside string literals, raw strings, and comments are left
  unchanged.

## Examples

``` r
# \donttest{
# --- Single file ---
temp <- tempfile(fileext = ".R")
writeLines("mtcars |> dplyr::filter(cyl > 4)", temp)
convert_pipe(temp, direction = "to_magrittr")
#> ✔ Converted pipes in /tmp/RtmpdKv0Cw/file1952717b49da.R ("to_magrittr")
readLines(temp)
#> [1] "mtcars %>% dplyr::filter(cyl > 4)"
# "mtcars %>% dplyr::filter(cyl > 4)"

# --- Entire package ---
tmp_pkg <- tempdir()
usethis::create_package(tmp_pkg, open = FALSE)
#> ✔ Setting active project to "/tmp/RtmpdKv0Cw".
#> Package: RtmpdKv0Cw
#> Title: What the Package Does (One Line, Title Case)
#> Version: 0.0.0.9000
#> Authors@R (parsed):
#>     * First Last <first.last@example.com> [aut, cre]
#> Description: What the package does (one paragraph).
#> License: `use_mit_license()`, `use_gpl3_license()` or friends to
#>     pick a license
#> Config/roxygen2/version: 8.1.1
#> Encoding: UTF-8
#> Roxygen: list(markdown = TRUE)
#> ✔ Setting active project to "<no active project>".
writeLines("mtcars %>% dplyr::filter(cyl > 4)", file.path(tmp_pkg, "R/foo.R"))
package_convert_pipe(tmp_pkg, direction = "to_base")
#> ✔ Processed 1 file, updated 1
readLines(file.path(tmp_pkg, "R/foo.R"))
#> [1] "mtcars |> dplyr::filter(cyl > 4)"
# }
```
