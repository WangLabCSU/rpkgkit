#' Make Function Arguments Explicit
#'
#' @description
#' Transform function calls in R source code so that all arguments are passed
#' with explicit parameter names. Uses a recursive tree-walking approach: every
#' function call node is inspected, the called function's formals are retrieved,
#' and positional arguments are given their formal parameter name.
#'
#' Transformation preserves all content outside the expression boundaries
#' (roxygen docs, section comments, blank lines). Inline comments on the
#' last line of a transformed expression are re-attached to the output.
#'
#' If the function has a \code{...} formal, unmatched positional and named
#' arguments are left in place as-is (they are captured by \code{...}).
#'
#' Operators (\code{+}, \code{-}, \code{*}, \code{/}, etc.), subset operators
#' (\code{[}, \code{[[}, \code{$}), assignment (\code{<-}, \code{=},
#' \code{<<-}), and special syntax (\code{if}, \code{for}, \code{while},
#' \code{repeat}, \code{\{}, \code{(}, \code{function}) are not transformed.
#'
#' @section Single-file operation:
#' Operates on one R file. When \code{path} is \code{NULL} and RStudio is
#' available, the currently active document is used automatically.
#'
#' @param path Path to an R file to modify.
#'   If \code{NULL} and RStudio is available, the active document path is used.
#' @param skip_functions Optional character vector of function or operator names
#'   to skip during transformation (e.g. \code{c("my_special_fn")}). In addition
#'   to user-provided names, all built-in operators (\code{+}, \code{-}, etc.),
#'   special syntax forms (\code{if}, \code{for}, \code{\{}, etc.), and all
#'   \code{\%...\%} infix operators (\code{\%in\%}, \code{\%>\%},
#'   \code{\%||\%}, etc.) are always skipped automatically.
#' @param ... Additional arguments. Currently unused and must be empty.
#'
#' @return Invisible \code{NULL}, called for its side effect of writing the
#'   transformed code back to the file.
#'
#' @examples
#' \donttest{
#' tf <- tempfile(fileext = ".R")
#' writeLines("vapply(1:9, function(x) x*2, numeric(1))", tf)
#' make_func_arg_explicit(tf)
#' cat(readLines(tf), sep = "\n")
#' # vapply(X = 1:9, FUN = function(x) x*2, FUN.VALUE = numeric(1))
#' }
#'
#' @export
make_func_arg_explicit <- function(path = NULL, skip_functions = NULL, ...) {
  rlang::check_dots_empty0()
  path <- path %||% rstudioapi::getActiveDocumentContext()$path
  lines <- readLines(con = path, warn = FALSE)
  all_text <- paste(lines, collapse = "\n")
  inline_comments <- .mfae_capture_inline_comments(lines = lines)
  exprs <- suppressWarnings(expr = parse(text = all_text, keep.source = TRUE))
  if (length(exprs) == 0L) {
    cli::cli_alert_info("No R expressions found in {.file {path}}.")
    return(invisible(NULL))
  }
  src_refs <- attr(exprs, "srcref")
  new_exprs <- .mfae_walk_expr(expr = exprs, skip_fns = skip_functions)
  out_lines <- character()
  cursor <- 1L
  for (i in seq_along(exprs)) {
    srcref <- src_refs[[i]]
    expr_start <- srcref[[1L]]
    expr_end <- srcref[[3L]]
    if (cursor < expr_start) {
      out_lines <- c(out_lines, lines[seq.int(cursor, expr_start - 1L)])
    }
    orig_text <- deparse(expr = exprs[[i]], width.cutoff = 500L)
    new_text <- deparse(expr = new_exprs[[i]], width.cutoff = 500L)
    if (identical(x = orig_text, y = new_text)) {
      out_lines <- c(out_lines, lines[seq.int(expr_start, expr_end)])
    } else {
      out_lines <- c(out_lines, new_text)
      comment_key <- as.character(expr_end)
      trail <- inline_comments[[comment_key]]
      if (!is.null(trail)) {
        idx <- length(out_lines)
        sep <- if (grepl(pattern = "\\s$", x = out_lines[[idx]], perl = TRUE)) {
          ""
        } else {
          " "
        }
        out_lines[[idx]] <- paste0(out_lines[[idx]], sep, trail)
      }
    }
    cursor <- expr_end + 1L
  }
  if (cursor <= length(lines)) {
    out_lines <- c(out_lines, lines[seq.int(cursor, length(lines))])
  }
  writeLines(text = out_lines, con = path)
  cli::cli_alert_success("Made function arguments explicit in {.file {path}}")
  invisible(NULL)
}


# ---- Inline comment capture -------------------------------------------------

#' Extract trailing inline comments from source lines.
#'
#' Returns a named list: line_number (character) -> trailing comment text
#' (including the \code{#} and leading whitespace). Only lines that have
#' non-whitespace code before the first \code{#} are captured (i.e., full-line
#' comments are excluded).
#' @keywords internal
.mfae_capture_inline_comments <- function(lines) {
  result <- list()
  for (i in seq_along(lines)) {
    line <- lines[[i]]
    hash_pos <- regexpr(pattern = "#", text = line, fixed = TRUE)
    if (hash_pos == -1L) {
      next
    }
    before_hash <- substr(x = line, start = 1L, stop = hash_pos - 1L)
    if (grepl(pattern = "\\S", x = before_hash, perl = TRUE)) {
      result[[as.character(i)]] <- substr(
        x = line,
        start = hash_pos,
        stop = nchar(x = line)
      )
    }
  }
  result
}


# ---- Recursive expression tree walker ---------------------------------------

#' Walk an expression object (vector of top-level expressions)
#' @keywords internal
.mfae_walk_expr <- function(expr, skip_fns = NULL) {
  if (!is.expression(expr)) {
    return(.mfae_walk(expr = expr, skip_fns = skip_fns))
  }
  as.expression(
    x = lapply(X = seq_along(expr), FUN = function(i) {
      .mfae_walk(expr = expr[[i]], skip_fns = skip_fns)
    })
  )
}

#' Main recursive walker: dispatch per expression type
#' @keywords internal
.mfae_walk <- function(expr, skip_fns = NULL) {
  if (is.symbol(expr) || is.atomic(expr) || is.pairlist(expr)) {
    return(expr)
  }
  if (!is.call(expr)) {
    return(expr)
  }

  op <- if (is.symbol(expr[[1L]])) as.character(expr[[1L]]) else NULL
  if (is.null(op)) {
    return(.mfae_walk_children(expr = expr, skip_fns = skip_fns))
  }

  if (
    grepl(pattern = "^%.*%$", x = op) || op %in% c(.mfae_skipped_ops, skip_fns)
  ) {
    return(.mfae_walk_children(expr = expr, skip_fns = skip_fns))
  }

  .mfae_transform_call(expr = expr, skip_fns = skip_fns)
}


#' Operators and special forms that are never transformed
#' @keywords internal
.mfae_skipped_ops <- c(
  "+",
  "-",
  "*",
  "/",
  "^",
  "%%",
  "%/%",
  "|",
  "||",
  "&",
  "&&",
  ">",
  ">=",
  "<",
  "<=",
  "==",
  "!=",
  "!",
  "$",
  "@",
  "[",
  "[[",
  "{",
  "(",
  "if",
  "for",
  "while",
  "repeat",
  "function",
  "return",
  "<-",
  "<<-",
  "=",
  "::",
  ":::"
)


# ---- Call transformation ----------------------------------------------------

#' Try to transform a single call expression
#'
#' Resolves the function definition, matches arguments to formals, then
#' recursively walks the matched call's children.
#' @keywords internal
.mfae_transform_call <- function(expr, skip_fns = NULL) {
  fn <- .mfae_resolve_function(fun_expr = expr[[1L]])
  if (is.null(fn)) {
    return(.mfae_walk_children(expr = expr, skip_fns = skip_fns))
  }

  fmls <- formals(fun = fn)
  if (is.null(fmls)) {
    return(.mfae_walk_children(expr = expr, skip_fns = skip_fns))
  }

  matched <- if (!is.primitive(x = fn)) {
    tryCatch(
      expr = match.call(definition = fn, call = expr, expand.dots = TRUE),
      error = function(e) NULL
    )
  } else {
    .mfae_match_args(expr = expr, fmls = fmls)
  }

  if (is.null(matched)) {
    return(.mfae_walk_children(expr = expr, skip_fns = skip_fns))
  }

  .mfae_walk_children(expr = matched, skip_fns = skip_fns)
}

#' Recursively walk children without changing the call head
#' @keywords internal
.mfae_walk_children <- function(expr, skip_fns = NULL) {
  new_args <- lapply(X = seq_along(expr)[-1L], FUN = function(i) {
    .mfae_walk(expr = expr[[i]], skip_fns = skip_fns)
  })
  names(new_args) <- names(expr)[-1L]
  as.call(c(list(expr[[1L]]), new_args))
}


# ---- Function resolution ----------------------------------------------------

.mfae_resolve_function <- function(fun_expr) {
  # pkg::fun / pkg:::fun
  if (is.call(fun_expr) && length(fun_expr) >= 3L) {
    op <- as.character(fun_expr[[1L]])
    if (op %in% c("::", ":::")) {
      pkg <- as.character(fun_expr[[2L]])
      name <- as.character(fun_expr[[3L]])
      return(tryCatch(
        expr = get(x = name, envir = asNamespace(ns = pkg), mode = "function"),
        error = function(e) NULL
      ))
    }
    return(NULL)
  }

  # Simple symbol — try caller scope then base
  if (is.symbol(fun_expr)) {
    name <- as.character(fun_expr)
    fn <- tryCatch(
      expr = get(x = name, envir = parent.frame(), mode = "function"),
      error = function(e) NULL
    )
    if (!is.null(fn)) {
      return(fn)
    }
    return(tryCatch(
      expr = get(x = name, envir = baseenv(), mode = "function"),
      error = function(e) NULL
    ))
  }

  NULL
}


# ---- Manual matching for primitives -----------------------------------------

.mfae_match_args <- function(expr, fmls) {
  args <- as.list(x = expr)[-1L]
  arg_nms <- names(args) %||% rep("", length(args))

  fml_nms <- names(fmls)
  has_dots <- any(fml_nms == "...")
  fml_nms_no_dots <- setdiff(x = fml_nms, y = "...")

  result_args <- list()
  result_nms <- character()
  matched <- character()

  # Phase 1: named arguments — keep their names
  for (i in which(x = nzchar(arg_nms))) {
    nm <- arg_nms[[i]]
    if (nm %in% fml_nms_no_dots) {
      matched <- c(matched, nm)
    }
    result_args <- c(result_args, list(args[[i]]))
    result_nms <- c(result_nms, nm)
  }

  # Phase 2: positional arguments — fill remaining unmatched formals
  pos_idx <- which(x = !nzchar(arg_nms))
  remaining <- setdiff(x = fml_nms_no_dots, y = matched)

  for (i in pos_idx) {
    if (length(remaining) > 0L) {
      nm <- remaining[[1L]]
      remaining <- remaining[-1L]
      result_args <- c(result_args, list(args[[i]]))
      result_nms <- c(result_nms, nm)
    } else if (has_dots) {
      result_args <- c(result_args, list(args[[i]]))
      result_nms <- c(result_nms, "")
    } else {
      result_args <- c(result_args, list(args[[i]]))
      result_nms <- c(result_nms, "")
    }
  }

  names(result_args) <- result_nms
  as.call(c(list(expr[[1L]]), result_args))
}
