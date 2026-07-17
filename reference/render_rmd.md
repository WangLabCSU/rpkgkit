# Render an R Markdown or R document to Markdown format

Render an R Markdown or R document to Markdown format

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
# \donttest{
rlang::check_installed("rmarkdown")
tmp <- tempfile(fileext = ".Rmd")
writeLines(c("---", "title: Test", "---", "", "Hello, world!"), tmp)
render_rmd(path = tmp)
#> 
#> 
#> processing file: file1a836ada662c.Rmd
#> 1/1
#> output file: file1a836ada662c.knit.md
#> /opt/hostedtoolcache/pandoc/3.8.3/x64/pandoc +RTS -K512m -RTS file1a836ada662c.knit.md --to markdown_strict-yaml_metadata_block --from markdown+autolink_bare_uris+tex_math_single_backslash --output file1a836ada662c.md 
#> 
#> Output created: file1a836ada662c.md
# }
```
