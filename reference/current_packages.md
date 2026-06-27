# Get packages from the current context

These functions find the packages/functions to use when running
[`add_double_colons()`](https://wanglabcsu.github.io/rpkgkit/reference/add_double_colons.md).

## Usage

``` r
is_dev_context(dir = ".")

imported_functions(dir = ".")

current_packages(
  dir = ".",
  base_packages = getOption("defaultPackages"),
  include_types = "Imports"
)
```

## Arguments

- dir:

  The current working directory

- base_packages:

  Default packages to include

- include_types:

  The types of package imports to return if the current context is
  package development. Should be a subset of
  `c("Imports", "Depends", "Suggests", "Enhances", "LinkingTo")`

## Value

`TRUE` if the current context is package development, `FALSE` otherwise.

A character vector of imported function names, or `NULL` if no NAMESPACE
file is found or `{pkgload}` is not installed.

A character vector of package names.

## Details

- `current_packages()` first checks if the current context is package
  development. If it is, then it returns the packages which are listed
  in the package `DESCRIPTION` as dependencies, but will not return any
  packages also listed as imports in the package `NAMESPACE`. If the
  current context is not package development, the currently attached
  packages (as given by
  [`search()`](https://rdrr.io/r/base/search.html)) are used. Note that
  if `{pkgload}` is not installed then the latter option is always used.

- `imported_functions()` looks for a package `NAMESPACE` file and
  returns the names of all imported functions. If a `NAMESPACE` file is
  not found, or if `{pkgload}` is not loaded, `NULL` is returned.
