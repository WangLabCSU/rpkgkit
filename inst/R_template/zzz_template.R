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
  if (startup_message_allowed()) {
    cli::cli_process_done(.envir = .time_record)
  }
}

.onLoad <- function(libname, pkgname) {
  if (startup_message_allowed()) {
    pkg_version <- utils::packageVersion(pkgname)
    .time_record$pkgname <- pkgname
    .time_record$pkg_version <- pkg_version
    cli::cli_progress_step(
      msg = "Loading {.pkg {pkgname}} v{pkg_version}",
      msg_done = "{.pkg {pkgname}} v{pkg_version} loaded",
      spinner = TRUE,
      .envir = .time_record
    )
  }

  invisible()
}

.time_record <- new.env()


startup_message_allowed <- function() {
  allowed <- FALSE

  withRestarts(
    {
      signalCondition(structure(
        list(message = ".__startup_probe__."),
        class = c(
          "packageStartupProbe",
          "packageStartupMessage",
          "condition"
        )
      ))
      allowed <- TRUE
    },
    muffleMessage = function() NULL
  )

  allowed
}
