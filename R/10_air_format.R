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
#' system PATH. If not, provides OS-specific installation instructions and
#' aborts with an informative error.
#'
#' @return Invisibly returns `TRUE` if `air` is found.
#'
#' @details
#' Installation methods per OS:
#'
#' **Linux:**
#' `curl -LsSf https://github.com/posit-dev/air/releases/latest/download/air-installer.sh | sh`
#'
#' **Windows:**
#' `powershell -ExecutionPolicy Bypass -c "irm https://github.com/posit-dev/air/releases/latest/download/air-installer.ps1 | iex"`
#'
#' **macOS (Homebrew):**
#' `brew install air`
#'
#' **All platforms (uv):**
#' `uv tool install air-formatter`
#'
#' @keywords internal
check_air_installed <- function() {
  if (nzchar(Sys.which("air"))) {
    return(invisible(TRUE))
  }

  os <- tolower(Sys.info()[["sysname"]])

  install_instructions <- switch(
    os,
    linux = c(
      "x" = "{.pkg air} is not installed.",
      "i" = "Install on Linux with:",
      ">" = "`curl -LsSf https://github.com/posit-dev/air/releases/latest/download/air-installer.sh | sh`"
    ),
    darwin = c(
      "x" = "{.pkg air} is not installed.",
      "i" = "Install on macOS with {.pkg Homebrew}:",
      ">" = "`brew install air`",
      "i" = "Or install with {.pkg uv} (any platform):",
      ">" = "`uv tool install air-formatter`"
    ),
    windows = c(
      "x" = "{.pkg air} is not installed.",
      "i" = "Install on Windows with:",
      ">" = "`powershell -ExecutionPolicy Bypass -c \"irm https://github.com/posit-dev/air/releases/latest/download/air-installer.ps1 | iex\"`"
    ),
    c(
      "x" = "{.pkg air} is not installed.",
      "i" = "See installation instructions at: https://github.com/posit-dev/air"
    )
  )

  cli::cli_abort(install_instructions)
}
