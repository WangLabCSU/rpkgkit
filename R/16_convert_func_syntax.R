#' Switch Between Explicit `function()` and Implicit `\()` Syntax
#'
#' @description
#' Converts all function definitions in an R file between the explicit
#' `function()` syntax and the R 4.1+ concise lambda `\()` syntax.
#' Handles strings and comments correctly, and supports nested function
#' definitions via iterative passes.
#'
#' @param path A character string specifying the path to the R file to modify.
#'   If `NULL` and RStudio is available, the currently active document path is used.
#' @param direction Conversion direction. One of:
#'   - `"to_lambda"`: convert `function(...)` to `\(...)`
#'   - `"to_explicit"`: convert `\(...)` to `function(...)`
#' @param ... Additional arguments. Currently unused and must be empty.
#'
#' @return
#' Invisibly returns the path to the modified file.
#'
#' @details
#' The conversion correctly handles strings, comments, and nested parentheses
#' in default argument values (e.g., `function(x = foo(y))`).
#'
#' Nested function definitions (e.g., `function(x, f = function(y) ...)`) are
#' converted in multiple iterative passes, so all nesting levels are reached.
#'
#' @examples
#' \donttest{
#' temp <- tempfile(fileext = ".R")
#' writeLines("add_one <- function(x) x + 1", temp)
#' convert_func_syntax(temp, direction = "to_lambda")
#' readLines(temp)
#' # "add_one <- \\(x) x + 1"
#' convert_func_syntax(temp, direction = "to_explicit")
#' readLines(temp)
#' # "add_one <- function(x) x + 1"
#' }
#'
#' @export
convert_func_syntax <- function(
  path = NULL,
  direction = c("to_lambda", "to_explicit"),
  ...
) {
  rlang::check_dots_empty0(...)

  path <- path %||%
    if (rstudioapi::isAvailable()) rstudioapi::getActiveDocumentContext()$path
  if (is.null(path) || !nzchar(path)) {
    cli::cli_abort(c("x" = "{.arg path} is required"))
  }

  direction <- match_arg(direction, c("to_lambda", "to_explicit"), NULL)

  text <- readLines(path, warn = FALSE)
  original <- paste(text, collapse = "\n")

  result <- .cfs_transform_text(original, direction)

  if (identical(result, original)) {
    cli::cli_alert_info(
      "No function definitions to convert in {.file {path}}"
    )
    return(invisible(path))
  }

  writeLines(result, path)
  cli::cli_alert_success(
    "Converted function definitions in {.file {path}} to {.val {direction}}"
  )

  invisible(path)
}


#' Internal: iterative transform (handles nesting via multiple passes)
#'
#' @keywords internal
.cfs_transform_text <- function(text, direction) {
  cfs_transform_text_rs(text, direction)
}


#' Internal: single-pass character-level transformation
#'
#' @keywords internal
.cfs_process_text_once <- function(text, direction) {
  cfs_process_text_once_rs(text, direction)
}


#' Internal: find the matching closing parenthesis
#'
#' @keywords internal
.cfs_find_matching_paren <- function(chars, open_pos) {
  cfs_find_matching_paren_rs(
    text = paste0(chars, collapse = ""),
    open_pos = as.integer(open_pos)
  )
}
