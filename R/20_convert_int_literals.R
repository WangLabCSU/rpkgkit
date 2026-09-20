#' Add Explicit Integer Suffix `L` to Integer Literals
#'
#' @description
#' Converts bare integer literals to explicit integer form with an `L` suffix,
#' e.g. `seq_len(10)` becomes `seq_len(10L)`. Strings and comments are left
#' unchanged.
#'
#' [convert_int_literals()] operates on one R file. When `path` is `NULL` and
#' RStudio is available, it uses the currently active document.
#' [package_convert_int_literals()] walks selected directories of an R package
#' and applies the same conversion to every `.R` / `.r` file found.
#'
#' @param path For [convert_int_literals()], a character string specifying the
#'   R file to modify. If `NULL` and RStudio is available, the currently active
#'   document path is used.
#'
#'   For [package_convert_int_literals()], a character string specifying the
#'   package root. If `NULL`, the current working directory is used.
#' @param verbose Logical; enable or disable per-file messages. Used only by
#'   [convert_int_literals()]. Default `TRUE`.
#' @param dirs Character vector of subdirectories relative to `path` to search.
#'   Used only by [package_convert_int_literals()]. Defaults to
#'   `c("R", "tests")`.
#' @param recursive Logical; recurse into subdirectories. Used only by
#'   [package_convert_int_literals()]. Default `TRUE`.
#' @param ... Additional arguments. Currently unused and must be empty.
#'
#' @return
#' [convert_int_literals()] invisibly returns the modified file path.
#' [package_convert_int_literals()] invisibly returns a character vector of
#' modified file paths.
#'
#' @details
#' A token is treated as an integer literal when it is:
#' - a decimal integer (`10`, `0`, `-` is not part of the token), or
#' - a hexadecimal integer (`0xFF`, `0X10`),
#'
#' and it is **not**:
#' - already suffixed with `L` / `l`,
#' - a floating-point number (`10.`, `1.0`, `.5`),
#' - scientific notation (`1e5`, `1E-3`),
#' - a complex literal (`10i`),
#' - adjacent to an identifier character (`a-zA-Z0-9._`).
#'
#' @examples
#' \donttest{
#' # --- Single file ---
#' temp <- tempfile(fileext = ".R")
#' writeLines("tmp <- seq_len(10)", temp)
#' convert_int_literals(temp)
#' readLines(temp)
#' # "tmp <- seq_len(10L)"
#'
#' # --- Entire package ---
#' tmp_pkg <- tempdir()
#' usethis::create_package(tmp_pkg, open = FALSE)
#' writeLines("foo <- seq_len(42)", file.path(tmp_pkg, "R/foo.R"))
#' package_convert_int_literals(tmp_pkg)
#' readLines(file.path(tmp_pkg, "R/foo.R"))
#' }
#'
#' @name convert_int_literals
NULL

#' @rdname convert_int_literals
#' @export
convert_int_literals <- function(path = NULL, verbose = TRUE, ...) {
  rlang::check_dots_empty0(...)

  path <- if (is.null(path) && rlang::is_installed("rstudioapi")) {
    rstudioapi::getActiveDocumentContext()$path
  } else {
    path %||%
      cli::cli_abort(c("x" = "{.arg path} is required when not in RStudio."))
  }

  text <- readLines(path, warn = FALSE)
  original <- paste(text, collapse = "\n")

  result <- .cil_process_text(original)

  if (identical(result, original)) {
    if (verbose) {
      cli::cli_alert_info(
        "No integer literals to convert in {.file {path}}"
      )
    }
    return(invisible(path))
  }

  writeLines(result, path)
  if (verbose) {
    cli::cli_alert_success(
      "Added explicit integer suffixes in {.file {path}}"
    )
  }

  invisible(path)
}


#' Internal: character-level integer-literal rewrite
#'
#' @keywords internal
.cil_process_text <- function(text) {
  chars <- strsplit(text, NULL)[[1L]]
  nc <- length(chars)

  result <- character()
  i <- 1L
  in_string <- FALSE
  string_char <- NA_character_
  in_comment <- FALSE
  in_raw_string <- FALSE
  raw_dash_n <- 0L
  raw_close <- NA_character_

  is_ident <- function(ch) {
    grepl("[a-zA-Z0-9._]", ch)
  }

  while (i <= nc) {
    ch <- chars[i]

    # ---- raw strings: r"..." / R"..." / r'...' (R 4.0+) ----
    if (
      !in_comment &&
        !in_string &&
        !in_raw_string &&
        ch %in% c("r", "R") &&
        i < nc &&
        chars[i + 1L] %in% c("'", '"')
    ) {
      quote <- chars[i + 1L]
      k <- i + 2L
      dashes <- 0L
      while (k <= nc && chars[k] == "-") {
        dashes <- dashes + 1L
        k <- k + 1L
      }
      if (k <= nc && chars[k] == "(") {
        in_raw_string <- TRUE
        raw_dash_n <- dashes
        raw_close <- quote
        result <- c(result, chars[i:k])
        i <- k + 1L
        next
      }
    }
    if (in_raw_string) {
      # look for )---"  (same dash count)
      if (ch == ")") {
        ok <- TRUE
        for (d in seq_len(raw_dash_n)) {
          if (i + d > nc || chars[i + d] != "-") {
            ok <- FALSE
            break
          }
        }
        qpos <- i + raw_dash_n + 1L
        if (ok && qpos <= nc && chars[qpos] == raw_close) {
          result <- c(result, chars[i:qpos])
          i <- qpos + 1L
          in_raw_string <- FALSE
          next
        }
      }
      result <- c(result, ch)
      i <- i + 1L
      next
    }

    # ---- Track string state ----
    if (!in_comment && !in_string && ch %in% c("'", '"')) {
      in_string <- TRUE
      string_char <- ch
      result <- c(result, ch)
      i <- i + 1L
      next
    }
    if (in_string) {
      if (ch == "\\" && i < nc) {
        result <- c(result, ch, chars[i + 1L])
        i <- i + 2L
        next
      }
      if (ch == string_char) {
        in_string <- FALSE
      }
      result <- c(result, ch)
      i <- i + 1L
      next
    }

    # ---- Track comment state ----
    if (!in_comment && ch == "#") {
      in_comment <- TRUE
      result <- c(result, ch)
      i <- i + 1L
      next
    }
    if (in_comment) {
      result <- c(result, ch)
      if (ch == "\n") {
        in_comment <- FALSE
      }
      i <- i + 1L
      next
    }

    # ---- Integer literals ----
    prev_ok <- i == 1L || !is_ident(chars[i - 1L])

    # hex: 0x / 0X + hex digits
    if (
      prev_ok &&
        ch == "0" &&
        i < nc &&
        chars[i + 1L] %in% c("x", "X")
    ) {
      j <- i + 2L
      while (j <= nc && grepl("[0-9a-fA-F]", chars[j])) {
        j <- j + 1L
      }
      if (j > i + 2L) {
        has_l <- j <= nc && chars[j] %in% c("L", "l")
        has_i <- j <= nc && chars[j] == "i"
        next_ident <- j <= nc && is_ident(chars[j]) && !has_l && !has_i
        if (!next_ident && !has_i) {
          result <- c(result, chars[i:(j - 1L)])
          if (!has_l) {
            result <- c(result, "L")
          } else {
            result <- c(result, chars[j])
            j <- j + 1L
          }
          i <- j
          next
        }
      }
    }

    # decimal digits
    if (prev_ok && grepl("[0-9]", ch)) {
      j <- i
      while (j <= nc && grepl("[0-9]", chars[j])) {
        j <- j + 1L
      }

      nxt <- if (j <= nc) chars[j] else ""

      is_float <- nxt == "."
      is_exp <- nxt %in% c("e", "E")
      is_complex <- nxt == "i"
      has_l <- nxt %in% c("L", "l")
      next_ident <- is_ident(nxt) && !has_l && !is_complex && !is_exp

      # 1.2 or 1e3 or 10i or glued identifier -> leave as-is
      if (!is_float && !is_exp && !is_complex && !next_ident) {
        result <- c(result, chars[i:(j - 1L)])
        if (!has_l) {
          result <- c(result, "L")
        } else {
          result <- c(result, chars[j])
          j <- j + 1L
        }
        i <- j
        next
      }
    }

    result <- c(result, ch)
    i <- i + 1L
  }

  paste(result, collapse = "")
}
