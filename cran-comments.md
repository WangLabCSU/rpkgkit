## R CMD check results

0 errors | 0 warnings | 2 notes

* This is a new submission.

## Notes

* The NOTE "New submission" is expected for first-time CRAN submissions and will be
  resolved once the package is accepted.

* NOTE about `pedant` package dependency: This package uses `pedant` (GitHub only,
  `wurli/pedant`) in the `make_func_call_explicit()` function for adding double-colon
  prefixes to function calls. To comply with CRAN policy, `Remotes` is not declared in
  DESCRIPTION, and `pedant` is listed only in `Suggests` (not `Imports`). In practice,
  we provide a runtime check similar to `rlang::check_installed()`: when
  `make_func_call_explicit()` is called without `pedant` installed, the user is prompted
  to install it interactively via `pak::pkg_install("wurli/pedant")`.

## Reverse Dependencies

There are no reverse dependencies.

## Method References

This package implements original functionality for R package development
workflows. There are no published references describing the methods in this
package.
