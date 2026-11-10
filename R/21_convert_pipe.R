#' Switch Between the Tidyverse Pipe `%>%` and the Base Pipe `|>`
#'
#' @description
#' Rewrites pipe operators in an R file between the magrittr pipe `%>%` and the
#' base pipe `|>`. Strings, comments, and raw strings are left unchanged, so a
#' mention of either operator in documentation or a character literal is not
#' rewritten.
#'
#' [convert_pipe()] operates on one R file. When `path` is `NULL` and RStudio is
#' available, it uses the currently active document.
#' [package_convert_pipe()] walks selected directories of an R package and
#' applies the same conversion to every `.R` / `.r` file found, except
#' automatically generated `RcppExports.R` files.
#'
#' The placeholder pipe `%<>%` and the exposition pipe `%$%` are not pipes in
#' this sense and are left untouched.
#'
#' @param path For [convert_pipe()], a character string specifying the R file to
#'   modify. If `NULL` and RStudio is available, the currently active document
#'   path is used.
#'
#'   For [package_convert_pipe()], a character string specifying the package
#'   root. If `NULL`, the current working directory is used.
#' @param direction Conversion direction. One of:
#'   - `"to_base"`: convert `%>%` to `|>`
#'   - `"to_magrittr"`: convert `|>` to `%>%`
#' @param verbose Logical; enable or disable per-file messages. Used only by
#'   [convert_pipe()]. Default `TRUE`.
#' @param dirs Character vector of subdirectories relative to `path` to search.
#'   Used only by [package_convert_pipe()]. Defaults to `c("R")`.
#' @param recursive Logical; recurse into subdirectories. Used only by
#'   [package_convert_pipe()]. Default `TRUE`.
#' @param ... Additional arguments. Currently unused and must be empty.
#'
#' @return
#' Both functions are called for their side effect and invisibly return `TRUE`
#' when they convert something. When there is nothing to convert, `FALSE` is returned
#'
#' @details
#' Rewriting is a literal match, so only a complete operator is converted:
#'
#' - `%>%` becomes `|>`, and `|>` becomes `%>%`.
#' - Matching is literal, so `% > %` (whitespace inside the operator) is not
#'   converted, and `%<>%`, `%$%`, and longer operators such as `%myop%` are
#'   left unchanged.
#' - `|>` is matched only when `%` does not immediately precede it, so the tail
#'   of an operator such as `%|>%` is not treated as a base pipe.
#' - Occurrences inside string literals, raw strings, and comments are left
#'   unchanged.
#'
#' @examples
#' \dontrun{
#' # --- Single file ---
#' temp <- tempfile(fileext = ".R")
#' writeLines("mtcars |> dplyr::filter(cyl > 4)", temp)
#' convert_pipe(temp, direction = "to_magrittr")
#' readLines(temp)
#' # "mtcars %>% dplyr::filter(cyl > 4)"
#'
#' # --- Entire package ---
#' tmp_pkg <- tempdir()
#' usethis::create_package(tmp_pkg, open = FALSE)
#' writeLines("mtcars %>% dplyr::filter(cyl > 4)", file.path(tmp_pkg, "R/foo.R"))
#' package_convert_pipe(tmp_pkg, direction = "to_base")
#' readLines(file.path(tmp_pkg, "R/foo.R"))
#' }
#'
#' @name convert_pipe
NULL

#' @rdname convert_pipe
#' @export
convert_pipe <- function(
  path = NULL,
  direction = c("to_base", "to_magrittr"),
  verbose = TRUE,
  ...
) {
  rlang::check_dots_empty()

  path <- path %||%
    if (rstudioapi::isAvailable()) {
      rstudioapi::getActiveDocumentContext()$path
    }
  if (is.null(path) || !nzchar(path)) {
    cli::cli_abort(c("x" = "{.arg path} is required"))
  }

  direction <- rlang::arg_match(direction)
  rlang::check_bool(verbose)

  text <- readLines(path, warn = FALSE)
  if (length(text) == 0L) {
    return(invisible(FALSE))
  }
  result <- .cp_process_text(text, direction)

  if (identical(result, text)) {
    if (verbose) {
      cli::cli_alert_info("No pipes to convert in {.file {path}}")
    }
    return(invisible(FALSE))
  }

  writeLines(result, path)
  if (verbose) {
    cli::cli_alert_success(
      "Converted pipes in {.file {path}} ({.val {direction}})"
    )
  }

  invisible(TRUE)
}


#' Internal: pipe rewrite that preserves strings and comments
#'
#' `text` is a character vector of lines. A line whose first non-whitespace
#' character is `#` is a comment and is returned untouched; within the remaining
#' lines, pipes inside string literals, raw strings, and trailing comments are
#' left unchanged. The scan is performed by `cp_process_text_rs()`.
#'
#' @keywords internal
.cp_process_text <- function(text, direction) {
  cp_process_text_rs(text, direction)
}

# Rewrite every pipe in free code. `pattern` / `replacement` are kept in the
# signature for backwards compatibility; the Rust scanner only needs the
# conversion direction.
.cp_rewrite_line <- function(lines, pattern, replacement) {
  if (!length(lines)) {
    return(lines)
  }
  direction <- if (identical(replacement, "|>")) "to_base" else "to_magrittr"
  vapply(
    lines,
    function(line) cp_rewrite_line_rs(line, direction),
    character(1L),
    USE.NAMES = FALSE
  )
}

# A pipe is rewritten only when it is not inside a string, raw string, or
# comment. Those regions are matched first (and captured, so the replacement
# keeps them verbatim); the pipe alternative is only reached in free code.
.cp_pattern <- function(direction) {
  pipe <- if (direction == "to_base") "%>%" else "(?<!%)\\|>"

  paste0(
    "(?x)",
    "(",
    # raw strings, e.g. r"(...)" / R'--[...]--' / r'{...}' (R 4.0+)
    "[rR](['\"])(-*)([\\(\\{\\[])",
    "(?:(?!\\4\\3\\2).)*",
    "(?:\\4\\3\\2|\\z)",
    "|",
    # string literals, honouring backslash escapes
    "'(?:\\\\.|[^'\\\\])*'",
    "|",
    "\"(?:\\\\.|[^\"\\\\])*\"",
    "|",
    # a trailing comment, which ends the line
    "\\#.*",
    ")",
    "|",
    pipe
  )
}
