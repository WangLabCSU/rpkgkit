#' Detect Unmatched `nocov` Markers
#'
#' @description
#' Check whether the `nocov start` and `nocov end` comment markers in \R source
#' files are consistent.
#'
#' Every marker is first located on its own line and column, and the markers are
#' then checked against the rules below.
#'
#' Detection is purely textual: every line is scanned for a marker comment, so a
#' marker that hides inside a string literal or inside a documentation comment
#' (a roxygen `#'` line) is reported as well. This is intentional -- such a
#' marker has no effect on coverage, which usually means it is a leftover that
#' should be removed by hand.
#'
#' @section Marker rules:
#' A file may contain at most one \code{nocov start} and at most one
#' \code{nocov end} marker, so the two counts must be equal: either both are
#' present or neither is.
#' \describe{
#'   \item{Second and later \code{nocov start}}{Reported as a problem: only the
#'   first start is meaningful, so every further start is echoed with its line
#'   and column.}
#'   \item{Second and later \code{nocov end}}{Reported as a problem for the same
#'   reason.}
#'   \item{\code{nocov start} without \code{nocov end}}{Reported as a problem:
#'   \code{covr::package_coverage()} aborts with a "range start but only range
#'   ends" error when a start is never closed, so a lone start must be fixed.}
#'   \item{\code{nocov end} without \code{nocov start}}{Reported as a problem:
#'   the block it closes does not exist.}
#'   \item{\code{nocov end} before \code{nocov start}}{Reported as a problem:
#'   the end must come after the start. Markers are compared by line first and
#'   then by column, so an end placed later on the same line is accepted.}
#' }
#'
#' @section Single file vs package scope:
#' \describe{
#'   \item{\code{detect_unmatched_nocov_marker()}}{Operates on one \R file. When
#'   \code{path} is \code{NULL} and RStudio is available, the currently active
#'   document path is used.}
#'   \item{\code{package_unmatched_nocov_marker()}}{Scans the \code{.R} files
#'   under the configured package-relative directories, by default \code{R/},
#'   and reports every problem together with its file name and line number.}
#' }
#'
#' @param path For \code{detect_unmatched_nocov_marker()}: path to an \R file.
#'   If \code{NULL} and RStudio is available, the active document path is used.
#'
#'   For \code{package_unmatched_nocov_marker()}: path to the root directory of
#'   an \R package. Defaults to the current directory.
#' @param dirs Character vector of package-relative directories scanned by
#'   \code{package_unmatched_nocov_marker()}. Defaults to \code{"R"}.
#' @param verbose Whether to emit detection results to the console.
#' @param ... Unused.
#'
#' @return Invisibly returns \code{TRUE} when the markers of the file follow the
#'   rules above, and \code{FALSE} otherwise. Each problem is printed with its
#'   line and column, the source line and a caret marker pointing at the
#'   offending comment, so that the fix is left to the user.
#'
#' @examples
#' \donttest{
#' file <- tempfile(fileext = ".R")
#' writeLines(c("f <- function() 1", paste0("# nocov", " end")), file)
#' detect_unmatched_nocov_marker(file)
#' }
#'
#' @name detect_unmatched_nocov_marker
NULL

#' @rdname detect_unmatched_nocov_marker
#' @export
detect_unmatched_nocov_marker <- function(path = NULL, verbose = TRUE, ...) {
  rlang::check_dots_empty()
  path <- path %||%
    if (rstudioapi::isAvailable()) rstudioapi::getActiveDocumentContext()$path
  if (is.null(path) || !nzchar(path)) {
    cli::cli_abort(c("x" = "{.arg path} is required"))
  }

  scan <- scan_nocov_file(path = path)

  if (length(scan$markers) == 0L) {
    if (verbose) {
      cli::cli_alert_success("No {.code nocov} markers found.")
    }
    return(invisible(TRUE))
  }

  if (length(scan$problems) > 0L) {
    if (verbose) {
      report_nocov_problems(scan = scan)
      problem_lines <- vapply(
        scan$problems,
        function(problem) scan$markers[[problem$index]]$line1,
        integer(1L)
      )
      cli::cli_alert_danger(
        "Found {length(problem_lines)} mismatched {.code nocov} marker{?s} on line{?s} {.val {problem_lines}}."
      )
    }
    return(invisible(FALSE))
  }

  if (verbose) {
    cli::cli_alert_success("All {.code nocov} markers are consistent.")
  }

  invisible(TRUE)
}


# ---------------------------------------------------------------------------
# Find all `nocov start` / `nocov end` comment markers in a character vector of
# source lines.
#
# Markers are matched textually, without parsing the file, so occurrences
# inside string literals and roxygen comments are collected as well (by
# design). Returns a list of markers, each with:
#   $line1 - line number of the marker
#   $col1  - first column of the marker
#   $col2  - last column of the marker
#   $type  - "start" or "end"
#   $text  - the matched text
# ---------------------------------------------------------------------------
find_nocov_markers <- function(lines) {
  dunm_find_markers_rs(lines)
}

# ---------------------------------------------------------------------------
# Check the markers found by `find_nocov_markers()` against the marker rules.
#
# Start and end markers are first split apart (each one already knows its line
# and column); the rules are then applied to those two sets:
#   - at most one `nocov start`  -> every start after the first is a problem
#   - at most one `nocov end`    -> every end after the first is a problem
#   - the two counts must match  -> a start with no end is a problem, because
#                                   covr aborts on an unclosed range
#   - an end needs a start, and must come after it (line first, then column)
#
# Returns $problems: a list of list(index, reason, reference), ordered by source
# position; `index` is the position in `markers` of the offending marker,
# `reason` is one of "duplicate_start", "duplicate_end", "unmatched_start",
# "unmatched_end" or "end_before_start", and `reference` is the marker the
# problem refers to (NA when there is none).
# ---------------------------------------------------------------------------
check_nocov_markers <- function(markers) {
  list(problems = dunm_check_markers_rs(markers))
}


# ---------------------------------------------------------------------------
# Read a file and collect its markers together with the check result.
#
# Returns a list with $lines, $markers and $problems.
# ---------------------------------------------------------------------------
scan_nocov_file <- function(path) {
  lines <- readLines(con = path, warn = FALSE)
  markers <- find_nocov_markers(lines = lines)
  check <- if (length(markers) > 0L) {
    check_nocov_markers(markers = markers)
  } else {
    list(problems = list())
  }

  list(
    lines = lines,
    markers = markers,
    problems = check$problems
  )
}

# ---------------------------------------------------------------------------
# Describe a single problem in a brace-free string (cli would otherwise try to
# evaluate `{...}` inside a message built at run time).
# ---------------------------------------------------------------------------
nocov_problem_text <- function(markers, problem) {
  if (!is.null(problem$text)) {
    return(problem$text)
  }

  marker <- markers[[problem$index]]
  at <- paste0(
    "`",
    if (identical(marker$type, "start")) "nocov start" else "nocov end",
    "` at line ",
    marker$line1,
    ", column ",
    marker$col1
  )

  if (identical(problem$reason, "unmatched_end")) {
    return(paste0(at, " has no matching `nocov start`."))
  }

  if (identical(problem$reason, "unmatched_start")) {
    return(paste0(at, " has no matching `nocov end`."))
  }

  reference <- markers[[problem$reference]]
  reference_at <- paste0(
    "`",
    if (identical(reference$type, "start")) "nocov start" else "nocov end",
    "` at line ",
    reference$line1,
    ", column ",
    reference$col1
  )

  switch(
    problem$reason,
    duplicate_start = paste0(
      at,
      ": only one `nocov start` is allowed per file, the first is ",
      reference_at,
      "."
    ),
    duplicate_end = paste0(
      at,
      ": only one `nocov end` is allowed per file, the first is ",
      reference_at,
      "."
    ),
    end_before_start = paste0(at, " comes before ", reference_at, ".")
  )
}

# ---------------------------------------------------------------------------
# Format a position hint for a marker: the source line followed by a caret line
# whose `^` characters underline the marker, in the same style as
# `format_brace_error()`.
# ---------------------------------------------------------------------------
format_nocov_marker_error <- function(line_content, marker) {
  dunm_format_marker_error_rs(
    line_content = line_content,
    col1 = as.integer(marker$col1),
    col2 = as.integer(marker$col2)
  )
}

# ---------------------------------------------------------------------------
# Print every problem of a scan, optionally prefixed with a file label (used by
# `package_unmatched_nocov_marker()`).
# ---------------------------------------------------------------------------
report_nocov_problems <- function(scan, label = NULL) {
  for (problem in scan$problems) {
    marker <- scan$markers[[problem$index]]
    if (!is.null(label)) {
      cli::cli_text("{.file {label}}: {.val {marker$line1}}:")
    }
    cli::cli_alert_danger(nocov_problem_text(scan$markers, problem))
    message(format_nocov_marker_error(scan$lines[[marker$line1]], marker))
  }
  invisible(NULL)
}
