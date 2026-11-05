# Format Long Vectors and Lists as Aligned Tables with Air

Air (\\\geq\\ 0.8.0) can align the elements of a call column by column,
giving the same layout as
[`tibble::tribble()`](https://tibble.tidyverse.org/reference/tribble.html)
or
[`data.table::fcase()`](https://rdrr.io/pkg/data.table/man/fcase.html).
The feature is switched on by the experimental `# fmt: table` comment
directive placed right above the call, but air never re-flows the
elements on its own: whatever sits on one source line stays there.

`use_air_table()` does the two things air does not do by itself:

1.  runs `air format` on `path`, so every long vector and list is laid
    out with one element per line;

2.  inserts the directive above every
    [`c()`](https://rdrr.io/r/base/c.html) /
    [`list()`](https://rdrr.io/r/base/list.html) call that has more than
    `min_length` elements, and re-flows the elements so that each row
    holds `ncol` of them. Multi-line definitions are collapsed by
    deleting the line breaks between the elements of a row; a definition
    that air kept on a single line is split into rows instead.

A second `air format` run then pads the cells and aligns the columns.

## Usage

``` r
use_air_table(
  path = NULL,
  ncol = 3L,
  min_length = 12L,
  marker = "# fmt: table",
  ...
)
```

## Arguments

- path:

  Path to an R file to modify. If `NULL` and RStudio is available, the
  path of the active document is used.

- ncol:

  Number of elements placed on each table row.

- min_length:

  A vector or list is only converted when it has strictly more than this
  many elements.

- marker:

  The comment directive that enables table formatting in air.

- ...:

  Additional arguments. Currently unused and must be empty.

## Value

Invisibly returns the normalized `path`.

## Details

Requirements and scope:

- `air` must be installed and on the `PATH` (see
  [`check_air_installed()`](https://wanglabcsu.github.io/rpkgkit/reference/check_air_installed.md)),
  and the directive requires air 0.8.0 or newer.

- Only calls whose elements are **all unnamed** are rewritten. Air
  expands named elements (`list(a = 1)`) one per line no matter what the
  directive says, so named calls are skipped to avoid a marker that has
  no effect.

- Calls that already carry `marker` on the preceding line are left
  untouched, so the function is idempotent.

- Air only honours the directive on the outermost call of a statement,
  so a vector or list nested inside another call (for example an
  argument of `x <- list(a = c(...))`) is skipped.

## Examples

``` r
if (FALSE) { # \dontrun{
tf <- tempfile(fileext = ".R")
writeLines(
  'x <- c("alpha", "beta", "gamma", "delta", "epsilon", "zeta", "eta", "theta")',
  tf
)
use_air_table(tf, ncol = 3L, min_length = 6L)
readLines(tf) |> cli::cli_code()
} # }
```
