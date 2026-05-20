# ---
# repo: Exceret/rpkgkit
# file: standalone-ts_cli.R
# last-updated: 2026-05-20
# license: https://unlicense.org
# imports: [cli]
# ---

#' @title Generate Timestamp String
#'
#' @description
#' Creates a formatted character string representing the current system time.
#' The format is "YYYY/mm/DD HH:MM:SS" (year/month/day hour:minute:second).
#'
#' @return Character string with current time in "YYYY/mm/DD HH:MM:SS" format.
#'
#'
#' @examples
#' \dontrun{
#' # Current time as formatted string
#' time_stamp()
#' # Returns something like: "2025/06/15 16:04:00"
#' }
#'
#' @noRd
#' @family ts_cli
#'
time_stamp <- function() {
  format(Sys.time(), "%Y/%m/%d %H:%M:%S")
}


#' @title A Decorator for Adding Timestamp to CLI Functions
#'
#' @description
#' A higher-order function that wraps CLI functions to automatically prepend
#' timestamps to their output messages. This creates a modified version of
#' any CLI function that includes timestamp information in its output.
#'
#' @param cli_func A CLI function from the \code{cli} package (e.g., \code{cli_alert_info},
#'                 \code{cli_warn}) that will be wrapped with timestamp functionality.
#'
#' @return Returns a modified version of the input function that automatically
#'         adds a timestamp in the format \code{"[{time_stamp()}]"} to the beginning
#'         of all character messages passed to it.
#'
#' @details
#' This function uses \code{\link{force}} to ensure the CLI function is evaluated
#' at creation time. The timestamp is generated using a \code{time_stamp()} function
#' which should be available in the execution environment and is inserted using
#' cli's glue-like syntax \code{"{ }"}.
#'
#' @examples
#' \dontrun{
#' # Create a timestamp-enabled version of cli_alert_info
#' timestamp_alert <- add_timestamp_to_cli(cli::cli_alert_info)
#' timestamp_alert("This message will have a timestamp")
#' }
#'
#' @seealso \code{\link{create_ts_cli_env}} for creating a complete environment
#'          of timestamped CLI functions.
#'
#' @noRd
#' @family ts_cli
#'
add_timestamp_to_cli <- function(cli_func) {
  function(...) {
    messages <- list(...)

    if (length(messages) > 0L) {
      if (is.character(messages[[1L]])) {
        messages[[1L]] <- paste0("[{time_stamp()}] ", messages[[1L]])
      }
    }

    do.call(cli_func, messages)
  }
}
#' @title Create Environment with Timestamped CLI Functions
#'
#' @description
#' Generates an environment containing wrapped versions of common CLI functions
#' that automatically include timestamps in their output. This provides a
#' convenient way to use multiple CLI functions with consistent timestamping.
#'
#' @param cli_functions from package \code{cli} to be wrapped with timestamp functionality.
#'
#' @return Returns an environment containing timestamp-wrapped versions of:
#' \itemize{
#'   \item \code{cli_alert_info}
#'   \item \code{cli_alert_success}
#'   \item \code{cli_alert_warning}
#'   \item \code{cli_alert_danger}
#' }
#' Each function in the environment will automatically prepend timestamps to
#' its output messages.
#'
#' @details
#' This function creates a new environment and populates it with timestamped
#' versions of commonly used CLI functions from the \code{cli} package. Only
#' functions that exist in the loaded \code{cli} package are added to the
#' environment.
#'
#' @examples
#' \dontrun{
#' # Create environment with timestamped CLI functions
#' cli_env <- create_ts_cli_env()
#'
#' # Use timestamped functions
#' cli_env$cli_alert_info("System started")
#' cli_env$cli_alert_success("Operation completed")
#' }
#'
#' @seealso \code{\link{add_timestamp_to_cli}} for the wrapper function used internally.
#'
#' @noRd
#' @family ts_cli
#'
create_ts_cli_env <- function(
  cli_functions = c(
    "cli_alert_info",
    "cli_alert_success",
    "cli_alert_warning",
    "cli_alert_danger"
  )
) {
  cli_env <- new.env()

  vapply(
    X = cli_functions,
    FUN = function(func_name) {
      if (exists(func_name, envir = asNamespace("cli"))) {
        orig_func <- get0(x = func_name, envir = asNamespace("cli"))

        new_func <- add_timestamp_to_cli(orig_func)

        assign(func_name, new_func, envir = cli_env)
        list(NULL)
      }
    },
    FUN.VALUE = list(NULL)
  )

  invisible(cli_env)
}
