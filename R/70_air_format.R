#' Format R code using air
#'
#' @param path Path to the R file to format. If NULL, attempts to use the active
#'   document in RStudio (requires `rstudioapi` package).
#' @param ... Additional arguments passed to `system2()`.
#'
#' @details
#' Install [air](https://github.com/posit-dev/air):
#'
#' Linux: `curl -LsSf https://github.com/posit-dev/air/releases/latest/download/air-installer.sh | sh`
#' Windows: `powershell -ExecutionPolicy Bypass -c "irm https://github.com/posit-dev/air/releases/latest/download/air-installer.ps1 | iex"`
#' uv: `uv tool install air-formatter`
#' brew (MacOS): `brew install air`
#'
#' @return The exit status of the `air format` command (invisibly).
#'
#' @examples
#' \dontrun{
#' air_format(system.file("R_template/zzz_template.R", package = "rpkgkit"))
#' }
#' @export
air_format <- function(path = NULL, ...) {
  check_air_installed()
  if (is.null(path)) {
    if (rlang::is_installed("rstudioapi")) {
      path <- rstudioapi::getActiveDocumentContext()$path
    } else {
      cli::cli_abort(c("c" = "{.arg path} is required"))
    }
  }
  on.exit(cli::cli_alert_success("{.pkg Air} formatted {.path {path}}"))

  system2(
    command = "air",
    args = c(
      "format",
      path
    ),
    ...
  )
}

#' Check that the air formatter is installed
#'
#' @description
#' Verifies that `air` (the R code formatter from Posit) is available on the
#' system PATH. In an interactive session, offers to install it when missing.
#' This prompt is skipped while tests are running. Otherwise, it aborts with
#' OS-specific installation instructions.
#'
#' @return Invisibly returns `TRUE` if `air` is found.
#'
#' @details
#' Installation methods per OS:
#'
#' **Linux:**
#' `curl --proto '=https' --tlsv1.2 -LsSf https://github.com/posit-dev/air/releases/latest/download/air-installer.sh | sh`
#'
#' **Windows:**
#' `powershell -ExecutionPolicy Bypass -c "irm https://github.com/posit-dev/air/releases/latest/download/air-installer.ps1 | iex"`
#'
#' **macOS:**
#' `curl --proto '=https' --tlsv1.2 -LsSf https://github.com/posit-dev/air/releases/latest/download/air-installer.sh | sh`
#'
#' @keywords internal
check_air_installed <- function() {
  if (nzchar(Sys.which("air"))) {
    return(invisible(TRUE))
  }

  os <- tolower(Sys.info()[["sysname"]])
  install_command <- switch(
    os,
    linux = paste(
      "curl --proto '=https' --tlsv1.2 -LsSf",
      "https://github.com/posit-dev/air/releases/latest/download/air-installer.sh",
      "| sh"
    ),
    darwin = paste(
      "curl --proto '=https' --tlsv1.2 -LsSf",
      "https://github.com/posit-dev/air/releases/latest/download/air-installer.sh",
      "| sh"
    ),
    windows = paste0(
      "powershell -ExecutionPolicy Bypass -c ",
      "\"irm https://github.com/posit-dev/air/releases/latest/download/",
      "air-installer.ps1 | iex\""
    ),
    NULL
  )

  if (
    isTRUE(rlang::is_interactive()) &&
      !(rlang::is_installed("testthat") && testthat::is_testing()) &&
      !is.null(install_command) &&
      isTRUE(utils::askYesNo("air is not installed. Install it now?"))
  ) {
    status <- system(install_command)
    if (identical(status, 0L)) {
      return(invisible(TRUE))
    }

    cli::cli_abort("Failed to install {.pkg air}.")
  }

  install_instructions <- switch(
    os,
    linux = c(
      "x" = "{.pkg air} is not installed.",
      "i" = "Install on Linux with:",
      ">" = "`{install_command}`"
    ),
    darwin = c(
      "x" = "{.pkg air} is not installed.",
      "i" = "Install on macOS with:",
      ">" = "`{install_command}`"
    ),
    windows = c(
      "x" = "{.pkg air} is not installed.",
      "i" = "Install on Windows with:",
      ">" = "`{install_command}`"
    ),
    c(
      "x" = "{.pkg air} is not installed.",
      "i" = "See installation instructions at: https://github.com/posit-dev/air"
    )
  )

  cli::cli_abort(install_instructions)
}
