# Edit NEWS

## Maintain NEWS.md

Here we create a template for editing NEWS.md

    #> ✔ Setting active project to "/tmp/Rtmpz6Q0N6".
    #> ✔ Creating R/.
    #> ✔ Writing DESCRIPTION.
    #> Package: Rtmpz6Q0N6
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

``` r

news_md_show(path = tmpdir)
#> # pkgname v0.0.0.9000
#> 
#> * This is a template for editing NEWS.md
```

Add a new entry using the package version in `DESCRIPTION`:

``` r

news_md_add_entry(
  entry = "Add foo function",
  category = "NEW FEATURES",
  path = tmpdir
)
#> ✔ Added 1 entry to /tmp/Rtmpz6Q0N6/NEWS.md
#> → Version: 0.0.0.9000, Category: NEW FEATURES
```

``` r

news_md_show(path = tmpdir)
#> # Rtmpz6Q0N6 0.0.0.9000 (2026-09-22)
#> 
#> ## NEW FEATURES
#> 
#> * Add foo function
#> 
#> 
#> # pkgname v0.0.0.9000
#> 
#> * This is a template for editing NEWS.md
```

Specify a different category when needed:

``` r

news_md_add_entry(
  entry = "Fixed bugs in `foo()`",
  category = "BUG FIXES",
  contributor = "Jack",
  path = tmpdir
)
#> ✔ Added 1 entry to /tmp/Rtmpz6Q0N6/NEWS.md
#> → Version: 0.0.0.9000, Category: BUG FIXES
```

``` r

news_md_show(path = tmpdir)
#> # Rtmpz6Q0N6 0.0.0.9000 (2026-09-22)
#> 
#> ## BUG FIXES
#> 
#> * Fixed bugs in `foo()` (@Jack)
#> 
#> 
#> ## NEW FEATURES
#> 
#> * Add foo function
#> 
#> 
#> # pkgname v0.0.0.9000
#> 
#> * This is a template for editing NEWS.md
```

As you can see, different categories belong to the same version are
grouped together.

Validate the resulting file against the package’s NEWS formatting rules:

``` r

news_md_check(path = tmpdir)
#> ℹ Checking NEWS.md with 15 lines
#> ✔ NEWS.md passed all required checks
#> ℹ 1 suggestion(s) for improvement
#> $valid
#> [1] TRUE
#> 
#> $errors
#> character(0)
#> 
#> $warnings
#> character(0)
#> 
#> $suggestions
#> [1] "File should end with a blank line"
```

`"File should end with a blank line"` just follows the same rule as
`DESCRIPTION`. But generally, there are very few items that need to be
checked for NEWS.md compared with other files in an R package, and these
requirements are not mandatory; however, they can indeed standardize
NEWS writing.
