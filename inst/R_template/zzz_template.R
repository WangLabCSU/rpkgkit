#' @title TITLE
#'
#' @description DESCRIPTION
#'
#' @section License:
#' LICENSE
#'
#' @docType package
#' @name PKG-package
#' @aliases PKG
#' @keywords internal
#'
"_PACKAGE"


.onAttach <- function(libname, pkgname) {
  pkg_version <- utils::packageVersion(pkgname)

  msg <- cli::cli_fmt(cli::cli_alert_success(
    "{.pkg {pkgname}} v{pkg_version} loaded"
  ))
  packageStartupMessage(msg)
  invisible()
}

.onLoad <- function(libname, pkgname) {
  invisible()
}
