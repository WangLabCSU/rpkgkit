#' @title Create and Maintain R Packages
#'
#' @description Utilities for R package development including NEWS.md
#' management, standalone file creation, and code formatting. Supports popular
#' development workflows and integrates with 'usethis' and 'RStudio'. Includes
#' helper functions for renaming functions and detecting common coding errors.
#'
#' @section License:
#' MIT + file LICENSE
#'
#' @docType package
#' @name rpkgkit-package
#' @aliases rpkgkit
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


## usethis namespace: start
## usethis namespace: end
NULL
