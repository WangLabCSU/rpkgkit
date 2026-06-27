# Create a zzz.R file from a template

Copies the built-in `zzz_template.R` to the target package's `R/`
directory and replaces template placeholders (all-caps words) with
values from the package `DESCRIPTION` file.

Template placeholders replaced:

- `PKG` — package name

- `PKG-package` — `{pkgname}-package`

- `TITLE` — package title

- `DESCRIPTION` — package description (multiline values get `#' `
  prefix)

- `LICENSE` — license type

## Usage

``` r
use_zzz(
  path = ".",
  file_name = "zzz.R",
  overwrite = FALSE,
  open = rlang::is_interactive(),
  ...
)
```

## Arguments

- path:

  Character. Path to the package root directory. Defaults to the current
  working directory (`"."`).

- file_name:

  Character. Output file name. Defaults to `"zzz.R"`.

- overwrite:

  Logical. If `TRUE`, overwrite an existing file. Defaults to `FALSE`.

- open:

  Logical. Whether to open the created file in the default editor.

- ...:

  Not used.

## Value

Invisibly returns the path to the created file.

## Examples

``` r
if (FALSE) { # \dontrun{
dir <- tempdir()
usethis::create_package(dir)
use_zzz(dir)
} # }
```
