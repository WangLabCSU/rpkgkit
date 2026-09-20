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
#' @param dirs Character vector of package-relative directories scanned by
#'   \code{package_print_and_cat()}. Defaults to \code{"R"} and
#'   \code{"tests/testthat"}.
#' @param pattern_fn_names Character vector of regular expressions matching function
#'   names whose return value is treated as a diagnostic string. A `print()`
#'   whose first argument is a string literal or calls a matching function is
#'   flagged as a message. Extra patterns are appended to the default set unless
#'   \code{replace_default_pattern = TRUE}.
#'
#'   To obtain the default patterns, use `rpkgkit:::DEFAULT_PATTERN_FN_NAMES`.
#' @param replace_default_pattern Logical. If \code{TRUE}, \code{pattern_fn_names}
#'   fully replaces the default set instead of extending it.
#' @param include_s3 Logical. If \code{TRUE}, report `print()` calls whose
#'   first argument is not string-like (S3 object printing). Default
#'   \code{TRUE}.
#' @param include_refs Logical. If \code{TRUE}, also report bare
#'   \code{print}/\code{cat} symbols (e.g. \code{lapply(x, print)}).
#'   Default \code{FALSE}.
#' @param test_included `r lifecycle::badge('deprecated')`. Logical indicating whether to scan
#'   \code{tests/testthat/} in addition to \code{R/}. Use \code{dirs} instead.
#'   When supplied, \code{FALSE} scans only \code{R/}; \code{TRUE} scans both
#'   default directories.
#' @param verbose Whether to output information in console
#'
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
detect_print_and_cat <- function(
  path = NULL,
  fix = FALSE,
  pattern_fn_names = DEFAULT_PATTERN_FN_NAMES,
  replace_default_pattern = FALSE,
  include_s3 = TRUE,
  include_refs = FALSE,
  verbose = TRUE,
  ...
) {
  path <- path %||% rstudioapi::getActiveDocumentContext()$path
  # validate pattern
  pattern_fn_names <- resolve_pattern_fn_names(
    pattern_fn_names,
    replace_default_pattern
  )

  lines <- readLines(con = path, warn = FALSE)
  text <- paste(lines, collapse = "\n")
  exprs <- parse_safely(text = text, path = path)
  parse_data <- utils::getParseData(exprs)

  calls_info <- find_print_cat_calls(
    parse_data = parse_data,
    pattern_fn_names = pattern_fn_names,
    include_s3 = include_s3,
    include_refs = include_refs
  )

  if (length(calls_info) == 0L) {
    if (verbose) {
      cli::cli_alert_success("No {.fn print} or {.fn cat} calls found.")
    }
    return(invisible(TRUE))
  }

  if (fix) {
    original_lines <- lines
    to_fix <- Filter(
      f = function(x) x$type == "call" && identical(x$kind, "message"),
      x = calls_info
    )
    if (length(to_fix) > 0L) {
      # right-to-left so column offsets stay valid on the same line
      ord <- order(
        vapply(to_fix, `[[`, integer(1L), "line1"),
        vapply(to_fix, `[[`, integer(1L), "col1"),
        decreasing = TRUE
      )
      for (info in to_fix[ord]) {
        lines[[info$line1]] <- replace_fn_at(
          line = lines[[info$line1]],
          col1 = info$col1,
          col2 = info$col2,
          new = "message"
        )
      }
      writeLines(text = lines, con = path)
      n_lines <- length(unique(vapply(to_fix, `[[`, integer(1L), "line1")))
      if (verbose) {
        cli::cli_alert_success(
          "Fixed {n_lines} line{?s} in {.path {basename(path)}}."
        )
      }
    }
  }

  report_lines <- if (fix) original_lines else lines
  for (info in calls_info) {
    caret_width <- nchar(x = info$text) + if (info$type == "call") 1L else 0L
    caret <- paste0(
      strrep(x = " ", times = info$col1 - 1L),
      strrep(x = "^", times = caret_width)
    )
    tag <- if (!is.null(info$kind)) paste0(" [", info$kind, "]") else ""
    message(paste0(report_lines[[info$line1]], tag, "\n", caret))
  }

  reported_lines <- unique(vapply(calls_info, `[[`, integer(1L), "line1"))
  if (verbose) {
    cli::cli_alert_danger(
      "Found {length(calls_info)} unsupported call{?s} on line{?s} {.val {reported_lines}}."
    )
  }
  invisible(FALSE)
}


DEFAULT_PATTERN_FN_NAMES <- c(
  "^paste$",
  "^paste0$",
  "^sprintf$",
  "^gettext$",
  "^gettextf$",
  "^ngettext$",
  "^glue$",
  "^str_c$",
  "^str_glue$",
  "^as\\.character$",
  "^as\\.numeric$",
  "^as\\.factor$",
  "^toString$",
  "^strrep$"
)

resolve_pattern_fn_names <- function(
  pattern_fn_names = NULL,
  replace_default_pattern = FALSE
) {
  if (is.null(pattern_fn_names) || length(pattern_fn_names) == 0L) {
    return(DEFAULT_PATTERN_FN_NAMES)
  }

  pattern_fn_names <- unique(as.character(pattern_fn_names))

  invalid <- !vapply(
    pattern_fn_names,
    function(x) {
      tryCatch(
        {
          grepl(x, "", perl = TRUE)
          TRUE
        },
        error = function(e) FALSE
      )
    },
    logical(1)
  )

  if (any(invalid)) {
    cli::cli_abort(
      "`pattern_fn_names` contains invalid regular expressions: {.val {pattern_fn_names[invalid]}}"
    )
  }

  if (isTRUE(replace_default_pattern)) {
    pattern_fn_names
  } else {
    unique(c(DEFAULT_PATTERN_FN_NAMES, pattern_fn_names))
  }
}

replace_fn_at <- function(line, col1, col2, new = "message") {
  paste0(substr(line, 1L, col1 - 1L), new, substr(line, col2 + 1L, nchar(line)))
}

get_children <- function(parse_data, id) {
  parse_data[parse_data$parent == id, , drop = FALSE]
}

is_stringy_expr <- function(parse_data, expr_id, pattern_fn_names) {
  kids <- get_children(parse_data, expr_id)
  if (nrow(kids) == 0L) {
    return(FALSE)
  }
  if (any(kids$token == "STR_CONST")) {
    return(TRUE)
  }
  fns <- kids$text[kids$token == "SYMBOL_FUNCTION_CALL"]
  nested_ids <- kids$id[kids$token == "expr"]
  for (nid in nested_ids) {
    nkids <- get_children(parse_data, nid)
    fns <- c(fns, nkids$text[nkids$token == "SYMBOL_FUNCTION_CALL"])
  }
  any(vapply(
    pattern_fn_names,
    function(pattern) any(grepl(pattern = pattern, x = fns)),
    logical(1L)
  ))
}

classify_print_cat <- function(parse_data, func_row, pattern_fn_names) {
  function_expr <- parse_data[parse_data$id == func_row$parent, , drop = FALSE]
  children <- get_children(parse_data, function_expr$parent)
  fn <- func_row$text

  if (identical(fn, "cat")) {
    has_file <- any(children$token == "SYMBOL_SUB" & children$text == "file")
    return(if (has_file) "file-write" else "message")
  }

  expr_ids <- children$id[children$token == "expr"]
  if (length(expr_ids) < 2L) {
    return("empty")
  }
  if (is_stringy_expr(parse_data, expr_ids[[2L]], pattern_fn_names)) {
    "message"
  } else {
    "s3-print"
  }
}

find_print_cat_calls <- function(
  parse_data,
  pattern_fn_names,
  include_s3 = TRUE,
  include_refs = FALSE
) {
  direct <- parse_data[
    parse_data$token == "SYMBOL_FUNCTION_CALL" &
      parse_data$text %in% c("print", "cat"),
  ]
  out <- list()
  for (i in seq_len(nrow(direct))) {
    kind <- classify_print_cat(parse_data, direct[i, ], pattern_fn_names)
    if (identical(kind, "s3-print") && !include_s3) {
      next
    }
    if (identical(kind, "file-write")) {
      next
    }
    out[[length(out) + 1L]] <- list(
      line1 = direct$line1[[i]],
      col1 = direct$col1[[i]],
      col2 = direct$col2[[i]],
      text = direct$text[[i]],
      type = "call",
      kind = kind
    )
  }
  if (include_refs) {
    refs <- parse_data[
      parse_data$token == "SYMBOL" & parse_data$text %in% c("print", "cat"),
    ]
    for (i in seq_len(nrow(refs))) {
      out[[length(out) + 1L]] <- list(
        line1 = refs$line1[[i]],
        col1 = refs$col1[[i]],
        col2 = refs$col2[[i]],
        text = refs$text[[i]],
        type = "ref",
        kind = "ref"
      )
    }
  }
  out
}
