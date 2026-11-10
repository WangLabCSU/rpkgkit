#' Detect Lost Glue Brace in `glue` and `cli` Expressions
#'
#' @description
#' Check whether `{` and `}` are balanced in all `glue()` / `glue_data()`
#' and `cli_*()` string arguments within R source files. Each file is scanned
#' by a Rust tokenizer that understands strings, comments and raw strings, then
#' every string literal passed to a target function is checked with a
#' stack-based brace matcher. Any mismatch is reported with its line number and
#' a visual caret (`^^^^`) marker under the problematic region.
#'
#' @section Single file vs package scope:
#' \describe{
#'   \item{\code{detect_lost_glue_brace()}}{Operates on one \R file. When
#'   \code{path} is \code{NULL} and RStudio is available, the currently active
#'   document path is used.}
#'   \item{\code{package_lost_glue_brace()}}{Scans \code{.R} files under the
#'   configured package-relative directories. By default, these are \code{R/}
#'   and \code{tests/testthat/}.}
#' }
#'
#' @param path For \code{detect_lost_glue_brace()}: path to an \R file. If
#'   \code{NULL} and RStudio is available, the active document path is used.
#'
#'   For \code{package_lost_glue_brace()}: path to the root directory of an
#'   \R package. Defaults to the current directory.
#' @param dirs Character vector of package-relative directories scanned by
#'   \code{package_lost_glue_brace()}. Defaults to \code{"R"} and
#'   \code{"tests/testthat"}.
#' @param test_included `r lifecycle::badge('deprecated')`. Logical indicating whether to scan
#'   \code{tests/testthat/} in addition to \code{R/}. Use \code{dirs} instead.
#'   When supplied, \code{FALSE} scans only \code{R/}; \code{TRUE} scans both
#'   default directories.
#' @param verbose Whether to emit detection results to the console. Package
#'   scanning disables this and supplies its own progress and summary output.
#' @param ... Unused.
#'
#' @return Invisibly returns \code{TRUE} if all expressions are balanced,
#' \code{FALSE} otherwise.
#'
#' @examples
#' \donttest{
#' file <- tempfile(fileext = ".R")
#' writeLines('glue("{a")', file)
#' detect_lost_glue_brace(file)
#' }
#'
#' @name detect_lost_glue_brace
NULL

#' @rdname detect_lost_glue_brace
#' @export
detect_lost_glue_brace <- function(path = NULL, verbose = TRUE, ...) {
  rlang::check_dots_empty()
  path <- path %||%
    if (rstudioapi::isAvailable()) rstudioapi::getActiveDocumentContext()$path
  if (is.null(path) || !nzchar(path)) {
    cli::cli_abort(c("x" = "{.arg path} is required"))
  }
  lines <- readLines(path, warn = FALSE)
  text <- paste(lines, collapse = "\n")
  parse_safely(text, path)

  strings_info <- find_glue_cli_strings(text)

  if (length(strings_info) == 0L) {
    if (verbose) {
      cli::cli_alert_success("No need to fix")
    }
    return(invisible(TRUE))
  }

  # highlight the whole file: a single source line is usually not parseable, and
  # `cli::code_highlight()` silently returns unparseable input unchanged. It must
  # also get one element per line, otherwise only the first line is highlighted.
  hl_lines <- tryCatch(
    cli::code_highlight(lines),
    error = function(e) lines,
    cli_parse_failure = function(cnd) lines
  )
  if (length(hl_lines) != length(lines)) {
    hl_lines <- lines
  }

  error_lines <- integer()

  # highlight the whole file: a single source line is usually not parseable, and
  # `cli::code_highlight()` silently returns unparseable input unchanged. It must
  # also get one element per line, otherwise only the first line is highlighted.
  hl_lines <- tryCatch(
    cli::code_highlight(lines),
    error = function(e) lines,
    cli_parse_failure = function(cnd) lines
  )
  if (length(hl_lines) != length(lines)) {
    hl_lines <- lines
  }

  for (info in strings_info) {
    result <- check_brace_balance(info$content)

    if (!result$balanced) {
      error_lines <- c(error_lines, info$line1)

      if (verbose) {
        message(
          format_brace_error(
            line_content = hl_lines[info$line1],
            str_content = info$content,
            line_num = info$line1,
            col_offset = info$col1,
            result = result
          )
        )
      }
    }
  }

  if (length(error_lines) == 0L) {
    if (verbose) {
      cli::cli_alert_success("No need to fix")
    }
    invisible(TRUE)
  } else {
    if (verbose) {
      cli::cli_alert_danger(
        "Found {length(error_lines)} line{?s} with mismatched braces: {.val {error_lines}}"
      )
    }
    invisible(FALSE)
  }
}


# ---------------------------------------------------------------------------
# Helper: parse source text safely
#
# This is the only remaining R-side guard: it keeps the previous behaviour of
# reporting unparseable files instead of silently scanning them. The actual
# inspection of glue/cli strings is done in Rust.
# ---------------------------------------------------------------------------
parse_safely <- function(text, path) {
  tryCatch(
    parse(text = text, keep.source = TRUE),
    error = function(e) {
      cli::cli_abort(c(
        "x" = "Could not parse {.path {path}}.)",
        "i" = "{e$message}"
      ))
    }
  )
}

# ---------------------------------------------------------------------------
# Helper: find all string literals inside glue / cli function calls
#
# `text` is the full source text (or a character vector of lines). The Rust
# tokenizer walks the source once, tracks the call stack, and returns every
# string literal whose enclosing call chain contains a target function.
# ---------------------------------------------------------------------------
find_glue_cli_strings <- function(text) {
  dlgb_find_glue_strings_rs(paste(text, collapse = "\n"))
}

# ---------------------------------------------------------------------------
# Helper: check brace balance with a stack-based scan (implemented in Rust)
# ---------------------------------------------------------------------------
check_brace_balance <- function(s) {
  dlgb_check_brace_balance_rs(s)
}

# ---------------------------------------------------------------------------
# Helper: nearest `{` before a position (implemented in Rust)
# ---------------------------------------------------------------------------
find_nearest_open_before <- function(s, pos) {
  out <- dlgb_find_nearest_open_before_rs(s, as.integer(pos))
  if (out < 0L) NA_integer_ else out
}

# ---------------------------------------------------------------------------
# Helper: format a visual error message for a brace mismatch
#
# Produces output like:
#
#   "Hello, {name!"
#           ^^^^^^
#
# The top line is the original source line (already highlighted by the caller),
# the second line has `^` markers aligned under the problematic region.
# ---------------------------------------------------------------------------
format_brace_error <- function(
  line_content,
  str_content,
  line_num,
  col_offset,
  result
) {
  dlgb_format_brace_error_rs(
    line_content = line_content,
    hl_start = as.integer(result$hl_start),
    hl_end = as.integer(result$hl_end),
    col_offset = as.integer(col_offset)
  )
}
