#' @title Convert Non-ASCII Code
#'
#' @description
#' Converts non-ASCII characters in R code to their ASCII escape sequences
#' (e.g., `\uXXXX`), or restores ASCII escape sequences back to readable
#' characters. Accepts either an R expression (via NSE) or a file path
#' (as a character string).
#'
#' @param code An R expression or a file path (character). When a bare
#'   expression is supplied, it is captured via NSE and deparsed. When a
#'   character string that points to an existing file is supplied, the
#'   file content is read and converted.
#' @param ... Additional arguments (must be empty).
#' @param reverse Logical. If `TRUE`, converts `\uXXXX` escape sequences back
#'   to readable Unicode characters. If `FALSE` (default), encodes non-ASCII
#'   characters to `\uXXXX` escapes.
#' @param overwrite Logical. Only used when `code` is a file path. If `TRUE`,
#'   overwrites the file with the converted content. Default is `NULL`, which
#'   prompts the user interactively.
#'
#' @return
#'   Invisibly returns the converted code as a character string.
#'   If `code` is a file path and `overwrite = TRUE`, the file is updated
#'   in place and the function returns the path invisibly.
#'
#' @examples
#' \donttest{
#' # Convert non-ASCII characters in a bare expression to \\u escapes
#' convert_nonascii_code(print('\u4e2d\u6587'))
#'
#' # Reverse: restore \\u escapes to readable characters
#' convert_nonascii_code(print('\u4e2d\u6587'), reverse = TRUE)
#' }
#'
#' @export
convert_nonascii_code <- function(
  code,
  ...,
  reverse = FALSE,
  overwrite = NULL
) {
  rlang::check_dots_empty()
  expr <- substitute(code)

  if (is.symbol(expr)) {
    # Variable: try to resolve to a file path, otherwise deparse the symbol
    val <- tryCatch(eval(expr, envir = parent.frame()), error = function(e) {
      NULL
    })
    if (is.character(val) && length(val) == 1 && file.exists(val)) {
      return(convert_nonascii_code_path(
        val,
        reverse = reverse,
        overwrite = overwrite
      ))
    }
    convert_nonascii_code_expr(expr, reverse = reverse)
  } else if (is.call(expr) || is.expression(expr) || is.pairlist(expr)) {
    convert_nonascii_code_expr(expr, reverse = reverse)
  } else if (is.character(code) && length(code) == 1 && file.exists(code)) {
    convert_nonascii_code_path(code, reverse = reverse, overwrite = overwrite)
  } else if (is.character(code) && length(code) == 1) {
    convert_nonascii_code_expr(expr, reverse = reverse)
  } else {
    cli::cli_abort(c(
      "x" = "Cannot handle input of type {.cls {class(code))}}"
    ))
  }
}

convert_nonascii_code_path <- function(
  path,
  reverse = FALSE,
  overwrite = NULL
) {
  if (!file.exists(path)) {
    cli::cli_abort(c("x" = "File {.path {path}} does not exist."))
  }

  lines <- readLines(path, warn = FALSE)
  code_str <- paste(lines, collapse = "\n")

  if (reverse) {
    converted <- restore_unicode_escapes(code_str)
  } else {
    converted <- encode_nonascii(code_str)
  }

  if (identical(converted, code_str)) {
    cli::cli_alert_warning(
      "No non-ASCII characters found (or no escapes to restore)."
    )
    return(invisible(code_str))
  }

  if (isTRUE(overwrite)) {
    writeLines(converted, con = path)
    cli::cli_alert_info("Converted content written to {.path {path}}")
    return(invisible(path))
  }

  if (isFALSE(overwrite)) {
    cli::cli_alert_warning(
      "Printing converted code to console (use overwrite = TRUE to write file):"
    )
    message(paste(converted, sep = "\n"))
    return(invisible(converted))
  }

  # overwrite is NULL — prompt user interactively
  if (rlang::is_interactive()) {
    msg <- cli::cli_fmt(cli::cli_text(
      "{cli::col_red(cli::symbol$checkbox_off)} \
      Overwrite file {.path {path}} with converted content?"
    ))
    ans <- utils::askYesNo(msg, default = FALSE)
    if (isTRUE(ans)) {
      writeLines(converted, con = path)
      cli::cli_alert_info("Converted content written to {.path {path}}")
      return(invisible(path))
    }
  }

  cli::cli_alert_info("Printing converted code to console:\n")
  message(paste(converted, sep = "\n"))
  invisible(converted)
}

#' @keywords internal
convert_nonascii_code_expr <- function(code, reverse = FALSE) {
  code_str <- rlang::expr_deparse(code)

  if (reverse) {
    converted <- restore_unicode_escapes(code_str)
  } else {
    converted <- encode_nonascii(code_str)
  }

  cli::cli_alert_info("Converted code (copy from console):\n")
  message(paste(converted, sep = "\n"))
  invisible(converted)
}

#' Encode Non-ASCII Characters to \\uXXXX Escape Sequences
#'
#' For each character in `x`, if its Unicode code point is outside the ASCII
#' range (0-127), it is replaced with a `\\uXXXX` escape. ASCII characters
#' are left unchanged.
#'
#' @param x A character string.
#' @return A character string with non-ASCII characters escaped.
#' @keywords internal
encode_nonascii <- function(x) {
  chars <- strsplit(x, NULL)[[1]]
  ints <- utf8ToInt(x)
  result <- vapply(
    seq_along(chars),
    function(i) {
      if (ints[i] > 127L) {
        sprintf("\\u%04x", ints[i])
      } else {
        chars[i]
      }
    },
    character(1)
  )
  paste(result, collapse = "")
}

#' Restore \\uXXXX Escape Sequences Back to Unicode Characters
#'
#' Matches patterns like `\\uXXXX` (where X is a hex digit) and replaces them
#' with the corresponding Unicode character.
#'
#' @param x A character string potentially containing `\\uXXXX` escapes.
#' @return A character string with escapes resolved.
#' @keywords internal
restore_unicode_escapes <- function(x) {
  m <- gregexpr("\\\\u[0-9a-fA-F]{4}", x, perl = TRUE)
  regmatches(x, m) <- lapply(regmatches(x, m), function(escapes) {
    vapply(
      escapes,
      function(e) {
        intToUtf8(strtoi(substr(e, 3L, 6L), 16L))
      },
      character(1),
      USE.NAMES = FALSE
    )
  })
  x
}

# nocov end
