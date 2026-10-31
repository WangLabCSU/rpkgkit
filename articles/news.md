# Edit NEWS

## Maintain NEWS.md

Here we create a template for editing NEWS.md

``` r

library(rpkgkit)
#> ✔ rpkgkit v0.1.21 loaded [1 ms]
tmpdir <- tempdir()
usethis::create_package(tmpdir, open = FALSE)
#> ✔ Setting active project to "/tmp/RtmpgLJlWF".
#> ✔ Creating R/.
#> ✔ Writing DESCRIPTION.
#> Package: RtmpgLJlWF
#> Title: What the Package Does (One Line, Title Case)
#> Version: 0.0.0.9000
#> Authors@R (parsed):
#>     * First Last <first.last@example.com> [aut, cre]
#> Description: What the package does (one paragraph).
#> License: `use_mit_license()`, `use_gpl3_license()` or friends to
#>     pick a license
#> Config/roxygen2/version: 8.1.1
#> Encoding: UTF-8
#> Roxygen: list(markdown = TRUE)
#> ✔ Writing NAMESPACE.
#> ✔ Setting active project to "<no active project>".
writeLines(
  c("# pkgname v0.0.0.9000", "", "* This is a template for editing NEWS.md"),
  file.path(tmpdir, "NEWS.md")
)
```

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
#> ✔ Added 1 entry to /tmp/RtmpgLJlWF/NEWS.md
#> → Version: 0.0.0.9000, Category: NEW FEATURES
```

``` r

news_md_show(path = tmpdir)
#> # RtmpgLJlWF 0.0.0.9000 (2026-10-31)
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
#> ✔ Added 1 entry to /tmp/RtmpgLJlWF/NEWS.md
#> → Version: 0.0.0.9000, Category: BUG FIXES
```

``` r

news_md_show(path = tmpdir)
#> # RtmpgLJlWF 0.0.0.9000 (2026-10-31)
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

For validating the formatting rules of `NEWS.md`, use
[`news_md_check()`](https://wanglabcsu.github.io/rpkgkit/reference/news_md.md);
it is deprecated and now warns on every call, so it is only kept for
backward compatibility.
