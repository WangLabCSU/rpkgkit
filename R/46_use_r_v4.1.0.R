#' Set the minimum `R` version a package needs
#'
#' @description
#' `use_r()` scans the package sources for base R functions and syntax introduced
#' in recent R versions, then records the highest version it finds in the
#' `Depends` field of `DESCRIPTION` with [usethis::use_package()].
#' `use_r_v4.1.0()` is a shortcut that always requires `R (>= 4.1.0)`, the
#' version that introduced `\()` and `|>`.
#'
#' `use_r()` detects:
#'
#' * `R (>= 4.1.0)`: `|>`, `\()`, `isa()`.
#' * `R (>= 4.2.0)`: the `_` pipe placeholder in a named argument,
#'   `Sys.setLanguage()`.
#' * `R (>= 4.3.0)`: the `_` pipe placeholder heading an extraction chain.
#' * `R (>= 4.4.0)`: `%||%`, `sort_by()`, `Tailcall()`, `Exec()`.
#' * `R (>= 4.5.0)`: `use()`, `grepv()`, the `penguins` dataset.
#' * `R (>= 4.6.0)`: `%notin%`, `messageCondition()`,
#'   `match.arg(several.ok = "all")`, `barplot(orderH =)`.
#'
#' Names that the package defines itself, such as its own `%||%`, never raise
#' the requirement: they are reported and ignored. `|>`, `\()` and the `_`
#' placeholder are syntax rather than names, so they always count. A
#' `DESCRIPTION` that already requires a higher version is never downgraded.
#'
#' @param path Path to the package root. If `NULL` (the default), the current
#'   working directory is used.
#' @param ... Must be empty. Reserved for future arguments.
#'
#' @return `use_r()` invisibly returns the detected minimum R version, or
#'   `NULL` when nothing requires a recent R. `use_r_v4.1.0()` invisibly returns
#'   `NULL`, called for side effects.
#' @export
#'
#' @examples
#' \dontrun{
#' tmpdir <- tempdir()
#' usethis::create_package(path = tmpdir)
#' use_r_v4.1.0(path = tmpdir)
#' use_r(path = tmpdir)
#' }
#' @name use_r

#' @rdname use_r
#' @export
use_r_v4.1.0 <- function(path = NULL, ...) {
  rlang::check_dots_empty()
  rlang::check_installed("usethis")
  path <- path %||% "."
  if (!is_pkg(path = path)) {
    cli::cli_abort(c(
      "x" = "{.path {path}} is not an R package root.",
      ">" = "No {.file DESCRIPTION} found."
    ))
  }
  usethis::proj_set(path = path)
  usethis::use_package(package = "R", type = "Depends", min_version = "4.1.0")
}
