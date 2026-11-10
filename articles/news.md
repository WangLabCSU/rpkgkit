# Edit NEWS

## Maintain NEWS.md

Here we create a template for editing NEWS.md

``` r

library(rpkgkit)
tmpdir <- tempdir()
usethis::create_package(tmpdir, open = FALSE)
writeLines(
  c("# pkgname v0.0.0.9000", "", "* This is a template for editing NEWS.md"),
  file.path(tmpdir, "NEWS.md")
)
```

``` r

news_md_show(path = tmpdir)
```

Add a new entry using the package version in `DESCRIPTION`:

``` r

news_md_add_entry(
  entry = "Add foo function",
  category = "NEW FEATURES",
  path = tmpdir
)
```

``` r

news_md_show(path = tmpdir)
```

Specify a different category when needed:

``` r

news_md_add_entry(
  entry = "Fixed bugs in `foo()`",
  category = "BUG FIXES",
  contributor = "Jack",
  path = tmpdir
)
```

``` r

news_md_show(path = tmpdir)
```

As you can see, different categories belong to the same version are
grouped together.

For validating the formatting rules of `NEWS.md`, use
[`news_md_check()`](https://wanglabcsu.github.io/rpkgkit/reference/news_md.md);
it is deprecated and now warns on every call, so it is only kept for
backward compatibility.
