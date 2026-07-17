# ---
# repo: WangLabCSU/rpkgkit
# file: standalone-caller_cli.R
# last-updated: 2026-06-27
# license: https://unlicense.org
# imports: [cli, rlang]
# ---
#
# Retrieve caller name and add caller context to CLI functions.
#
# ## Changelog:
#
# 2026-06-27:
# * Fixed lints
#
# nocov start

#' @title Get Caller Name
#'
#' @description
#' Retrieves the name of the function that called the current execution context.
#' If called from the global environment, returns "global".
#'
#' @param offset Integer. The number of stack frames to go back.
#'        Defaults to 2 (skipping the get_caller_name frame and the Wrapper frame
#'        to find the User's function).
#'
#' @return Character string. E.g., "my_function()" or "global".
#'
#' @examples
#' \donttest{
#' f <- function() { get_caller_name() }
#' f() # Returns "f()"
#' }
#'
#' @noRd
get_caller_name <- function(offset = 2L) {
  # Calculate absolute frame position
  # sys.nframe() gives current depth.
  # We subtract offset to find the target frame index.
  target_frame <- sys.nframe() - offset

  if (target_frame < 1) {
    return("global")
  }

  # Retrieve the call object that initiated the target frame
  # sys.call(target_frame) gets the call expression (e.g., f(1, 2))
  call_obj <- sys.call(target_frame)

  # Extract function name using rlang for robustness against anonymous functions/formulas
  fn_name <- rlang::call_name(call_obj)

  if (is.null(fn_name)) {
    return("expression") # Handling cases like local({ ... }) or anonymous funcs
  }

  paste0(fn_name, "()")
}

#' @title A Decorator for Adding Caller Info to CLI Functions
#'
#' @description
#' Wraps CLI functions to automatically prepend the caller's identity
#' (function name or 'global') to the output message.
#'
#' @param cli_func A CLI function (e.g., \code{cli_alert_info}).
#'
#' @return A wrapper function that formats output as "\[caller\]: message".
#'
#' @noRd
add_caller_to_cli <- function(cli_func, offset = 2L) {
  force(cli_func)

  function(...) {
    # offset = 1 because we are inside this anonymous wrapper function.
    # We look back 1 frame to find who called this wrapper.
    caller_name <- get_caller_name(offset = offset)

    messages <- list(...)

    if (length(messages) > 0 && is.character(messages[[1]])) {
      # Construct the prefix: [caller]:
      prefix <- paste0("[", caller_name, "]: ")
      messages[[1]] <- paste0(prefix, messages[[1]])
    }

    do.call(cli_func, messages)
  }
}

#' @title Create Environment with Caller-Aware CLI Functions
#'
#' @description
#' Generates an environment containing CLI functions that automatically
#' report their caller (Global or Function Name).
#'
#' @param cli_functions Character vector of function names from package \code{cli}.
#'
#' @return An environment with wrapped functions.
#'
#' @examples
#' \donttest{
#' caller_cli <- create_caller_cli_env()
#'
#' # Global context
#' caller_cli$cli_alert_info("Hello")
#' # Output: [global]: Hello
#'
#' # Function context
#' f <- function(x) { caller_cli$cli_alert_success("Result is {x}") }
#' f(100)
#' # Output: [f()]: Result is 100
#' }
#'
#' @noRd
create_caller_cli_env <- function(
  cli_functions = c(
    "cli_alert_info",
    "cli_alert_success",
    "cli_alert_warning",
    "cli_alert_danger",
    "cli_inform"
  )
) {
  cli_env <- new.env()

  vapply(
    X = cli_functions,
    FUN = function(func_name) {
      if (exists(func_name, envir = asNamespace("cli"))) {
        orig_func <- get0(func_name, envir = asNamespace("cli"))

        new_func <- add_caller_to_cli(orig_func, offset = 2L)

        assign(func_name, new_func, envir = cli_env)
        list(NULL)
      }
    },
    FUN.VALUE = list(NULL)
  )

  invisible(cli_env)
}

# nocov end
