# Package Setup & Maintenace

    #> ✔ Setting active project to "/tmp/RtmprMLUdM".
    #> ✔ Creating R/.
    #> ✔ Writing DESCRIPTION.
    #> Package: RtmprMLUdM
    #> Title: What the Package Does (One Line, Title Case)
    #> Version: 0.0.0.9000
    #> Authors@R (parsed):
    #>     * First Last <first.last@example.com> [aut, cre]
    #> Description: What the package does (one paragraph).
    #> License: `use_mit_license()`, `use_gpl3_license()` or friends to
    #>     pick a license
    #> Config/roxygen2/version: 8.1.0
    #> Encoding: UTF-8
    #> Roxygen: list(markdown = TRUE)
    #> ✔ Writing NAMESPACE.
    #> ✔ Setting active project to "<no active project>".

## Create package infrastructure

### A spinner startup message

[`use_zzz()`](https://wanglabcsu.github.io/rpkgkit/reference/use_zzz.md)
creates a package documentation file with `.onLoad`, `.onAttach`, and
`%||%`. It is similar to
[`usethis::use_package_doc()`](https://usethis.r-lib.org/reference/use_package_doc.html)
while also providing a useful starting template.

``` r

use_zzz(path = dir, open = FALSE)
#> ✔ Setting active project to "/tmp/RtmprMLUdM".
#> ✔ Created /tmp/RtmprMLUdM/R/RtmprMLUdM-package.R from template.
#> ✔ Adding cli to Imports field in DESCRIPTION.
#> 
#> ☐ Refer to functions with `cli::fun()`.
```

### Check missing function in `_pkgdown` reference

[`check_pkgdown_reference()`](https://wanglabcsu.github.io/rpkgkit/reference/check_pkgdown_reference.md)
identifies exported functions that are absent from the `reference`
section of `_pkgdown.yml`.

``` r

check_pkgdown_reference(pkg = dir)
```

## Vendor permissively licensed code

[`use_vendor()`](https://wanglabcsu.github.io/rpkgkit/reference/use_vendor.md)
records attribution and licensing information when incorporating
selected source files from a permissively licensed GitHub R package. It
creates an `inst/vendor/` directory, a `R/vendor-*.R` file, and updates
relevant `DESCRIPTION` fields.

``` r

try(use_vendor(
  pkg = "WangLabCSU/rpkgkit",
  "43_use_vendor.R",
  branch = "main",
  path = dir
))
#> ℹ Fetching repository information for WangLabCSU/rpkgkit...
#> ✔ Vendor package uses MIT license.
#> ✔ Created directory /tmp/RtmprMLUdM/inst/vendor/rpkgkit.
#> ✔ Copied LICENSE.
#> ✔ Copied LICENSE.md.
#> ✔ Created inst/vendor/rpkgkit/README.md.
#> ✔ Created /tmp/RtmprMLUdM/R/vendor-rpkgkit.R.
#> ✔ Added rpkgkit authors to Authors@R.
#> ✔ Updated DESCRIPTION.
#> ☐ Consider pasting the following statement into README.md
#> 
#> 
#> ## Acknowledgements
#> 
#> We would like to thank the following people and projects:
#> 
#> - The authors of the [rpkgkit](https://github.com/WangLabCSU/rpkgkit) package &mdash; **Yuxi Yang** &mdash; whose code is included (under MIT license) in `R/vendor-rpkgkit.R`.
```

Only packages with a supported permissive license can be vendored.
Review the acknowledgement text printed by the function and add it to
your README when appropriate.

``` r

rpkgkit::PERMISSIVE_LICENSE
#> [1] "MIT"          "Apache-2.0"   "Apache 2.0"   "BSD-2-Clause" "BSD-3-Clause"
#> [6] "Unlicense"    "CC0-1.0"      "CC0"
```

## `usethis` extensions

Use the following helpers from the package root:

### Use R 4.1.0 version

R 4.1.0 introduced the pipe (`|>`) and anonymous function `\()`. If
these syntaxes need to be used in a package, the R package must require
at least R version 4.1.0.

``` r

use_r_v4.1.0(path = dir)
#> ✔ Adding R to Depends field in DESCRIPTION.
```

### Add URL in `DESCRIPTION`

``` r

use_url(dir)
```

### Add bug reports URL in `DESCRIPTION`

``` r

use_bugreports(dir)
```

## Open CFF

CITATION.cff files are plain text files with human- and machine-readable
citation information for software and datasets.

Code developers can include such files in their source code repositories
to let others know how to correctly cite their software.

``` r

open_cffinit()
```

**This cannot replace
[`usethis::use_citation()`](https://usethis.r-lib.org/reference/use_citation.html)**,
it just complements project.

## Global ignore-file templates

Use
[`add_global_rbuildignore()`](https://wanglabcsu.github.io/rpkgkit/reference/add_global_rbuildignore.md)
and
[`add_global_gitgnore()`](https://wanglabcsu.github.io/rpkgkit/reference/add_global_gitgnore.md)
to add the corresponding global ignore-file templates to a package.

``` r

add_global_rbuildignore(path = dir)
#> ✔ Added 39 pattern(s) to .Rbuildignore.
```

``` r

add_global_gitgnore(pkg = dir)
```
