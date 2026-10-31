# Add a `URL` field to a package's `DESCRIPTION`

Sets the `URL` field of a package's `DESCRIPTION` file. By default, the
GitHub repository URL is detected from the configured `git` remote
(`origin`). An additional pkgdown website URL can optionally be
appended.

- Requires that the target directory is an R package root (contains a
  `DESCRIPTION` file).

- Both `https://` and `git@` style remotes are converted to a browser
  URL (a trailing `.git` suffix is removed).

## Usage

``` r
use_url(url = NULL, pkgdown_url = NULL, path = NULL, ...)
```

## Arguments

- url:

  Character. The primary URL (usually the GitHub repository). If `NULL`
  (the default), it is detected from the `git` remote configuration.

- pkgdown_url:

  Character. An optional pkgdown website URL, appended after `url`.

- path:

  Path to the package root. If `NULL` (the default), the current working
  directory is used.

- ...:

  Must be empty. Reserved for future arguments.

## Value

Invisibly returns the URLs that were written.

## Examples

``` r
if (FALSE) { # \dontrun{
tmpdir <- tempdir()
usethis::create_package(path = tmpdir)
use_url(
  url = "https://github.com/WangLabCSU/rpkgkit",
  pkgdown_url = "https://wanglabcsu.github.io/rpkgkit/",
  path = tmpdir
)
} # }
```
