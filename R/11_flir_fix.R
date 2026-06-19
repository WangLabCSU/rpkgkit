#' Fix R code or package using flir
#'
#' @description
#' Automatically detect the type of path (file, package, or directory) and
#' apply the appropriate flir fix function.
#'
#' @param path A file path, package directory path, or NULL. If NULL and
#'   running in RStudio, uses the active document path.
#' @param ... Additional arguments passed to the underlying flir fix function.
#'
#' @details
#' The function determines the fix strategy based on the path type:
#' - If `path` points to an existing file, calls `flir::fix()`
#' - If `path` is a package directory (contains DESCRIPTION), calls `flir::fix_package()`
#' - If `path` is a directory, calls `flir::fix_dir()`
#'
#' @return Invisibly returns the result from the called flir function.
#'
#' @examplesIf rlang::is_installed("flir")
#' tmp <- tempfile(fileext = ".R")
#' writeLines("a<-1+1", tmp)
#' flir_fix(tmp)
#' cat(readLines(tmp, warn = FALSE), sep = "\n")
#' @export
flir_fix <- function(path = NULL, ...) {
  rlang::check_installed("flir")
  path <- path %||% rstudioapi::getActiveDocumentContext()$path

  cli::cli_alert_info("Fixing R code in {.path {path}}")

  if (file.exists(path)) {
    flir::fix(path = path, ...)
  } else if (is_pkg(path)) {
    flir::fix_package(path = path, ...)
  } else if (dir.exists(path)) {
    flir::fix_dir(path = path, ...)
  }
}
