#' Detect Default Paths in Exported Function Arguments
#'
#' @description
#' CRAN does not allow exported functions to default a path-like argument to a
#' concrete location. This checker parses R source, finds exported functions,
#' and reports every argument whose name matches `arg_pattern` and whose
#' default value is not in `allow` (by default only `NULL`; an argument with
#' no default is always fine). Each hit is reported with file, line, column and
#' a caret (`^^^^`) marker under `arg = default`.
#'
#' @section Single file vs package scope:
#' \describe{
#'   \item{\code{detect_fn_arg_path()}}{Operates on one \R file. Use
#'   \code{exports} / \code{export_patterns} to say which top-level functions
#'   count as exported; when \code{exports} is \code{NULL} and no patterns are
#'   given, every top-level function in the file is checked.}
#'   \item{\code{package_fn_arg_path()}}{Checks that \code{path} is an \R
#'   package, reads exports from \code{NAMESPACE}, then scans \code{.R} files
#'   under \code{dirs} (default \code{"R"}).}
#' }
#'
#' @param path For \code{detect_fn_arg_path()}: path to an \R file. If
#'   \code{NULL} and RStudio is available, the active document is used.
#'
#'   For \code{package_fn_arg_path()}: root directory of an \R package.
#'   Defaults to the current directory.
#' @param arg_pattern Regular expression matched (unanchored) against argument
#'   names. Use e.g. `"^(path|file|filename)$"` to avoid matching `profile`.
#' @param exports Character vector of exported function names.
#' @param export_patterns Character vector of regular expressions, as in
#'   `exportPattern()` in `NAMESPACE`.
#' @param allow Character vector of default-value expressions (as written in
#'   the source, whitespace trimmed) that are acceptable.
#'   Defaults to `"NULL"`.
#' @param dirs Package-relative directories scanned by
#'   \code{package_fn_arg_path()}.
#' @param verbose Whether to emit results to the console.
#' @param ... Unused.
#'
#' @return Invisibly returns \code{TRUE} if no offending defaults are found,
#' \code{FALSE} otherwise.
#'
#' @examples
#' \donttest{
#' file <- tempfile(fileext = ".R")
#' writeLines('read_it <- function(path = "~/data.csv", n = 1) NULL', file)
#' detect_fn_arg_path(file)
#' }
#'
#' @name detect_fn_arg_path
NULL

#' @rdname detect_fn_arg_path
#' @export
detect_fn_arg_path <- function(
  path = NULL,
  arg_pattern = "path|file|filename",
  exports = NULL,
  export_patterns = character(),
  allow = "NULL",
  verbose = TRUE,
  ...
) {
  rlang::check_dots_empty()
  path <- path %||%
    if (rstudioapi::isAvailable()) rstudioapi::getActiveDocumentContext()$path
  if (is.null(path) || !nzchar(path)) {
    cli::cli_abort(c("x" = "{.arg path} is required"))
  }

  scanned <- scan_fn_arg_path(
    file = path,
    arg_pattern = arg_pattern,
    exports = exports,
    export_patterns = export_patterns,
    allow = allow
  )

  if (length(scanned$hits) == 0L) {
    if (verbose) {
      cli::cli_alert_success("No need to fix")
    }
    return(invisible(TRUE))
  }

  if (verbose) {
    report_fn_arg_hits(path, scanned$lines, scanned$hits)
    n_hits <- length(scanned$hits)
    cli::cli_alert_danger(
      "Found {n_hits} argument{?s} with a default path in {.path {path}}"
    )
  }
  invisible(FALSE)
}

# ---------------------------------------------------------------------------
# Scan one file; return source lines and a list of hits
#
# A "hit" is a formal argument of a top-level `name <- function(...)` whose
#   * function is exported (or all functions, when no export info is given),
#   * name matches `arg_pattern`,
#   * has a default value that is not listed in `allow`.
# ---------------------------------------------------------------------------
scan_fn_arg_path <- function(
  file,
  arg_pattern,
  exports = NULL,
  export_patterns = character(),
  allow = "NULL"
) {
  if (!file.exists(file)) {
    cli::cli_abort("File {.path {file}} does not exist.")
  }
  lines <- readLines(file, warn = FALSE)
  text <- paste(lines, collapse = "\n")

  # keep the original guard: unparseable files must still be reported
  parse_safely(text, file)

  hits <- dfap_scan_text_rs(
    text = text,
    arg_pattern = arg_pattern,
    exports = exports,
    export_patterns = export_patterns,
    allow = allow
  )

  list(lines = lines, hits = hits)
}

# ---------------------------------------------------------------------------
# Print hits, e.g.
#
#   R/read.R:3:15  read_it(): `path` defaults to "~/data.csv"
#   read_it <- function(path = "~/data.csv", n = 1) {
#                       ^^^^^^^^^^^^^^^^^^^
#
# The code line(s) and the caret marker are printed with `cli_verbatim()`, so
# they keep their line breaks and are never re-wrapped by cli's text formatter.
# The source is highlighted as a whole file, because `cli::code_highlight()`
# needs complete, parseable code: a single line is usually not parseable (a
# continuation such as `  x = fn(a, b),` ends with a comma) and on a parse
# failure `code_highlight()` silently returns its input unchanged, i.e. without
# any highlighting. It must also be fed one element per line: with a single
# string containing `\n` only the first line would be highlighted.
# ---------------------------------------------------------------------------
report_fn_arg_hits <- function(file, lines, hits, root = NULL) {
  shown <- if (is.null(root)) {
    file
  } else {
    sub(
      paste0("^", gsub("([.\\\\|()\\[{^$*+?])", "\\\\\\1", root), "/?"),
      "",
      file
    )
  }

  hl_lines <- tryCatch(
    cli::code_highlight(
      lines,
      code_theme = getOption("rpkgkit.code.highlight")
    ),
    error = function(e) lines,
    cli_parse_failure = function(cnd) lines
  )
  if (length(hl_lines) != length(lines)) {
    hl_lines <- lines
  }

  for (h in hits) {
    line_content <- lines[h$line1]
    end_col <- if (h$line2 == h$line1) h$col2 else nchar(line_content)
    caret <- paste0(
      strrep(" ", h$col1 - 1L),
      strrep("^", max(end_col - h$col1 + 1L, 1L))
    )
    cli::cli_text(
      "{.path {shown}}",
      ":",
      h$line1,
      ":",
      h$col1,
      "  ",
      "{.strong {h$fn}}",
      "(): `",
      "{.field {h$arg}}",
      "` defaults to ",
      cli::col_grey(h$default)
    )
    shown_lines <- seq.int(h$line1, max(h$line2, h$line1))
    for (i in shown_lines) {
      code_line <- if (i <= length(hl_lines)) hl_lines[i] else lines[i]
      cli::cli_verbatim(code_line)
    }
    cli::cli_verbatim(cli::col_grey(caret))
  }
  invisible(NULL)
}
