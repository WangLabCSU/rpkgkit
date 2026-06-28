#' Detect `print()` and `cat()` Calls (CRAN-Unsafe)
#'
#' @description
#' Check whether \R source files contain direct calls to `print()` or `cat()`,
#' which are generally not permitted by CRAN policies. Output should use
#' \code{\link[base]{message}} instead.
#'
#' These functions parse \R source code into an AST and identify every
#' \code{SYMBOL_FUNCTION_CALL} token whose text is \code{"print"} or
#' \code{"cat"}. Each match is reported with the line number, the full source
#' line, and a caret marker pointing at the offending call.
#'
#' When \code{fix = TRUE}, the function performs a simple text replacement of
#' \code{print(} and \code{cat(} with \code{message(} on the affected lines.
#' The replacement uses word-boundary matching to avoid false positives inside
#' other identifiers (e.g. \code{sprintf} or \code{print.myclass}).
#'
#' @section Single file vs package scope:
#' \describe{
#'   \item{\code{detect_print_and_cat()}}{Operates on one \R file. When \code{path}
#'   is \code{NULL} and RStudio is available, the currently active document is
#'   used automatically.}
#'   \item{\code{package_print_and_cat()}}{Scans all \code{.R} files in a
#'   package's \code{R/} directory, plus \code{tests/testthat/} when
#'   \code{test_included = TRUE}. Results are aggregated into a single report
#'   showing per-file summaries.}
#' }
#'
#' @param path For \code{detect_print_and_cat()}: path to an \R file. If
#'   \code{NULL} and RStudio is available, the active document path is used.
#'
#'   For \code{package_print_and_cat()}: path to the root directory of an
#'   \R package. If \code{NULL}, the function walks up from the active document
#'   to find the package root.
#' @param fix Logical. If \code{TRUE}, replace \code{print(}/\code{cat(} with
#'   \code{message(} directly in the source file(s). Default is \code{FALSE}.
#' @param test_included Logical, used only by
#'   \code{package_print_and_cat()}. If \code{TRUE} (the default), \code{.R}
#'   files under \code{tests/testthat/} are also scanned.
#' @param ... Additional arguments passed to utils::methods (currently unused).
#'
#' @return Invisibly returns \code{TRUE} if no calls were found, \code{FALSE}
#'   otherwise. Side-effect messages and caret markers are emitted via
#'   \pkg{cli} and \code{\link[base]{message}}.
#'
#' @examples
#' \donttest{
#' # --- Single file ---
#' tmp <- tempfile(fileext = ".R")
#' writeLines('print("hello")', tmp)
#' detect_print_and_cat(tmp)
#'
#' # --- With auto-fix ---
#' detect_print_and_cat(tmp, fix = TRUE)
#'
#' # --- Entire package ---
#' pkg <- tempfile()
#' dir.create(file.path(pkg, "R"), recursive = TRUE)
#' writeLines('cat("debug\\n")', file.path(pkg, "R", "example.R"))
#' writeLines(c("Package: example", "Version: 0.0.1"),
#'            file.path(pkg, "DESCRIPTION"))
#' package_print_and_cat(pkg)
#' }
#'
#' @name detect_print_and_cat
NULL

#' @rdname detect_print_and_cat
#' @export
detect_print_and_cat <- function(path = NULL, fix = FALSE, ...) {
  path <- path %||% rstudioapi::getActiveDocumentContext()$path
  lines <- readLines(con = path, warn = FALSE)
  text <- paste(lines, collapse = "\n")
  exprs <- parse_safely(text = text, path = path)
  parse_data <- utils::getParseData(exprs)
  calls_info <- find_print_cat_calls(parse_data = parse_data)
  if (length(calls_info) == 0L) {
    cli::cli_alert_success("No {.fn print} or {.fn cat} calls found.")
    return(invisible(TRUE))
  }
  if (fix) {
    original_lines <- lines
    call_entries <- Filter(f = function(x) x$type == "call", x = calls_info)
    if (length(call_entries) > 0L) {
      lines_to_fix <- unique(
        x = vapply(
          X = call_entries,
          FUN = `[[`,
          FUN.VALUE = integer(length = 1L),
          "line1"
        )
      )
      for (l in lines_to_fix) {
        lines[l] <- gsub(
          pattern = "\\b(print|cat)\\(",
          replacement = "message(",
          x = lines[l]
        )
      }
      writeLines(text = lines, con = path)
      cli::cli_alert_success(
        "Fixed {length(lines_to_fix)} line{?s} in {.path {basename(path)}}."
      )
    }
  }
  report_lines <- if (fix) {
    original_lines
  } else {
    lines
  }
  for (info in calls_info) {
    caret_width <- nchar(x = info$text) +
      if (info$type == "call") {
        1L
      } else {
        0L
      }
    caret <- paste0(
      strrep(x = " ", times = info$col1 - 1L),
      strrep(x = "^", times = caret_width)
    )
    message(paste0(report_lines[info$line1], "\n", caret))
  }
  reported_lines <- unique(
    x = vapply(
      X = calls_info,
      FUN = `[[`,
      FUN.VALUE = integer(length = 1L),
      "line1"
    )
  )
  cli::cli_alert_danger(
    "Found {length(calls_info)} unsupported call{?s} on line{?s} \n     {.val {reported_lines}}."
  )
  invisible(FALSE)
}


# ---------------------------------------------------------------------------
# Find all SYMBOL_FUNCTION_CALL tokens whose text is "print" or "cat"
# ---------------------------------------------------------------------------
find_print_cat_calls <- function(parse_data) {
  direct_calls <- parse_data[
    parse_data$token == "SYMBOL_FUNCTION_CALL" &
      parse_data$text %in% c("print", "cat"),
  ]
  func_refs <- parse_data[
    parse_data$token == "SYMBOL" & parse_data$text %in% c("print", "cat"),
  ]
  calls_list <- list()
  for (i in seq_len(nrow(x = direct_calls))) {
    calls_list <- c(
      calls_list,
      list(list(
        line1 = direct_calls$line1[i],
        col1 = direct_calls$col1[i],
        text = direct_calls$text[i],
        type = "call"
      ))
    )
  }
  for (i in seq_len(nrow(x = func_refs))) {
    calls_list <- c(
      calls_list,
      list(list(
        line1 = func_refs$line1[i],
        col1 = func_refs$col1[i],
        text = func_refs$text[i],
        type = "ref"
      ))
    )
  }
  calls_list
}
