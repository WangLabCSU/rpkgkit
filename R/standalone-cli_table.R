# ---
# repo: Exceret/rpkgkit
# file: standalone-cli_table.R
# last-updated: 2026-10-14
# license: https://unlicense.org
# imports: [cli]
# ---
#
# This file provides cli-styled frequency tables for vectors:
# `cli_table()` prints the distinct values and their counts as two aligned
# lines, and `cli_table_oneline()` prints the same information as a single
# `header: count` line. Both return the underlying `table` object invisibly,
# and headers/counts can be styled with any cli inline class.
#
# nocov start

#' Print a frequency table of a vector with cli styling
#'
#' Tabulates `x` and prints two lines of formatted output: the first line
#' holds the headers (the distinct values), the second line holds the counts.
#' Headers and counts can be styled independently with cli inline classes.
#'
#' @param x A vector (character, factor, numeric, etc.).
#' @param head_format A cli inline style applied to the headers, e.g. `".val"`,
#'   `".field"`, `".emph"`, `".strong"`, `".code"`, `".cls"`. The leading dot is
#'   optional. `NULL` means no styling.
#' @param count_format A cli inline style applied to the counts. Same usage as
#'   `head_format`.
#' @param align Alignment of the counts within each column: `"right"`
#'   (default), `"left"` or `"center"`. Column width is the larger of the header
#'   and the count.
#' @param useNA Passed to [table()]. Defaults to `"ifany"`, so missing values
#'   are counted separately when present.
#' @param sep Number of spaces between columns.
#' @param .envir Evaluation environment used by cli.
#'
#' @return The underlying `table` object, invisibly.
#' @noRd
cli_table <- function(
  x,
  head_format = ".field",
  count_format = ".val",
  align = c("right", "left", "center"),
  useNA = "ifany",
  sep = 2L,
  .envir = parent.frame()
) {
  align <- match.arg(arg = align)
  tab <- table(x, useNA = useNA)
  heads <- names(tab)
  heads[is.na(heads)] <- "NA"
  counts <- as.vector(x = tab)

  head_txt <- vapply(
    X = heads,
    FUN = .cli_render,
    FUN.VALUE = character(length = 1L),
    fmt = head_format,
    USE.NAMES = FALSE
  )
  count_txt <- vapply(
    X = counts,
    FUN = .cli_render,
    FUN.VALUE = character(length = 1L),
    fmt = count_format,
    USE.NAMES = FALSE
  )

  # column width
  w <- pmax(
    cli::ansi_nchar(x = head_txt, type = "width"),
    cli::ansi_nchar(x = count_txt, type = "width")
  )

  gap <- strrep(x = " ", times = sep)

  cli::cli_verbatim(paste(
    .cli_pad(txt = head_txt, w = w, how = "left"),
    collapse = gap
  ))
  cli::cli_verbatim(paste(
    .cli_pad(txt = count_txt, w = w, how = align),
    collapse = gap
  ))

  invisible(tab)
}

#' Print a frequency table of a vector on one line
#'
#' Tabulates `x` and prints a single line of the form
#' `col1: val1, col2: val2, ...`, where `col` is each distinct value and `val`
#' its count. Styling works the same way as in `cli_table()`.
#'
#' @param x A vector (character, factor, numeric, etc.).
#' @param head_format A cli inline style applied to the headers, e.g. `".val"`,
#'   `".field"`, `".emph"`. The leading dot is optional. `NULL` means no
#'   styling.
#' @param count_format A cli inline style applied to the counts. Same usage as
#'   `head_format`.
#' @param useNA Passed to [table()]. Defaults to `"ifany"`.
#' @param sep Separator between `header: count` pairs.
#' @param colon Separator between a header and its count.
#'
#' @return The underlying `table` object, invisibly.
#' @noRd
cli_table_oneline <- function(
  x,
  head_format = ".field",
  count_format = ".val",
  useNA = "ifany",
  sep = ", ",
  colon = ": "
) {
  tab <- table(x, useNA = useNA)
  heads <- names(tab)
  heads[is.na(heads)] <- "NA"
  counts <- as.vector(x = tab)

  head_txt <- vapply(
    X = heads,
    FUN = .cli_render,
    FUN.VALUE = character(length = 1L),
    fmt = head_format,
    USE.NAMES = FALSE
  )
  count_txt <- vapply(
    X = counts,
    FUN = .cli_render,
    FUN.VALUE = character(length = 1L),
    fmt = count_format,
    USE.NAMES = FALSE
  )

  # cli_verbatim() avoids re-interpreting braces that may appear in the values
  cli::cli_verbatim(paste(paste0(head_txt, colon, count_txt), collapse = sep))

  invisible(tab)
}

.cli_pad <- function(txt, w, how = "left") {
  n <- w - cli::ansi_nchar(x = txt, type = "width") # spaces still needed
  left <- switch(how, left = 0L, right = n, center = n %/% 2L)
  paste0(strrep(x = " ", times = left), txt, strrep(x = " ", times = n - left))
}

# Internal helper shared by cli_table() and cli_table_oneline():
# styles a single value with a cli inline class such as ".val" or "field".
# `fmt = NULL` (or "") returns the value unstyled.
.cli_render <- function(x, fmt) {
  tpl <- if (is.null(fmt) || !nzchar(fmt)) {
    "{x}"
  } else {
    paste0("{.", sub("^\\.", "", fmt), " {x}}")
  }
  cli::format_inline(tpl) # `x` is looked up in this function's environment
}

# nocov end
