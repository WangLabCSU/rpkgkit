# Add a `BugReports` field to a package's `DESCRIPTION`

Sets the `BugReports` field of a package's `DESCRIPTION` file. By
default, the GitHub issues page URL is derived from the configured `git`
remote (`origin`).

- Requires that the target directory is an R package root (contains a
  `DESCRIPTION` file).

- Both `https://` and `git@` style remotes are supported (see
  [`use_url()`](https://wanglabcsu.github.io/rpkgkit/reference/use_url.md)).

## Usage

``` r
use_bugreports(url = NULL, path = NULL, ...)
```

## Arguments

- url:

  Character. The bug reports URL (usually the GitHub issues page). If
  `NULL` (the default), it is derived from the `git` remote
  configuration by appending `/issues` to the repository URL.

- path:

  Path to the package root. If `NULL` (the default), the current working
  directory is used.

- ...:

  Must be empty. Reserved for future arguments.

## Value

Invisibly returns the URL that was written.

## Examples

``` r
# \donttest{
tmpdir <- tempdir()
usethis::create_package(path = tmpdir)
#> ✔ Setting active project to "/tmp/Rtmp9AGm6P".
#> ✔ Creating R/.
#> ✔ Writing DESCRIPTION.
#> Package: Rtmp9AGm6P
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
use_bugreports(
  url = "https://github.com/WangLabCSU/rpkgkit/issues",
  path = tmpdir
)
#> ✔ Setting active project to "/tmp/Rtmp9AGm6P".
#> ✔ Setting BugReports field to <https://github.com/WangLabCSU/rpkgkit/issues>.
# }
```
