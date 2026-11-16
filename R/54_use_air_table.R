#' Format Long Vectors and Lists as Aligned Tables with Air
#'
#' @description
#' Air (\eqn{\geq} 0.8.0) can align the elements of a call column by column,
#' giving the same layout as \code{tibble::tribble()} or
#' \code{data.table::fcase()}. The feature is switched on by the experimental
#' \code{# fmt: table} comment directive placed right above the call, but air
#' never re-flows the elements on its own: whatever sits on one source line
#' stays there.
#'
#' [use_air_table()] does the two things air does not do by itself:
#'
#' 1. runs \code{air format} on \code{path}, so every long vector and list is
#'    laid out with one element per line;
#' 2. inserts the directive above every \code{c()} / \code{list()} call that
#'    has more than \code{min_length} elements, and re-flows the elements so
#'    that each row holds \code{ncol} of them. Multi-line definitions are
#'    collapsed by deleting the line breaks between the elements of a row;
#'    a definition that air kept on a single line is split into rows instead.
#'
#' A second \code{air format} run then pads the cells and aligns the columns.
#'
#' @param path Path to an R file to modify. If \code{NULL} and RStudio is
#'   available, the path of the active document is used.
#' @param ncol Number of elements placed on each table row.
#' @param min_length A vector or list is only converted when it has strictly
#'   more than this many elements.
#' @param marker The comment directive that enables table formatting in air.
#' @param ... Additional arguments. Currently unused and must be empty.
#'
#' @return Invisibly returns the normalized \code{path}.
#'
#' @details
#' Requirements and scope:
#'
#' - \code{air} must be installed and on the \code{PATH} (see
#'   [check_air_installed()]), and the directive requires air 0.8.0 or newer.
#' - Only calls whose elements are **all unnamed** are rewritten. Air expands
#'   named elements (\code{list(a = 1)}) one per line no matter what the
#'   directive says, so named calls are skipped to avoid a marker that has no
#'   effect.
#' - Calls that already carry \code{marker} on the preceding line are left
#'   untouched, so the function is idempotent.
#' - Air only honours the directive on the outermost call of a statement, so a
#'   vector or list nested inside another call (for example an argument of
#'   \code{x <- list(a = c(...))}) is skipped.
#'
#' @examples
#' \dontrun{
#' tf <- tempfile(fileext = ".R")
#' writeLines(
#'   'x <- c("alpha", "beta", "gamma", "delta", "epsilon", "zeta", "eta", "theta")',
#'   tf
#' )
#' use_air_table(tf, ncol = 3L, min_length = 6L)
#' readLines(tf) |> cli::cli_code()
#' }
#'
#' @export
use_air_table <- function(
  path = NULL,
  ncol = 3L,
  min_length = 12L,
  marker = "# fmt: table",
  ...
) {
  rlang::check_dots_empty()
  # rpkgkit: not int
  rlang::check_number_whole(ncol, min = 1)
  # rpkgkit: not int
  rlang::check_number_whole(min_length, min = 0)
  rlang::check_string(marker)
  check_air_installed()

  path <- path %||%
    if (rstudioapi::isAvailable()) rstudioapi::getActiveDocumentContext()$path
  if (is.null(path) || !nzchar(path)) {
    cli::cli_abort(c("x" = "{.arg path} is required"))
  }
  if (!file.exists(path)) {
    cli::cli_abort(c("x" = "{.file {path}} does not exist."))
  }
  path <- normalizePath(path = path, mustWork = TRUE)

  # Fail fast with a readable message instead of air's verbose diagnostics.
  .uat_parse(
    lines = readLines(con = path, warn = FALSE),
    path = path
  )
  .uat_run_air(path = path)

  lines <- readLines(con = path, warn = FALSE)
  targets <- .uat_targets(
    lines = lines,
    path = path,
    min_length = min_length,
    marker = marker
  )
  if (nrow(targets) == 0L) {
    cli::cli_alert_info(
      "No vector or list with more than {min_length} element{?s} found in {.file {path}}."
    )
    return(invisible(path))
  }

  new_lines <- .uat_collapse(
    lines = lines,
    targets = targets,
    ncol = ncol,
    marker = marker
  )
  writeLines(text = new_lines, con = path)

  .uat_run_air(path = path)

  cli::cli_alert_success(
    "Converted {nrow(targets)} vector{?s}/list{?s} to {ncol}-column table{?s} in {.file {path}}."
  )

  invisible(path)
}


#' Internal: run `air format` and abort on failure
#'
#' @param path Path to the file to format.
#'
#' @return Invisibly returns `path`.
#'
#' @keywords internal
.uat_run_air <- function(path) {
  out <- suppressWarnings(
    system2(
      command = "air",
      args = c("format", shQuote(path)),
      stdout = TRUE,
      stderr = TRUE
    )
  )
  status <- attr(out, "status") %||% 0L
  if (!identical(as.integer(status), 0L)) {
    details <- utils::head(out[nzchar(out)], 5L)
    cli::cli_abort(c(
      "x" = "{.pkg air} failed to format {.file {path}}.",
      "i" = "{paste(details, collapse = '\n')}"
    ))
  }

  invisible(path)
}


#' Internal: parse a file, aborting on invalid R code
#'
#' @param lines Character vector of the file contents.
#' @param path Path of the file, used in the error message.
#'
#' @return The parsed expressions.
#'
#' @keywords internal
.uat_parse <- function(lines, path) {
  tryCatch(
    suppressWarnings(
      parse(text = paste(lines, collapse = "\n"), keep.source = TRUE)
    ),
    error = function(e) {
      cli::cli_abort(c(
        "x" = "{.file {path}} is not valid R code.",
        "i" = "{conditionMessage(e)}"
      ))
    }
  )
}


#' Internal: locate long vector and list definitions
#'
#' @param lines Character vector of the file contents.
#' @param path Path of the file, used in error messages.
#' @param min_length Minimum number of elements (exclusive).
#' @param marker The air table directive.
#'
#' @return A data frame with one row per target and the list-column
#'   `elements` (position of every element), or an empty data frame with the
#'   same columns when nothing qualifies.
#'
#' @keywords internal
.uat_targets <- function(lines, path, min_length, marker) {
  # keep the original guard: unparseable files must still be reported
  .uat_parse(lines = lines, path = path)

  raw <- uat_find_targets_rs(
    text = paste(lines, collapse = "\n"),
    min_length = as.integer(min_length),
    marker = marker
  )
  .uat_targets_from_rust(raw)
}

# Adapt between the compact list shape returned by Rust and the data frame /
# list-column shape the rest of the package (and its tests) expect.
.uat_targets_from_rust <- function(raw) {
  if (length(raw) == 0L) {
    empty <- data.frame(
      line1 = integer(),
      line2 = integer(),
      col1 = integer(),
      n = integer(),
      multiline = logical(),
      stringsAsFactors = FALSE
    )
    empty$elements <- list()
    return(empty)
  }

  out <- data.frame(
    line1 = vapply(raw, `[[`, integer(1L), "line1"),
    line2 = vapply(raw, `[[`, integer(1L), "line2"),
    col1 = vapply(raw, `[[`, integer(1L), "col1"),
    n = vapply(raw, `[[`, integer(1L), "n"),
    multiline = vapply(raw, `[[`, logical(1L), "multiline"),
    stringsAsFactors = FALSE
  )
  out$elements <- lapply(
    raw,
    function(target) .uat_elements_from_rust(target$elements)
  )
  out
}

.uat_elements_from_rust <- function(elements) {
  data.frame(
    line1 = vapply(elements, `[`, integer(1L), 1L),
    col1 = vapply(elements, `[`, integer(1L), 2L),
    line2 = vapply(elements, `[`, integer(1L), 3L),
    col2 = vapply(elements, `[`, integer(1L), 4L)
  )
}

.uat_elements_for_rust <- function(elements) {
  if (!is.data.frame(elements)) {
    return(elements)
  }
  lapply(seq_len(nrow(elements)), function(i) {
    as.integer(c(
      elements$line1[[i]],
      elements$col1[[i]],
      elements$line2[[i]],
      elements$col2[[i]]
    ))
  })
}

.uat_targets_for_rust <- function(targets) {
  lapply(seq_len(nrow(targets)), function(i) {
    list(
      line1 = as.integer(targets$line1[[i]]),
      line2 = as.integer(targets$line2[[i]]),
      col1 = as.integer(targets$col1[[i]]),
      n = as.integer(targets$n[[i]]),
      multiline = isTRUE(targets$multiline[[i]]),
      elements = .uat_elements_for_rust(targets$elements[[i]])
    )
  })
}

.uat_collapse <- function(lines, targets, ncol, marker) {
  uat_collapse_rs(
    lines = lines,
    targets = .uat_targets_for_rust(targets),
    ncol = as.integer(ncol),
    marker = marker
  )
}

.uat_rows <- function(n, ncol) {
  uat_rows_rs(as.integer(n), as.integer(ncol))
}
