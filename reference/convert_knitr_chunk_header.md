# Convert Knitr Chunk Headers in R Markdown Files

Converts legacy knitr chunk headers in R Markdown (`.Rmd`) files to the
current header syntax using
[`knitr::convert_chunk_header()`](https://rdrr.io/pkg/knitr/man/convert_chunk_header.html).

When `path` points to an R package root (a directory containing a
`DESCRIPTION` file), the conversion is applied to all `.Rmd` files found
under the package `vignettes/` directory (including subdirectories) and
to the package `README.Rmd` file when present.

When `path` points to a single file, that file is converted and written
back in place.

## Usage

``` r
convert_knitr_chunk_header(path = NULL, ...)
```

## Arguments

- path:

  Path to an R package root directory or an R Markdown file. If `NULL`
  (the default), the current working directory is used.

- ...:

  Additional arguments passed to
  [`knitr::convert_chunk_header()`](https://rdrr.io/pkg/knitr/man/convert_chunk_header.html).

## Value

Invisibly returns a character vector of file paths that were converted.

## Examples

``` r
tmp <- tempfile(fileext = ".Rmd")
writeLines(c("```{r, echo=TRUE, fig.width=10}", "x <- 1", "```"), tmp)
convert_knitr_chunk_header(tmp)
#> ℹ Converting knitr chunk headers in /tmp/RtmpEsKggO/file19a46ad3a40e.Rmd
readLines(tmp)
#> [1] "```{r}"            "#| echo = TRUE,"   "#| fig.width = 10"
#> [4] "x <- 1"            "```"              
```
