#' Add a minimum `R` version dependency to a package
#'
#' @description
#' Adds `R (>= 4.1.0)` to the `Depends` field of a package's `DESCRIPTION` file.
#' This sets a minimum R version requirement for your package. Then you can use
#' `\()` and `|>` syntax in your package.
#'
#' * Requires that the target directory is an R package root (contains a
#'   `DESCRIPTION` file).
#' * Calls [usethis::use_package()] to add the dependency.
#'
#' @param path Path to the package root. If `NULL` (the default), the current
#'   working directory is used.
#' @param ... Must be empty. Reserved for future arguments.
#'
#' @return Invisibly returns `NULL`, called for side effects.
#' @export
#'
#' @examples
#' \donttest{
#' tmpdir <- tempdir()
#' usethis::create_package(path = tmpdir)
#' use_r_v4.1.0(path = tmpdir)
#' }
use_r_v4.1.0 <- function(path = NULL, ...) {
  rlang::check_dots_empty()
  rlang::check_installed("usethis")
  path <- path %||% "."
  if (!is_pkg(path = path)) {
    cli::cli_abort(c(
      x = "{.path {path}} is not an R package root.",
      `>` = "No {.file DESCRIPTION} found."
    ))
  }
  usethis::proj_set(path = path)
  usethis::use_package(package = "R", type = "Depends", min_version = "4.1.0")
}
