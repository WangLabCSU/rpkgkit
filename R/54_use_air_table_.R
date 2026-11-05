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
  rlang::check_number_whole(ncol, min = 1)
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
  .at_parse(
    lines = readLines(con = path, warn = FALSE),
    path = path
  )
  .at_run_air(path = path)

  lines <- readLines(con = path, warn = FALSE)
  targets <- .at_targets(
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

  new_lines <- .at_collapse(
    lines = lines,
    targets = targets,
    ncol = ncol,
    marker = marker
  )
  writeLines(text = new_lines, con = path)

  .at_run_air(path = path)

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
.at_run_air <- function(path) {
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
.at_parse <- function(lines, path) {
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
.at_targets <- function(lines, path, min_length, marker) {
  empty <- data.frame(
    line1 = integer(),
    line2 = integer(),
    col1 = integer(),
    n = integer(),
    multiline = logical(),
    stringsAsFactors = FALSE
  )
  empty$elements <- list()

  exprs <- .at_parse(lines = lines, path = path)
  if (length(exprs) == 0L) {
    return(empty)
  }
  pd <- utils::getParseData(exprs)
  if (is.null(pd) || nrow(pd) == 0L) {
    return(empty)
  }

  fn_syms <- pd[
    pd$token == "SYMBOL_FUNCTION_CALL" & pd$text %in% c("c", "list"),
    ,
    drop = FALSE
  ]
  if (nrow(fn_syms) == 0L) {
    return(empty)
  }

  call_ids <- .at_call_ids(pd)
  found <- vector("list", nrow(fn_syms))
  for (i in seq_len(nrow(fn_syms))) {
    info <- .at_call_info(
      pd = pd,
      sym_id = fn_syms$id[[i]],
      call_ids = call_ids,
      min_length = min_length
    )
    if (is.null(info)) {
      next
    }
    line <- info$line1
    if (line > 1L && identical(trimws(lines[line - 1L]), marker)) {
      next
    }
    found[[i]] <- info
  }
  found <- found[!vapply(found, is.null, logical(1L))]
  if (length(found) == 0L) {
    return(empty)
  }

  # Keep the outermost call of nested candidates, and keep source order.
  found <- found[order(
    vapply(found, `[[`, integer(1L), "line1"),
    vapply(found, `[[`, integer(1L), "col1")
  )]
  keep <- logical(length(found))
  last_line2 <- -Inf
  for (i in seq_along(found)) {
    if (found[[i]]$line1 > last_line2) {
      keep[[i]] <- TRUE
      last_line2 <- found[[i]]$line2
    }
  }
  found <- found[keep]

  out <- data.frame(
    line1 = vapply(found, `[[`, integer(1L), "line1"),
    line2 = vapply(found, `[[`, integer(1L), "line2"),
    col1 = vapply(found, `[[`, integer(1L), "col1"),
    n = vapply(found, `[[`, integer(1L), "n"),
    multiline = vapply(found, `[[`, logical(1L), "multiline"),
    stringsAsFactors = FALSE
  )
  out$elements <- lapply(found, `[[`, "elements")

  out
}


#' Internal: describe one `c()` / `list()` call
#'
#' @param pd Parse data as returned by `getParseData()`.
#' @param sym_id Id of the `SYMBOL_FUNCTION_CALL` row.
#' @param call_ids Ids returned by `.at_call_ids()`.
#' @param min_length Minimum number of elements (exclusive).
#'
#' @return `NULL` when the call does not qualify, otherwise a list with
#'   `line1`, `line2`, `col1`, `n`, `multiline` and `elements`.
#'
#' @keywords internal
.at_call_info <- function(pd, sym_id, call_ids, min_length) {
  fn_expr_id <- pd$parent[pd$id == sym_id]
  if (length(fn_expr_id) != 1L) {
    return(NULL)
  }
  call_id <- pd$parent[pd$id == fn_expr_id]
  if (length(call_id) != 1L) {
    return(NULL)
  }
  call_row <- pd[pd$id == call_id, , drop = FALSE]
  if (nrow(call_row) != 1L || call_row$token != "expr") {
    return(NULL)
  }

  kids <- pd[pd$parent == call_id, , drop = FALSE]
  if (any(kids$token %in% c("SYMBOL_SUB", "EQ_SUB"))) {
    # Air refuses to build a table out of named elements.
    return(NULL)
  }
  if (
    .at_has_call_ancestor(
      pd = pd,
      call_id = call_id,
      call_ids = call_ids
    )
  ) {
    # Air only honours the directive for the outermost call of a statement.
    return(NULL)
  }
  is_separator <- kids$terminal & kids$text %in% c("(", ")", ",")
  is_comment <- kids$token == "COMMENT"
  is_element <- !kids$id %in% fn_expr_id & !is_separator & !is_comment
  elements <- kids[is_element, c("line1", "col1", "line2", "col2")]
  elements <- elements[order(elements$line1, elements$col1), , drop = FALSE]
  n <- nrow(elements)
  if (n <= min_length) {
    return(NULL)
  }

  list(
    line1 = as.integer(call_row$line1),
    line2 = as.integer(call_row$line2),
    col1 = as.integer(call_row$col1),
    n = as.integer(n),
    multiline = call_row$line2 > call_row$line1,
    elements = elements
  )
}


#' Internal: ids of all call expressions
#'
#' @param pd Parse data as returned by `getParseData()`.
#'
#' @return An integer vector of `expr` ids that are function calls.
#'
#' @keywords internal
.at_call_ids <- function(pd) {
  fn_expr <- pd$parent[pd$token == "SYMBOL_FUNCTION_CALL"]
  call_ids <- pd$parent[match(fn_expr, pd$id)]

  unique(call_ids[!is.na(call_ids)])
}


#' Internal: is the call nested inside another call?
#'
#' @param pd Parse data as returned by `getParseData()`.
#' @param call_id Id of the call expression.
#' @param call_ids Ids returned by `.at_call_ids()`.
#'
#' @return A single logical.
#'
#' @keywords internal
.at_has_call_ancestor <- function(pd, call_id, call_ids) {
  parent <- pd$parent[pd$id == call_id]
  while (length(parent) == 1L && parent > 0L) {
    if (parent %in% call_ids) {
      return(TRUE)
    }
    parent <- pd$parent[pd$id == parent]
  }

  FALSE
}


#' Internal: insert the directive and re-flow the elements
#'
#' @param lines Character vector of the file contents.
#' @param targets Data frame returned by `.at_targets()`.
#' @param ncol Number of elements per row.
#' @param marker The air table directive to insert.
#'
#' @return A character vector with the modified file contents.
#'
#' @keywords internal
.at_collapse <- function(lines, targets, ncol, marker) {
  n_lines <- length(lines)
  insert <- rep(NA_character_, n_lines)
  join <- logical(n_lines)
  replace <- vector("list", n_lines)

  for (i in seq_len(nrow(targets))) {
    first <- targets$line1[[i]]
    indent <- sub("^([ \t]*).*$", "\\1", lines[[first]])
    marker_line <- paste0(indent, marker)

    if (isTRUE(targets$multiline[[i]])) {
      insert[[first]] <- marker_line
      join <- .at_join_flags(
        join = join,
        elements = targets$elements[[i]],
        ncol = ncol,
        lines = lines
      )
    } else {
      replace[[first]] <- c(
        marker_line,
        .at_split_lines(
          line = lines[[first]],
          call_col1 = targets$col1[[i]],
          elements = targets$elements[[i]],
          ncol = ncol
        )
      )
    }
  }

  out <- list()
  pos <- 0L
  for (i in seq_len(n_lines)) {
    if (!is.null(replace[[i]])) {
      for (chunk in replace[[i]]) {
        pos <- pos + 1L
        out[[pos]] <- chunk
      }
      next
    }
    if (!is.na(insert[[i]])) {
      pos <- pos + 1L
      out[[pos]] <- insert[[i]]
    }
    if (join[[i]] && pos > 0L) {
      out[[pos]] <- paste0(out[[pos]], " ", trimws(lines[[i]]))
    } else {
      pos <- pos + 1L
      out[[pos]] <- lines[[i]]
    }
  }

  unlist(out, use.names = FALSE)
}


#' Internal: rows of element indices
#'
#' @param n Number of elements.
#' @param ncol Number of elements per row.
#'
#' @return A list of integer vectors.
#'
#' @keywords internal
.at_rows <- function(n, ncol) {
  split(
    seq_len(n),
    rep(seq_len(ceiling(n / ncol)), each = ncol, length.out = n)
  )
}


#' Internal: flag the line breaks that disappear when rows are collapsed
#'
#' @param join Logical vector of line-break flags to update.
#' @param elements Data frame of element positions.
#' @param ncol Number of elements per row.
#' @param lines Character vector of the file contents.
#'
#' @return The updated `join` vector.
#'
#' @details
#' A line ending in a comment is never joined with the next one: the joined
#' element would be swallowed by the comment and silently disappear.
#'
#' @keywords internal
.at_join_flags <- function(join, elements, ncol, lines) {
  for (row in .at_rows(nrow(elements), ncol)) {
    if (length(row) < 2L) {
      next
    }
    for (k in seq_len(length(row) - 1L)) {
      from <- elements$line2[[row[[k]]]]
      to <- elements$line1[[row[[k + 1L]]]]
      if (to != from + 1L) {
        next
      }
      trailing <- substring(
        lines[[from]],
        elements$col2[[row[[k]]]] + 1L,
        nchar(lines[[from]])
      )
      if (!grepl("#", trailing, fixed = TRUE)) {
        join[[to]] <- TRUE
      }
    }
  }

  join
}


#' Internal: rewrite a single-line definition as a table
#'
#' @param line The source line holding the whole call.
#' @param call_col1 Column where the call starts.
#' @param elements Data frame of element positions.
#' @param ncol Number of elements per row.
#'
#' @return A character vector of replacement lines, without the directive.
#'
#' @keywords internal
.at_split_lines <- function(line, call_col1, elements, ncol) {
  indent <- sub("^([ \t]*).*$", "\\1", line)
  prefix <- substr(line, 1L, call_col1 - 1L)
  open <- trimws(
    substr(line, call_col1, elements$col1[[1L]] - 1L),
    which = "right"
  )
  cells <- substring(
    line,
    elements$col1,
    elements$col2
  )
  close_col <- elements$col2[[nrow(elements)]] + 1L
  close <- substring(line, close_col, nchar(line))

  rows <- .at_rows(length(cells), ncol)
  row_text <- vapply(
    rows,
    function(row) paste0(cells[row], collapse = ", "),
    character(1L)
  )
  row_text <- paste0(row_text, c(rep(",", length(row_text) - 1L), ""))

  c(
    paste0(prefix, open),
    paste0(indent, "  ", row_text),
    paste0(indent, close)
  )
}
