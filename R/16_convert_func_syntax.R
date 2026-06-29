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
  rlang::check_dots_empty0()

  path <- if (is.null(path) && rlang::is_installed("rstudioapi")) {
    rstudioapi::getActiveDocumentContext()$path
  } else {
    path %||%
      cli::cli_abort(c("x" = "{.arg path} is required when not in RStudio."))
  }

  direction <- match_arg(direction, c("to_lambda", "to_explicit"))

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
  repeat {
    new_text <- .cfs_process_text_once(text, direction)
    if (identical(new_text, text)) {
      break
    }
    text <- new_text
  }
  text
}


#' Internal: single-pass character-level transformation
#'
#' @keywords internal
.cfs_process_text_once <- function(text, direction) {
  chars <- strsplit(text, NULL)[[1L]]
  nc <- length(chars)

  result <- character()
  i <- 1L
  in_string <- FALSE
  string_char <- NA_character_
  in_comment <- FALSE

  while (i <= nc) {
    ch <- chars[i]

    # ---- Track string state ----
    if (!in_comment && !in_string && ch %in% c("'", '"')) {
      in_string <- TRUE
      string_char <- ch
      result <- c(result, ch)
      i <- i + 1L
      next
    }
    if (in_string) {
      if (ch == "\\" && i < nc) {
        result <- c(result, ch, chars[i + 1L])
        i <- i + 2L
        next
      }
      if (ch == string_char) {
        in_string <- FALSE
      }
      result <- c(result, ch)
      i <- i + 1L
      next
    }

    # ---- Track comment state ----
    if (!in_comment && ch == "#") {
      in_comment <- TRUE
      result <- c(result, ch)
      i <- i + 1L
      next
    }
    if (in_comment) {
      result <- c(result, ch)
      if (ch == "\n") {
        in_comment <- FALSE
      }
      i <- i + 1L
      next
    }

    # ---- Outside strings and comments: match function definitions ----
    if (direction == "to_lambda") {
      # Match the "function" keyword at a word boundary
      if (
        i + 7L <= nc &&
          substr(text, i, i + 7L) == "function" &&
          (i == 1L || !grepl("[a-zA-Z0-9._]", chars[i - 1L]))
      ) {
        # Skip optional whitespace / newlines before the opening paren
        j <- i + 8L
        while (j <= nc && chars[j] %in% c(" ", "\t", "\n", "\r")) {
          j <- j + 1L
        }
        if (j <= nc && chars[j] == "(") {
          close <- .cfs_find_matching_paren(chars, j)
          if (!is.na(close)) {
            result <- c(result, "\\", chars[j:close])
            i <- close + 1L
            next
          }
        }
      }
    } else {
      # Match "\\(" — the R 4.1+ lambda syntax
      if (ch == "\\" && i < nc && chars[i + 1L] == "(") {
        close <- .cfs_find_matching_paren(chars, i + 1L)
        if (!is.na(close)) {
          result <- c(result, "function", chars[(i + 1L):close])
          i <- close + 1L
          next
        }
      }
    }

    # No match: emit the character unchanged
    result <- c(result, ch)
    i <- i + 1L
  }

  paste(result, collapse = "")
}


#' Internal: find the matching closing parenthesis
#'
#' @keywords internal
.cfs_find_matching_paren <- function(chars, open_pos) {
  depth <- 0L
  for (i in open_pos:length(chars)) {
    if (chars[i] == "(") {
      depth <- depth + 1L
    }
    if (chars[i] == ")") {
      depth <- depth - 1L
      if (depth == 0L) return(i)
    }
  }
  NA_integer_
}
