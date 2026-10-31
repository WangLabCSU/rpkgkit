# Package Setup & Maintenace

``` r

library(rpkgkit)
#> ✔ rpkgkit v0.1.21 loaded [2 ms]
dir <- tempdir()
usethis::create_package(path = dir, open = FALSE)
#> ✔ Setting active project to "/tmp/Rtmp4OwfNG".
#> ✔ Creating R/.
#> ✔ Writing DESCRIPTION.
#> Package: Rtmp4OwfNG
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
usethis::use_pkgdown()
#> ✔ Setting active project to "/home/runner/work/rpkgkit/rpkgkit".
#> ℹ Leaving _pkgdown.yml unchanged.
#> ☐ Edit _pkgdown.yml.
```

## Create package infrastructure

### A startup message

[`use_zzz()`](https://wanglabcsu.github.io/rpkgkit/reference/use_zzz.md)
creates a package documentation file with `.onLoad`, `.onAttach`, and
`%||%`. It is similar to
[`usethis::use_package_doc()`](https://usethis.r-lib.org/reference/use_package_doc.html)
while also providing a useful starting template.

``` r

use_zzz(path = dir, open = FALSE)
#> ✔ Setting active project to "/tmp/Rtmp4OwfNG".
#> ✔ Created /tmp/Rtmp4OwfNG/R/Rtmp4OwfNG-package.R from template.
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

### Configure the clangd language server

[`use_clangd()`](https://wanglabcsu.github.io/rpkgkit/reference/use_clangd.md)
writes a `.clangd` configuration file that lets the clangd language
server find the system R headers and the `include/` directory of the
packages you pass in `include` (`Rcpp`, `RcppEigen` and `RcppArmadillo`
by default). Packages that are not installed are skipped with a warning.

``` r

use_clangd(path = dir, overwrite = TRUE)
#> Warning: Package RcppEigen is not installed; skipping its
#> include path.
#> Warning: Package RcppArmadillo is not installed; skipping its
#> include path.
#> ✔ Created /tmp/Rtmp4OwfNG/.clangd.
```

When `path` is a package root, the file also disables background
indexing for the `R/` directory (which holds no C++ code) and adds
`.clangd` to `.Rbuildignore`.

``` r

use_clangd(path = dir, include = c("Rcpp", "BH"), overwrite = TRUE)
#> ! Overwriting /tmp/Rtmp4OwfNG/.clangd.
#> Warning: Package BH is not installed; skipping its include path.
#> ✔ Created /tmp/Rtmp4OwfNG/.clangd.
```

### Configure the jarl linter

[`use_jarl()`](https://wanglabcsu.github.io/rpkgkit/reference/use_jarl.md)
writes a `jarl.toml` file for [jarl](https://jarl.etiennebacher.com/),
the linter written in Rust. The file pins down the linting behaviour of
every `jarl` invocation, so the command line, your editor and CI all
agree. It enables the opt-in `TESTTHAT` group of rules, skips vendored
files, and lints the code inside `@examples` and `@examplesIf` tags.

``` r

use_jarl(path = dir, overwrite = TRUE)
#> ✔ Created /tmp/Rtmp4OwfNG/jarl.toml.
#> • Read jarl's editor support
#>   (<https://jarl.etiennebacher.com/reference/config-file>) to learn how to
#>   invoke jarl in your preferred editor.
#> 
#> • Read jarl's continuous integration
#>   (<https://jarl.etiennebacher.com/howto/ci>) to learn about GHA workflows that
#>   continuously run linting checks.
```

`jarl` reads a single configuration file: the closest `jarl.toml` in the
current directory or any of its parents, and finally the one in your
user configuration directory. When `path` is a package root, `jarl.toml`
is also added to `.Rbuildignore` so it stays out of the built tarball.

``` r

readLines(file.path(dir, "jarl.toml")) |> cli::cli_code()
#> # jarl configuration file
#> # Reference: https://jarl.etiennebacher.com/reference/config-file
#> [lint]
#> # Rules enabled on top of jarl's default rule set. The `TESTTHAT` group is
#> # opt-in, so it has to be requested explicitly.
#> extend-select = ["TESTTHAT"]
#> # Files or directories that jarl should not lint.
#> exclude = ["R/vendor-*.R"]
#> # Also lint the R code inside `@examples` and `@examplesIf` tags
#> # (the default).
#> check-roxygen = true
#> # Rules that `jarl check --fix` is allowed to fix (all rules by default).
#> # fixable = ["PERF"]
#> # Rules that `jarl check --fix` must leave untouched.
#> # unfixable = ["undesirable_function"]
```

Read the [configuration
reference](https://jarl.etiennebacher.com/reference/config-file) for
options such as `select`, `ignore` and `per-file-ignores`, and the
[continuous integration guide](https://jarl.etiennebacher.com/howto/ci)
to run `jarl check` on every push with the `etiennebacher/setup-jarl`
action.

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
#> ✔ Created directory /tmp/Rtmp4OwfNG/inst/vendor/rpkgkit.
#> ✔ Copied LICENSE.
#> ✔ Copied LICENSE.md.
#> ✔ Created inst/vendor/rpkgkit/README.md.
#> ✔ Created /tmp/Rtmp4OwfNG/R/vendor-rpkgkit.R.
#> ✔ Added rpkgkit authors to Authors@R.
#> ✔ Updated DESCRIPTION.
#> ☐ Consider pasting the following statement into README.md
#> 
#> 
#> ## Acknowledgements
#> 
#> We would like to thank the following people and projects:
#> 
#> - The authors of the [rpkgkit](https://github.com/WangLabCSU/rpkgkit) package &mdash; **Yuxi Yang** &mdash; whose code is included (under MIT license) in files named `vendor-rpkgkit.*`.
```

Only packages with a supported permissive license can be vendored.
Review the acknowledgement text printed by the function and add it to
your README when appropriate.

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
#> ✔ Added 38 pattern(s) to .Rbuildignore.
```

``` r

add_global_gitgnore(pkg = dir)
```

## GitHub Actions workflows

Each `use_workflow_*()` function copies a workflow template bundled in
`inst/actions/` into the `.github/` directory of the target package. All
of them create the directories they need, abort instead of overwriting
unless `overwrite = TRUE`, and return the written path invisibly.

### Bump the version from commit messages

[`use_workflow_version_update()`](https://wanglabcsu.github.io/rpkgkit/reference/use_workflow_version_update.md)
installs `version_update.yml` together with the `version-bumper`
composite action. The version is bumped from the commit message
(`major`/`breaking`, `feat`/`minor`, `patch`/`fix`), or explicitly
through `workflow_dispatch`. A bump is skipped when the new version
would exceed the highest version documented in `NEWS.md`, and the
`version` field of `src/rust/Cargo.toml` is kept in sync when the
package ships Rust code.

``` r

use_workflow_version_update(path = dir)
#> ✔ Created workflow: /tmp/Rtmp4OwfNG/.github/workflows/version_update.yml
#> → It triggers on push to "main/master" and via workflow_dispatch. Version bump
#>   is inferred from commit messages or manual input.
#> ☐ It is recommended to add a devel version badge to your README.md via
#> `badger::badge_devel(color = "blue")`
```

### Run `R CMD check` on packages with Rust code

[`use_workflow_rust_compatible_check()`](https://wanglabcsu.github.io/rpkgkit/reference/use_workflow_rust_compatible_check.md)
installs a `R-CMD-check.yaml` that can download, compile and link Rust
crates, which is what packages built on `extendr`/`rextendr` need. It
replaces `usethis::use_github_action("check-standard")` for such
packages.

``` r

use_workflow_rust_compatible_check(path = dir)
#> ✔ Created workflow: /tmp/Rtmp4OwfNG/.github/workflows/R-CMD-check.yaml
#> → It triggers on push to "main" and on pull requests targeting "main".
#> → Rust crates are compiled with a pinned toolchain and the
#>   "x86_64-pc-windows-gnu" target on Windows, so they link against Rtools.
```

The difference lies in the toolchain. The `usethis` workflow only sets
up R and leaves the runner default in place; on Windows that default is
an MSVC toolchain, while R and Rtools are GNU based, so the static
library produced by `cargo` cannot be linked and the resulting build
noise makes `R CMD check` report a WARNING. The template used here
follows the official `extendr` CI:

- `dtolnay/rust-toolchain` installs the requested toolchain and, on
  Windows, additionally the `x86_64-pc-windows-gnu` target that Rtools
  can link.
- The matrix covers Windows, macOS, Ubuntu release and Ubuntu devel with
  `fail-fast: false`, so one broken platform does not hide the others.
- `R_REMOTES_NO_ERRORS_FROM_WARNINGS` keeps download noise from
  `remotes` and `pak` from surfacing as a check failure.

### Sync `main` to a `test` branch

[`use_workflow_test_branch()`](https://wanglabcsu.github.io/rpkgkit/reference/use_workflow_test_branch.md)
adds a workflow that runs after `R-CMD-check.yaml` succeeds on
`main`/`master` and force-pushes the checked commit to `test`. The sync
is skipped when `test` holds commits that are not reachable from `main`,
so unmerged work is never overwritten. Push experimental changes to
`test` and each push to `main` resets it again.

``` r

use_workflow_test_branch(path = dir)
#> ✔ Created workflow: /tmp/Rtmp4OwfNG/.github/workflows/sync_test_branch.yml
#> → It runs after "R-CMD-check.yaml" succeeds for "main/master", then syncs the
#>   checked commit to "test".
#> → If "test" has unmerged work, the sync is skipped automatically.
```

## Check system dependencies

Some packages need system development libraries (graphics and font
libraries, for example) to compile.
[`check_sysdeps()`](https://wanglabcsu.github.io/rpkgkit/reference/check_sysdeps.md)
detects the package manager in use (`dpkg`, `rpm`, `pacman`, `apk` or
`brew`), checks each dependency with it, and reports every hit and miss
together with a ready-to-paste install command for the missing ones.

``` r

check_sysdeps()
#> Package manager: dpkg
#> ✔ libfreetype-dev|libfreetype6-dev
#> ✔ libjpeg-dev
#> ✔ libpng-dev
#> ✔ libtiff-dev
#> ✔ libwebp-dev
#> ✔ libharfbuzz-dev
#> ✔ libfribidi-dev
#> ✔ libfontconfig1-dev
#> ✔ All 8 system dependencies installed.
```

With `deps = NULL` (the default), a built-in list of graphics and font
libraries (`freetype`, `libjpeg`, `libpng`, `libtiff`, `libwebp`,
`harfbuzz`, `fribidi`, `fontconfig`) is checked using the names that the
detected package manager expects. Pass your own names in `deps`, and
optionally set `manager` to check against a manager other than the
detected one:

``` r

try(check_sysdeps(c("freetype-devel", "libwebp-devel"), manager = "rpm"))
#> Package manager: rpm
#> ✖ freetype-devel
#> ✖ libwebp-devel
#> ! Missing 2 dependencies: freetype-devel and libwebp-devel
#> ℹ Try installing with: `sudo dnf install -y freetype-devel libwebp-devel`
```

The result is returned invisibly as a named logical vector, so it can be
reused in scripts. Set `verbose = FALSE` to keep the run silent:

``` r

ok <- check_sysdeps(verbose = FALSE)
ok[!ok]
#> named logical(0)
```

## Detect the Positron version

[`get_positron_version()`](https://wanglabcsu.github.io/rpkgkit/reference/get_positron_version.md)
reports the version of the Positron IDE that hosts the current R
session. It is useful for diagnostics, bug reports, or for enabling
IDE-specific behaviour only on recent builds.

``` r

get_positron_version() # e.g. "2025.01.0"
get_positron_version(long = TRUE) # e.g. "2025.01.0-123"
```

The version is looked up in three steps, in this order:

1.  the `POSITRON_VERSION` environment variable set by Positron for its
    R sessions (`POSITRON_LONG_VERSION`, which also carries the build
    number, when `long = TRUE`);
2.  the `.ps.positron_version()` helper that the IDE injects into the
    session;
3.  the `positron --version` command-line tool.

If the session does not run inside Positron and no `positron` executable
is on `PATH`, the function returns `NA_character_` instead of throwing
an error, so it is safe to call in any session, including CI.
