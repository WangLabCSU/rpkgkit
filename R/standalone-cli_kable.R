# ---
# repo: Exceret/rpkgkit
# file: standalone-cli_kable.R
# last-updated: 2026-11-05
# license: https://unlicense.org
# imports: [cli]
# ---
#
# This file provides a `cli`-only re-implementation of the pipe table printed
# by `kableExtra::kable()` / `knitr::kable(x, format = "pipe")`:
# `cli_kable()`. The layout is the one of `kable()` (padded cells, `|`
# separators and the `:---|---:` alignment rule), while the column headers, the
# row names and the body values can each be styled with any `cli` inline class.
#
# The three format arguments accept a single class, a named vector or a named
# list, so a part of the table can be highlighted: named elements only style
# the matching columns (or rows), and an unnamed element is the fallback style
# of everything that is not named.
#
# nocov start

#' Print a data frame as a `kable`-style table with cli styling
#'
#' Prints `x` as a pipe table laid out like `knitr::kable(x, format = "pipe")`,
#' the format used by `kableExtra::kable()`. Headers, row names and values can
#' each be styled with `cli` inline classes, so a whole table or only a part of
#' it can be highlighted.
#'
#' Every format argument accepts, in addition to a single class applied
#' everywhere, a named vector or a named list: only the columns (or rows)
#' whose name is given are styled, which is how a part of the table is
#' highlighted. An element without a name is the fallback style for everything
#' that is not named.
#'
#' @param x A data frame, a matrix, or any object [as.data.frame()] accepts.
#' @param header_format A `cli` inline class for the column headers, e.g.
#'   `".val"`, `".field"`, `".strong"`, `".emph"`; the leading dot is
#'   optional. `NULL` means no styling. A single string styles every header,
#'   and a named vector such as `c(cyl = ".val", wt = ".field")` styles only
#'   the `cyl` and `wt` columns, leaving the others unstyled.
#' @param rownames_format Same as `header_format`, but applied to the row names
#'   column and matched against the row names, e.g.
#'   `c("Hornet 4 Drive" = ".field")`.
#' @param value_format Style of the body values. `NULL` (default) means no
#'   styling. It can be a single string, a vector of length `ncol(x)`, a named
#'   vector or named list matched against the column names (all values of a
#'   column get the same style), or a named list whose elements are named
#'   vectors matched against the row names (per cell styling within a column).
#' @param align Column alignment: `NULL` aligns numbers to the right and
#'   everything else to the left, as `kable()` does; `"l"`, `"c"`, `"r"` (or
#'   `"left"`, `"center"`, `"right"`) are recycled over the columns. The row
#'   names column is always left aligned.
#' @param digits Number of decimal places that numeric columns are rounded to
#'   before they are formatted, as in `kable()`. Defaults to
#'   `getOption("digits")`; `NULL` formats the values without rounding.
#' @param padding Spaces added to the width of each column. `padding = 1`
#'   reproduces the layout of `knitr::kable()`; `padding = 0` removes that
#'   extra space. Columns are still at least 3 characters wide, as in
#'   `kable()`, so the alignment rule stays valid.
#' @param sep Separator between cells, used both between cells and at both
#'   ends of each line.
#' @param rule Whether to print the `:---|---:` alignment rule below the
#'   headers, as `kable()` does.
#'
#' @return The printed lines, invisibly.
#' @noRd
cli_kable <- function(
  x,
  header_format = ".val",
  rownames_format = ".val",
  value_format = NULL,
  align = NULL,
  digits = NULL,
  padding = 1L,
  sep = "|",
  rule = TRUE
) {
  df <- if (is.data.frame(x)) x else as.data.frame(x, stringsAsFactors = FALSE)
  n_row <- nrow(df)
  n_col <- ncol(df)
  if (!is.null(digits)) {
    if (!is.numeric(digits) || length(digits) != 1L || is.na(digits)) {
      cli::cli_abort("`digits` must be a single number or {.val NULL}.")
    }
  }
  if (
    !is.numeric(padding) ||
      length(padding) != 1L ||
      is.na(padding) ||
      padding < 0L
  ) {
    cli::cli_abort(
      "`padding` must be a single non-negative number."
    )
  }
  if (!is.character(sep) || length(sep) != 1L || is.na(sep)) {
    cli::cli_abort("`sep` must be a single string.")
  }
  padding <- as.integer(padding)

  # Column names and row names, as used to match the formats. Row names are
  # dropped when they are the default `1:n`, as `kable()` does.
  cols <- names(df)
  if (is.null(cols)) {
    cols <- rep("", n_col)
  }
  blank <- !nzchar(cols) | is.na(cols)
  cols[blank] <- paste0("V", which(blank))
  rns <- rownames(df)
  if (is.null(rns) || identical(rns, as.character(seq_len(n_row)))) {
    rns <- NULL
  }
  has_rn <- !is.null(rns)
  rn_keys <- if (has_rn) rns else as.character(seq_len(n_row))

  # Plain text of the body, one column at a time so that numeric columns are
  # formatted (and aligned on the decimal point) as a whole.
  vals <- matrix("", nrow = n_row, ncol = n_col)
  for (j in seq_len(n_col)) {
    vals[, j] <- .ck_cell_text(x = df[[j]], digits = digits)
  }

  head_cls <- .ck_fmt_axis(
    fmt = header_format,
    keys = cols,
    arg = "header_format",
    what = "column"
  )
  rn_cls <- if (has_rn) {
    .ck_fmt_axis(
      fmt = rownames_format,
      keys = rn_keys,
      arg = "rownames_format",
      what = "row"
    )
  } else {
    character()
  }
  val_cls <- .ck_fmt_cells(
    fmt = value_format,
    cols = cols,
    rns = rn_keys,
    arg = "value_format"
  )

  how <- .ck_align(align = align, df = df)

  # Render (styles may add visible characters, e.g. `{.val}` quotes), then
  # measure the visible width and pad.
  head_txt <- .ck_style(x = cols, cls = head_cls)
  rn_txt <- if (has_rn) .ck_style(x = rns, cls = rn_cls)
  val_txt <- .ck_style(x = as.vector(vals), cls = as.vector(val_cls))
  dim(val_txt) <- dim(vals)

  w <- vapply(
    X = seq_len(n_col),
    FUN = function(j) {
      max(cli::ansi_nchar(x = c(head_txt[j], val_txt[, j]), type = "width"))
    },
    FUN.VALUE = integer(1L)
  )
  # `kable()` pads every column by `padding` and keeps it at least 3 characters
  # wide, so that the `:---` alignment rule stays valid.
  w <- pmax(w + ifelse(how == "center", 2L * padding, padding), 3L)
  w_rn <- if (has_rn) {
    max(3L, max(cli::ansi_nchar(x = rn_txt, type = "width")) + padding)
  } else {
    0L
  }

  build <- function(cells) {
    paste0(sep, paste(cells, collapse = sep), sep)
  }
  head_line <- build(
    c(
      if (has_rn) strrep(x = " ", times = w_rn),
      .ck_pad(txt = head_txt, w = w, how = how)
    )
  )
  rule_line <- build(
    c(
      if (has_rn) .ck_rule(w = w_rn, how = "left"),
      .ck_rule(w = w, how = how)
    )
  )
  body_lines <- vapply(
    X = seq_len(n_row),
    FUN = function(i) {
      cells <- .ck_pad(txt = val_txt[i, ], w = w, how = how)
      if (has_rn) {
        cells <- c(.ck_pad(txt = rn_txt[i], w = w_rn, how = "left"), cells)
      }
      build(cells)
    },
    FUN.VALUE = character(1L)
  )

  lines <- c(head_line, if (isTRUE(rule)) rule_line, body_lines)
  cli::cli_verbatim(lines)

  invisible(lines)
}

# ---- Internal helpers -------------------------------------------------------

# Plain text of one column, formatted like `kable()`: numerics are rounded to
# `digits` decimals and formatted as a vector (so that decimals line up),
# everything else is coerced to character.
.ck_cell_text <- function(x, digits) {
  out <- if (is.factor(x)) {
    as.character(x)
  } else if (is.numeric(x) || is.complex(x)) {
    if (!is.null(digits)) {
      x <- round(x, digits = digits)
    }
    format(x, trim = TRUE)
  } else {
    as.character(x)
  }
  out[is.na(out)] <- "NA"
  trimws(out)
}

# Automatic alignment, as `kable()`: numbers right, everything else left.
.ck_align <- function(align, df) {
  n <- length(df)
  auto <- vapply(
    X = df,
    FUN = function(col) {
      if (is.numeric(col)) "right" else "left"
    },
    FUN.VALUE = character(1L)
  )
  if (is.null(align)) {
    return(unname(auto))
  }
  if (!is.character(align)) {
    cli::cli_abort("`align` must be {.cls character} or {.val NULL}.")
  }
  map <- c(
    l = "left",
    left = "left",
    c = "center",
    center = "center",
    r = "right",
    right = "right"
  )
  out <- unname(map[tolower(rep_len(align, n))])
  if (anyNA(out)) {
    cli::cli_abort(
      c(
        "x" = "`align` must be one of {.val l}, {.val c} or {.val r}.",
        "i" = "Got: {.val {setdiff(unique(align), names(map))}}."
      )
    )
  }
  out
}

# Resolve a format of the header / row names axis into one class per key.
.ck_fmt_axis <- function(fmt, keys, arg, what) {
  n <- length(keys)
  if (is.null(fmt)) {
    return(rep("", n))
  }
  if (is.list(fmt)) {
    # One string per element, and no names of its own: `list(a = c(x = ".val"))`
    # would otherwise be flattened to the key `a.x`.
    scalar <- vapply(
      X = fmt,
      FUN = function(el) {
        is.character(el) && length(el) == 1L && is.null(names(el))
      },
      FUN.VALUE = logical(1L)
    )
    if (!all(scalar)) {
      cli::cli_abort(
        c(
          "x" = "`{arg}` only accepts single strings when given as a list.",
          "i" = "Nested styles are supported by {.arg value_format} only."
        )
      )
    }
    nms <- names(fmt)
    fmt <- unlist(fmt, use.names = FALSE)
    names(fmt) <- nms
  }
  if (!is.character(fmt)) {
    cli::cli_abort(
      "`{arg}` must be {.cls character}, {.cls list} or {.val NULL}, not {.cls {class(fmt)}}."
    )
  }
  nms <- names(fmt)
  out <- if (!is.null(nms) && any(!is.na(nms) & nzchar(nms))) {
    .ck_map_named(vals = fmt, nms = nms, keys = keys, arg = arg, what = what)
  } else if (length(fmt) == 1L) {
    rep(fmt, n)
  } else if (length(fmt) == n) {
    unname(fmt)
  } else {
    cli::cli_abort(
      c(
        "x" = "`{arg}` must be length {n} (one per {what}) or 1, not {length(fmt)}.",
        "i" = "Use a single string, a vector of length {n}, or a named vector."
      )
    )
  }
  .ck_norm_class(cls = out, arg = arg)
}

# Resolve `value_format` into one class per cell (a rows x columns matrix).
.ck_fmt_cells <- function(fmt, cols, rns, arg) {
  n_row <- length(rns)
  n_col <- length(cols)
  out <- matrix("", nrow = n_row, ncol = n_col)
  if (is.null(fmt)) {
    return(out)
  }

  # Not a list: a class per column, as for the header axis.
  if (!is.list(fmt)) {
    per_col <- .ck_fmt_axis(fmt = fmt, keys = cols, arg = arg, what = "column")
    return(matrix(rep(per_col, each = n_row), nrow = n_row, ncol = n_col))
  }

  nms <- names(fmt)
  # Unnamed list: positional over the columns.
  if (is.null(nms) || !any(!is.na(nms) & nzchar(nms))) {
    per_col <- .ck_fmt_axis(
      fmt = unlist(fmt, use.names = FALSE),
      keys = cols,
      arg = arg,
      what = "column"
    )
    return(matrix(rep(per_col, each = n_row), nrow = n_row, ncol = n_col))
  }

  # Named list: one element per column, optionally per row within the column.
  keep <- !is.na(nms) & nzchar(nms)
  if (any(!keep)) {
    fallback <- fmt[!keep]
    if (length(fallback) > 1L) {
      cli::cli_abort(
        c(
          "x" = "`{arg}` has {length(fallback)} unnamed elements.",
          "i" = "Use at most one unnamed element: it styles every unnamed column."
        )
      )
    }
    out[] <- .ck_col_cls(el = fallback[[1L]], rns = rns, arg = arg)
  }
  idx <- match(nms[keep], cols)
  if (anyNA(idx)) {
    .ck_abort_unknown(
      unknown = unique(nms[keep][is.na(idx)]),
      keys = cols,
      arg = arg,
      what = "column"
    )
  }
  for (p in which(keep)) {
    out[, match(nms[p], cols)] <- .ck_col_cls(
      el = fmt[[p]],
      rns = rns,
      arg = arg
    )
  }
  # assigned back into the matrix, because `.ck_norm_class()` drops `dim`
  out[] <- .ck_norm_class(cls = out, arg = arg)
  out
}

# Classes of one column of `value_format`: either one class for the column, or
# one class per row (named by row name, or positional).
.ck_col_cls <- function(el, rns, arg) {
  n <- length(rns)
  if (is.null(el)) {
    return(rep("", n))
  }
  if (!is.character(el)) {
    cli::cli_abort(
      "Elements of `{arg}` must be {.cls character}, not {.cls {class(el)}}."
    )
  }
  nms <- names(el)
  out <- if (!is.null(nms) && any(!is.na(nms) & nzchar(nms))) {
    .ck_map_named(vals = el, nms = nms, keys = rns, arg = arg, what = "row")
  } else if (length(el) == 1L) {
    rep(el, n)
  } else if (length(el) == n) {
    unname(el)
  } else {
    cli::cli_abort(
      c(
        "x" = "An element of `{arg}` must be length {n} (one per row) or 1, not {length(el)}.",
        "i" = "Use a single string, a vector of length {n}, or a named vector."
      )
    )
  }
  .ck_norm_class(cls = out, arg = arg)
}

# Match the named values of a format onto `keys`. The value without a name, if
# any, is the fallback style of the keys that are not named.
.ck_map_named <- function(vals, nms, keys, arg, what) {
  n <- length(keys)
  keep <- !is.na(nms) & nzchar(nms)
  fallback <- vals[!keep]
  if (length(fallback) > 1L) {
    cli::cli_abort(
      c(
        "x" = "`{arg}` has {length(fallback)} unnamed values.",
        "i" = "Use at most one unnamed value: it styles everything not named."
      )
    )
  }
  out <- rep(if (length(fallback) == 1L) fallback else "", n)
  idx <- match(nms[keep], keys)
  if (anyNA(idx)) {
    .ck_abort_unknown(
      unknown = unique(nms[keep][is.na(idx)]),
      keys = keys,
      arg = arg,
      what = what
    )
  }
  out[idx] <- vals[keep]
  out
}

.ck_abort_unknown <- function(unknown, keys, arg, what) {
  shown <- keys[seq_len(min(length(keys), 8L))]
  more <- if (length(keys) > 8L) ", ..." else ""
  cli::cli_abort(
    c(
      "x" = "`{arg}` refers to unknown {what} name{?s}: {.val {unknown}}.",
      "i" = "Known {what} names: {paste0(shown, collapse = ', ')}{more}."
    )
  )
}

# Normalise and validate cli inline classes: the leading dot is optional, and
# `""` is "no style".
.ck_norm_class <- function(cls, arg) {
  cls <- trimws(as.character(cls))
  cls[is.na(cls)] <- ""
  bare <- sub("^\\.", "", cls)
  bad <- nzchar(bare) & !grepl("^[A-Za-z][A-Za-z0-9_.-]*$", bare)
  if (any(bad)) {
    cli::cli_abort(
      c(
        "x" = "`{arg}` contains an invalid cli class: {.val {unique(cls[bad])}}.",
        "i" = "Use a cli inline class such as {.val .val}, {.val .field} or {.val .strong}, with or without the leading dot."
      )
    )
  }
  bare
}

# Style a vector of strings, one class per element (`""` keeps the element as
# is). The class may add visible characters, e.g. the quotes of `{.val}`.
#
# A cli inline class renders as a prefix, the value, then a suffix, so the
# prefix and suffix of each distinct class are read from a single render call
# and pasted around the values. Formatting each cell with
# `cli::format_inline()` instead would cost a few milliseconds per cell.
.ck_style <- function(x, cls) {
  out <- as.character(x)
  cls <- rep_len(as.character(cls), length(out))
  uniq <- unique(cls[nzchar(cls)])
  if (!length(uniq)) {
    return(out)
  }
  sentinel <- "ck_sentinel_6a1f"
  rendered <- vapply(
    X = uniq,
    FUN = .ck_style1,
    FUN.VALUE = character(1L),
    txt = sentinel
  )
  at <- regexpr(sentinel, rendered, fixed = TRUE)
  if (any(at < 1L)) {
    # A class that drops the sentinel: render the cells one by one instead.
    for (i in seq_along(out)) {
      if (nzchar(cls[i])) {
        out[i] <- .ck_style1(txt = out[i], cls = cls[i])
      }
    }
    return(out)
  }
  prefix <- substring(rendered, 1L, at - 1L)
  suffix <- substring(rendered, at + nchar(sentinel))
  idx <- match(cls, uniq)
  styled <- !is.na(idx)
  out[styled] <- paste0(prefix[idx[styled]], out[styled], suffix[idx[styled]])
  out
}

.ck_style1 <- function(txt, cls) {
  # cli >= 3.4.0 rejects literals that start with a dot, so the leading dot of
  # a class such as ".val" is dropped here rather than in the caller.
  cls <- sub("^\\.", "", cls)
  cli::format_inline(
    text = paste0("{.", cls, " {txt}}"),
    .envir = environment()
  )
}

# Pad styled text to `w` visible characters, alignment per element. An unknown
# alignment is treated as left, and `how` is recycled over the elements.
.ck_pad <- function(txt, w, how) {
  spare <- pmax(w - cli::ansi_nchar(x = txt, type = "width"), 0L)
  how <- rep_len(how, length(spare))
  left <- ifelse(
    how == "right",
    spare,
    ifelse(how == "center", spare %/% 2L, 0L)
  )
  paste0(
    strrep(x = " ", times = left),
    txt,
    strrep(x = " ", times = spare - left)
  )
}

# The `:---` alignment rule of one or more columns. `how` is recycled over the
# columns, and an unknown alignment is treated as left.
.ck_rule <- function(w, how) {
  how <- rep_len(how, length(w))
  dash <- pmax(w - 1L, 0L)
  left <- paste0(":", strrep(x = "-", times = dash))
  right <- paste0(strrep(x = "-", times = dash), ":")
  center <- paste0(":", strrep(x = "-", times = pmax(w - 2L, 0L)), ":")
  ifelse(how == "right", right, ifelse(how == "center", center, left))
}

# nocov end
