# Format R code using air

Format R code using air

## Usage

``` r
air_format(path = NULL, ...)
```

## Arguments

- path:

  Path to the R file to format. If NULL, attempts to use the active
  document in RStudio (requires `rstudioapi` package).

- ...:

  Additional arguments passed to
  [`system2()`](https://rdrr.io/r/base/system2.html).

## Value

The exit status of the `air format` command (invisibly).

## Details

Install [air](https://github.com/posit-dev/air):

Linux:
`curl -LsSf https://github.com/posit-dev/air/releases/latest/download/air-installer.sh | sh`
Windows:
`powershell -ExecutionPolicy Bypass -c "irm https://github.com/posit-dev/air/releases/latest/download/air-installer.ps1 | iex"`
uv: `uv tool install air-formatter` brew (MacOS): `brew install air`

## Examples

``` r
if (FALSE) { # \dontrun{
air_format(system.file("R_template/zzz_template.R", package = "rpkgkit"))
} # }
```
