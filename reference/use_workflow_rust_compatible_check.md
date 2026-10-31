# Create a Rust-compatible R-CMD-check Workflow

Copies the built-in `R-CMD-Check.yaml` workflow template to the target
package's `.github/workflows/` directory, so that `R CMD check` runs on
GitHub Actions with a toolchain that can download, compile and link Rust
crates (packages built on `extendr`/`rextendr`).

## Usage

``` r
use_workflow_rust_compatible_check(path = NULL, overwrite = FALSE)
```

## Arguments

- path:

  Character. Path to the package root directory. If `NULL` (the
  default), uses the current working directory.

- overwrite:

  Logical. If `TRUE`, overwrite an existing workflow file. Defaults to
  `FALSE`.

## Value

Invisibly returns the path to the created workflow file.

## Why not the `usethis` workflow

`usethis::use_github_action("check-standard")` only sets up R and then
calls `R CMD check` on a matrix of operating systems. For packages with
Rust code this is not enough:

- No Rust toolchain is installed, so the runner default is used. On
  Windows that default is an **MSVC** toolchain, while R and Rtools are
  **GNU** based, so the static library produced by `cargo` cannot be
  linked, and the resulting build noise (`cargo` warnings, linker
  messages) makes `R CMD check` report a WARNING.

The template used here follows the official `extendr` CI:

- `dtolnay/rust-toolchain` installs the requested toolchain, and on
  Windows additionally the `x86_64-pc-windows-gnu` target that Rtools
  can link.

- The R matrix covers Windows, macOS, Ubuntu release and Ubuntu devel,
  with `fail-fast: false` so one broken platform does not hide the
  others.

- `R_REMOTES_NO_ERRORS_FROM_WARNINGS` keeps `remotes`/`pak` download
  noise from turning into check failures.

## Examples

``` r
if (FALSE) { # \dontrun{
temp <- tempdir()
usethis::create_package(temp)
use_workflow_rust_compatible_check(temp)
use_workflow_rust_compatible_check(temp, overwrite = TRUE)
} # }
```
