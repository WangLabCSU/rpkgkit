# Create a `.clangd` configuration file

Writes a `.clangd` configuration file at `path` with `CompileFlags` set
to include headers from the system R installation and from common C++
interface packages (`Rcpp`, `RcppEigen`, `RcppArmadillo`). If `path` is
the root of an R package (contains a `DESCRIPTION` file), an additional
`If:` block is appended that disables background indexing for the `R/`
source directory, since it only contains R code, not C++ source. In that
case `.clangd` is also added to `.Rbuildignore` (inside a scoped
project, so the active project of the calling session is restored
afterwards).

- `.clangd` is the configuration file read by the clangd language
  server. It is typically placed in the project root.

- The system R include directory is obtained via
  [`base::R.home()`](https://rdrr.io/r/base/Rhome.html) with component
  `"include"`.

- Package include directories are obtained via
  [`base::system.file()`](https://rdrr.io/r/base/system.file.html) with
  `package = <pkg>`.

- Packages that are not installed (or that have no `include/` directory)
  are skipped with a
  [`cli::cli_warn()`](https://cli.r-lib.org/reference/cli_abort.html)
  warning.

## Usage

``` r
use_clangd(
  path = NULL,
  include = c("Rcpp", "RcppEigen", "RcppArmadillo"),
  overwrite = FALSE,
  open = rlang::is_interactive(),
  ...
)
```

## Arguments

- path:

  Character. Path to the directory where `.clangd` should be written. If
  `NULL` (the default), the current working directory is used.

- include:

  Character vector of package names whose `include/` directories should
  be added to `CompileFlags.Add`. Defaults to
  `c("Rcpp", "RcppEigen", "RcppArmadillo")`. Pass `character(0)` to add
  only the system R include path. Custom names such as `"BH"` are
  supported; if the package is not installed, its include path is
  skipped and a warning is emitted.

- overwrite:

  Logical. If `TRUE`, overwrite an existing `.clangd` file. Defaults to
  `FALSE`.

- open:

  Logical. Whether to open the created file in the editor. Defaults to
  [`rlang::is_interactive()`](https://rlang.r-lib.org/reference/is_interactive.html).
  Only takes effect when `rstudioapi` is installed.

- ...:

  Must be empty. Reserved for future arguments.

## Value

Invisibly returns the path to the created `.clangd` file.

## Examples

``` r
# \donttest{
tmp <- tempdir()
use_clangd(path = tmp)
#> Warning: Package RcppEigen is not installed; skipping its include path.
#> Warning: Package RcppArmadillo is not installed; skipping its include path.
#> ✔ Created /tmp/Rtmp0sdzOO/.clangd.

# Custom include library names
use_clangd(
  path = tmp,
  include = c("Rcpp", "BH"),
  overwrite = TRUE
)
#> ! Overwriting /tmp/Rtmp0sdzOO/.clangd.
#> Warning: Package BH is not installed; skipping its include path.
#> ✔ Created /tmp/Rtmp0sdzOO/.clangd.
# }
```
