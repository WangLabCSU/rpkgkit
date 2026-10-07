# nocov start

#' @title Create and Maintain R Packages
#'
#' @description Utilities for R package development including NEWS.md
#' management, standalone file creation, and code formatting. Supports
#' popular development workflows and integrates with 'usethis' and
#' 'RStudio'. Includes helper functions for renaming functions and
#' detecting common coding errors.
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
  if (startup_message_allowed()) {
    pkg_version <- utils::packageVersion(pkgname)
    end <- Sys.time()
    elapsed <- cli_timestamp_formatter(as.numeric(end - .time_record$start))
    cli::cli_alert_success(sprintf(
      "{.pkg {pkgname}} v{pkg_version} loaded {cli::col_grey('[%s]')}",
      elapsed
    ))
  }
}

.onLoad <- function(libname, pkgname) {
  if (startup_message_allowed()) {
    .time_record$start <- Sys.time()
  }

  invisible()
}

.time_record <- new.env()

cli_timestamp_formatter <- function(x) {
  stopifnot(
    length(x) == 1L,
    is.numeric(x),
    !is.na(x),
    x >= 0L
  )

  if (x < 1L) {
    sprintf("%.2f ms", x * 1000L)
  } else if (x < 60L) {
    sprintf("%.2f s", x)
  } else if (x < 3600L) {
    sprintf("%d min %.2f s", floor(x / 60L), x %% 60L)
  } else {
    sprintf(
      "%d h %02d min %.2f s",
      floor(x / 3600L),
      floor((x %% 3600L) / 60L),
      x %% 60L
    )
  }
}

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

## usethis namespace: start
## usethis namespace: end
NULL

`%||%` <- function(x, y) {
  if (is.null(x)) {
    x <- y
  }
  x
}

# nocov end
