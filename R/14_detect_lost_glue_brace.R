#' Detect Lost Glue Brace in `glue` and `cli` Expressions
#'
#' @description
#' Check whether `{` and `}` are balanced in all `glue::glue()` / `glue_data()`
#' and `cli::cli_*()` string arguments within an R file. Lines containing these
#' function calls are scanned for quoted strings; if the number of opening braces
#' does not equal the number of closing braces in any string, the line is reported
#' as an error.
#'
#' @param path A character string specifying the path to the R file to inspect.
#'   If `NULL` and RStudio is available, the currently active document path is used.
#'
#' @return Invisibly returns `TRUE` if all expressions are balanced, `FALSE`
#'   otherwise. Side-effect messages are emitted via [cli].
#'
#' @examples
#' \dontrun{
#' detect_lost_glue_brace("path/to/file.R")
#' }
#'
#' @export
detect_lost_glue_brace <- function(path = NULL) {
  path <- if (is.null(path) && rlang::is_installed("rstudioapi")) {
    rstudioapi::getActiveDocumentContext()$path
  } else if (is.null(path)) {
    cli::cli_abort(
      c("x" = "{.arg path} is required when not in RStudio.")
    )
  } else {
    path
  }

  lines <- readLines(path, warn = FALSE)

  # Match lines that contain glue::glue(, glue_data(, or cli::cli_*(
  pattern <- "(glue::glue\\s*\\(|glue_data\\s*\\(|cli::cli_[a-zA-Z_]+\\s*\\()"

  error_lines <- integer()

  for (i in seq_along(lines)) {
    line <- lines[i]

    if (!grepl(pattern, line, perl = TRUE)) {
      next
    }

    # Extract all double-quoted strings: "(?:[^"\\]|\\.)*"
    dq <- gregexpr('"(?:[^"\\\\]|\\\\.)*"', line, perl = TRUE)
    dq_strs <- regmatches(line, dq)[[1]]

    # Extract all single-quoted strings: '(?:[^'\\]|\\.)*'
    sq <- gregexpr("'(?:[^'\\\\]|\\\\.)*'", line, perl = TRUE)
    sq_strs <- regmatches(line, sq)[[1]]

    all_strs <- c(dq_strs, sq_strs)

    for (s in all_strs) {
      # Strip surrounding quotes
      s_content <- substr(s, 2L, nchar(s) - 1L)

      open_count <- lengths(regmatches(
        s_content,
        gregexpr("\\{", s_content, perl = TRUE)
      ))
      close_count <- lengths(regmatches(
        s_content,
        gregexpr("\\}", s_content, perl = TRUE)
      ))

      if (open_count != close_count) {
        error_lines <- c(error_lines, i)
        break
      }
    }
  }

  if (length(error_lines) == 0L) {
    cli::cli_alert_success("No need to fix")
    invisible(TRUE)
  } else {
    cli::cli_alert_danger(
      "Found {length(error_lines)} line{?s} with mismatched braces: {.val {error_lines}}"
    )
    invisible(FALSE)
  }
}
