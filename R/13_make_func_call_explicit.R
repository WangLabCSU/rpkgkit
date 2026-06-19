#' Make Function Calls Explicit
#'
#' @description
#' Add double colons (`::`) to function calls from specified packages to make
#' package dependencies explicit in R code.
#'
#' @param path A character string specifying the path to the R file to modify.
#'   If `NULL` and RStudio is available, the currently active document path is used.
#' @param use_packages A character vector of package names to process. Defaults to
#'   `pedant::current_packages()`.
#' @param ignore_functions A character vector of function names to ignore. Defaults to
#'   `pedant::imported_functions()`.
#' @param ... Additional arguments. Currently unused and must be empty.
#'
#' @return
#' Invisible `NULL`. This function is called for its side effect of modifying the
#' specified file in place.
#'
#' @details
#' This function reads the specified R file, identifies function calls from the
#' specified packages, and adds explicit namespace qualifiers (`::`) to those
#' calls. The modified code is written back to the original file.
#'
#' @seealso
#' [pedant::add_double_colons()], [pedant::current_packages()], [pedant::imported_functions()]
#'
#' @examples
#' \dontrun{
#' make_func_call_explicit("path/to/file.R")
#' make_func_call_explicit(
#'   path = "path/to/file.R",
#'   use_packages = c("dplyr", "tidyr"),
#'   ignore_functions = c("library", "require")
#' )
#' }
#'
#' @export
make_func_call_explicit <- function(
  path = NULL,
  use_packages = pedant::current_packages(),
  ignore_functions = pedant::imported_functions(),
  ...
) {
  rlang::check_dots_empty0()
  if (!rlang::is_installed("pedant")) {
    choice <- utils::askYesNo(cli::cli_fmt(cli::cli_alert_info(
      "{.pkg pedant} is not installed. Would you like to install it?"
    )))
    if (!isTRUE(choice)) {
      stop("Installation of pedant package is required")
    }
    pak::pkg_install("wurli/pedant")
  }
  path <- if (is.null(path) && rlang::is_installed("rstudioapi")) {
    rstudioapi::getActiveDocumentContext()$path
  } else {
    cli::cli_abort(("c" = "{.arg path} is required"))
  }

  cli::cli_alert_info("Retrieving function calls from {.pkg {use_packages}}")
  formated_code <- pedant::add_double_colons(
    code = paste(readLines(path), collapse = "\n"),
    use_packages = use_packages,
    ignore_functions = ignore_functions
  )
  writeLines(formated_code, path)
  cli::cli_alert_success(
    "Successfully made function call explicit in {.file {path}}"
  )
}
