# Create an RStudio Addin registration entry for a package function

`use_tidy_addin()` writes an entry into `inst/rstudio/addins.dcf`, which
makes an exported function available from the RStudio Addins menu.

## Usage

``` r
use_tidy_addin(fn_name, desc, Interactive = FALSE, path = NULL)
```

## Arguments

- fn_name:

  Name of the function (it must already be exported in `NAMESPACE`).

- desc:

  Description of the addin.

- Interactive:

  Whether this is an interactive addin (maps to the `Interactive` field
  of the dcf file).

- path:

  Root directory of the R package.

## Value

Invisibly, the path of the dcf file that was written (`NULL` if the
operation was cancelled).

## Examples

``` r
if (FALSE) { # \dontrun{
# Inside a package that exports `my_addin()`
use_tidy_addin("my_addin", "Open my Shiny gadget", Interactive = TRUE)
} # }
```
