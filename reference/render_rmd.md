# **\[deprecated\]** Render an R Markdown or R document to Markdown format

**\[deprecated\]** Render an R Markdown or R document to Markdown format

## Usage

``` r
render_rmd(path = NULL, output_format = "md_document", ...)
```

## Arguments

- path:

  Path to the input file. If NULL and rstudioapi is available, uses the
  currently active document in RStudio.

- output_format:

  Output format to render to. Defaults to "md_document".

- ...:

  Additional arguments passed to rmarkdown::render.

## Value

The output file path from rmarkdown::render.

## Examples

``` r
if (FALSE) { # \dontrun{
rlang::check_installed("rmarkdown")
tmp <- tempfile(fileext = ".Rmd")
writeLines(c("---", "title: Test", "---", "", "Hello, world!"), tmp)
render_rmd(path = tmp)
} # }
```
