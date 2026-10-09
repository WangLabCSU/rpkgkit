#' Make Function Arguments Explicit
#'
#' @description
#' Transform function calls in R source code so that all arguments are passed
#' with explicit parameter names.
#'
#' The transformation is a minimal, position-based text edit: only the missing
#' \code{argument = } prefixes are inserted into the original source. Everything
#' else is preserved verbatim, including comments inside function bodies, blank
#' lines, indentation and operator spacing.
#'
#' If the function has a \code{...} formal, positional arguments that are
#' captured by \code{...} are left in place as-is. Calls that forward
#' \code{...} literally (e.g. \code{g(...)}) are skipped, because the number of
#' arguments that \code{...} expands to cannot be known statically.
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
#' # vapply(X = 1:9, FUN = function(x) x*2, FUN.VALUE = numeric(length = 1))
#' }
#'
#' @export
make_func_arg_explicit <- function(path = NULL, skip_functions = NULL, ...) {
  rlang::check_dots_empty()
  path <- path %||% rstudioapi::getActiveDocumentContext()$path
  lines <- readLines(con = path, warn = FALSE)
  exprs <- suppressWarnings(
    parse(text = paste(lines, collapse = "\n"), keep.source = TRUE)
  )
  if (length(exprs) == 0L) {
    cli::cli_abort("No R expressions found in {.file {path}}.")
  }

  edits <- .mfae_plan_edits(exprs = exprs, skip_fns = skip_functions)
  writeLines(
    text = .mfae_apply_edits(lines = lines, edits = edits),
    con = path
  )
  cli::cli_alert_success("Made function arguments explicit in {.file {path}}")
  invisible(NULL)
}


# ---- Position-based edit planning -------------------------------------------
#
# The transformation never regenerates code from the parse tree (which would
# drop comments and reformat the file). Instead it records the exact source
# position of every argument that is still unnamed and inserts the missing
# `argument = ` prefix there. Nothing is ever removed or rewritten, so all
# comments and formatting survive untouched.

#' Plan the insertions that make function arguments explicit
#'
#' Returns a list of insertions, each a list with \code{line}, \code{col} and
#' \code{text}, describing an \code{argument = } prefix to insert at that source
#' position.
#' @keywords internal
.mfae_plan_edits <- function(exprs, skip_fns = NULL) {
  parse_data <- utils::getParseData(exprs)
  if (is.null(parse_data) || nrow(parse_data) == 0L) {
    return(list())
  }

  pd <- .mfae_parse_data(parse_data)
  skip_fns <- skip_fns %||% character(0L)

  edits <- list()
  for (id in pd$id[pd$token == "expr"]) {
    kids <- .mfae_children(pd, id)
    # A call looks like `f(...)`: an expression head followed by `(`. Control
    # flow (`if`, `for`, ...), `function`, `{` and grouping `(` put a keyword or
    # a `(` token first, so they can never match.
    if (length(kids) < 2L || pd$token[[kids[[1L]]]] != "expr") {
      next
    }
    if (!any(pd$token[kids] == "'('")) {
      next
    }

    callee <- .mfae_callee(pd, kids[[1L]])
    if (is.null(callee)) {
      next
    }
    if (callee$name %in% skip_fns) {
      next
    }
    if (callee$name %in% .mfae_operators || grepl("^%.*%$", callee$name)) {
      next
    }

    fn <- .mfae_resolve_function(callee$expr)
    if (is.null(fn)) {
      next
    }
    fmls <- formals(fn)
    if (is.null(fmls)) {
      next
    }

    slots <- .mfae_arg_slots(pd, kids)
    if (length(slots) == 0L) {
      next
    }
    # `g(...)` expands to an unknown number of arguments, so positional
    # matching is impossible — leave the whole call alone.
    if (any(vapply(slots, function(s) isTRUE(s$dots), logical(1L)))) {
      next
    }

    arg_names <- vapply(slots, function(s) s$name, character(1L))
    wanted <- .mfae_assign_arg_names(arg_names, names(fmls))

    for (i in seq_along(slots)) {
      if (nzchar(arg_names[[i]]) || !nzchar(wanted[[i]])) {
        next
      }
      if (is.na(slots[[i]]$line)) {
        next
      }
      edits[[length(edits) + 1L]] <- list(
        line = as.numeric(slots[[i]]$line),
        col = as.numeric(slots[[i]]$col),
        text = paste0(wanted[[i]], " = ")
      )
    }
  }
  edits
}


#' Flatten parse data into the lookup structure used by the edit planner
#'
#' The planner reads the same handful of parse-data fields over and over, so
#' they are extracted once into plain vectors — indexing a data.frame costs a
#' dispatch per column. Children are reached through a hashed environment keyed
#' by parent id and return row indices into those vectors. A list or data.frame
#' keyed by name would not do: \code{[[} by name scans linearly, which turns
#' planning a single large file quadratic.
#'
#' Rows are reordered into source order first, because that order is what maps
#' a call's child tokens onto its arguments.
#' @keywords internal
.mfae_parse_data <- function(parse_data) {
  parse_data <- parse_data[
    order(
      parse_data$line1,
      parse_data$col1,
      -parse_data$line2,
      -parse_data$col2
    ),
    ,
    drop = FALSE
  ]
  pd <- list(
    line1 = parse_data$line1,
    col1 = parse_data$col1,
    id = parse_data$id,
    parent = parse_data$parent,
    token = parse_data$token,
    text = parse_data$text
  )
  pd$children <- list2env(
    split(seq_len(nrow(parse_data)), as.character(parse_data$parent)),
    hash = TRUE,
    parent = emptyenv()
  )
  pd
}


#' Direct children of a parse-data node
#'
#' \code{pd} is the structure built by \code{.mfae_parse_data()}. Returns the
#' rows of \code{pd} that are direct children of node \code{id}, in source
#' order.
#' @keywords internal
.mfae_children <- function(pd, id) {
  get0(as.character(id), envir = pd$children, ifnotfound = integer(0L))
}


#' Resolve the callee of a call from its head parse-data row
#'
#' Returns \code{NULL} when the head is not a plain function name (for example
#' an anonymous function, a grouping parenthesis, or the result of another
#' call). Otherwise returns the bare name plus the equivalent language object,
#' which \code{.mfae_resolve_function()} can resolve.
#' @keywords internal
.mfae_callee <- function(pd, head_row) {
  head_kids <- .mfae_children(pd, pd$id[[head_row]])
  tokens <- pd$token[head_kids]
  n <- length(head_kids)
  simple <- n == 1L && tokens[[1L]] == "SYMBOL_FUNCTION_CALL"
  qualified <- n == 3L &&
    tokens[[1L]] == "SYMBOL_PACKAGE" &&
    tokens[[2L]] %in% c("NS_GET", "NS_GET_INT") &&
    tokens[[3L]] == "SYMBOL_FUNCTION_CALL"
  if (!simple && !qualified) {
    return(NULL)
  }

  text <- pd$text[head_kids]
  name <- text[[if (simple) 1L else 3L]]
  expr <- tryCatch(
    str2lang(paste0(text, collapse = "")),
    error = function(e) NULL
  )
  if (is.null(expr)) {
    return(NULL)
  }
  list(name = gsub("^`|`$", "", name), expr = expr)
}


#' Split a call node's children into its argument slots
#'
#' Each slot records the argument's name (empty when positional), the source
#' position of its first token, and whether it is a literal \code{...}.
#'
#' Named arguments appear as three sibling tokens (\code{SYMBOL_SUB},
#' \code{EQ_SUB}, \code{expr}) rather than one wrapping expression. Empty
#' arguments (\code{f(a, , b)}) produce no token at all — only an extra
#' \code{,} — which is why slots are accumulated per comma so that positional
#' matching still lines up with R's.
#' @keywords internal
.mfae_arg_slots <- function(pd, kids) {
  tokens <- pd$token[kids]
  open_i <- which(tokens == "'('")
  close_i <- which(tokens == "')'")
  if (length(open_i) == 0L || length(close_i) == 0L) {
    return(list())
  }
  open_i <- open_i[[1L]]
  close_i <- max(close_i)
  if (close_i <= open_i + 1L) {
    return(list()) # f()
  }

  new_slot <- function() {
    list(
      name = "",
      line = NA_real_,
      col = NA_real_,
      dots = FALSE,
      filled = FALSE
    )
  }

  slots <- list()
  cur <- new_slot()
  saw_comma <- FALSE
  j <- open_i + 1L
  while (j < close_i) {
    token <- tokens[[j]]
    if (token == "','") {
      slots[[length(slots) + 1L]] <- cur
      cur <- new_slot()
      saw_comma <- TRUE
      j <- j + 1L
    } else if (token == "SYMBOL_SUB") {
      cur$name <- gsub("^`|`$", "", pd$text[[kids[[j]]]])
      cur$filled <- TRUE
      j <- j + 1L
      if (j < close_i && tokens[[j]] == "EQ_SUB") {
        j <- j + 1L
      }
    } else if (token == "expr") {
      if (!cur$filled) {
        cur$line <- as.numeric(pd$line1[[kids[[j]]]])
        cur$col <- as.numeric(pd$col1[[kids[[j]]]])
      }
      cur$filled <- TRUE
      if (.mfae_is_dots(pd, kids[[j]])) {
        cur$dots <- TRUE
      }
      j <- j + 1L
    } else {
      j <- j + 1L
    }
  }
  if (saw_comma || cur$filled) {
    slots[[length(slots) + 1L]] <- cur
  }
  slots
}


#' Is this node a literal \code{...}?
#'
#' \code{row} is the row of the expression node to inspect.
#' @keywords internal
.mfae_is_dots <- function(pd, row) {
  kids <- .mfae_children(pd, pd$id[[row]])
  length(kids) == 1L && pd$token[kids] == "SYMBOL" && pd$text[kids] == "..."
}


#' Apply planned insertions to the source lines
#'
#' Insertions on the same line are applied right to left so that earlier
#' positions stay valid.
#' @keywords internal
.mfae_apply_edits <- function(lines, edits) {
  if (length(edits) == 0L) {
    return(lines)
  }
  for (ln in unique(vapply(edits, `[[`, numeric(1L), "line"))) {
    on_line <- Filter(function(e) e$line == ln, edits)
    on_line <- on_line[
      order(vapply(on_line, `[[`, numeric(1L), "col"), decreasing = TRUE)
    ]
    line <- lines[[ln]]
    for (e in on_line) {
      at <- .mfae_char_index(line, e$col)
      line <- paste0(
        substr(line, 1L, at - 1L),
        e$text,
        substr(line, at, nchar(line))
      )
    }
    lines[[ln]] <- line
  }
  lines
}


#' Translate a parse-data column into a character index on the source line
#'
#' The parser reports columns with tabs expanded to the next multiple of 8 (so
#' the character after a leading tab is at column 9), while \code{substr()} counts
#' every character as one. Tab-indented lines therefore need this mapping before
#' a parse-data column can be used as a substring index.
#' @keywords internal
.mfae_char_index <- function(line, col) {
  chars <- strsplit(line, "", fixed = TRUE)[[1L]]
  current <- 1
  for (i in seq_along(chars)) {
    if (current >= col) {
      return(i)
    }
    current <- if (chars[[i]] == "\t") {
      current + 8 - ((current - 1) %% 8)
    } else {
      current + 1
    }
  }
  length(chars) + 1L
}


#' Built-in R operators that are never transformed into named-arg calls.
#'
#' These are pure operators/syntax, not control flow. Control flow is excluded
#' structurally: \code{if}, \code{for}, \code{while}, \code{repeat},
#' \code{function}, \code{\{} and \code{(} never look like a
#' \code{name(...)} call node in the parse data, so they need no entry here.
#' @keywords internal
.mfae_operators <- c(
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
  "<-",
  "<<-",
  "=",
  "return",
  "::",
  ":::"
)


# ---- Function resolution ----------------------------------------------------

.mfae_resolve_function <- function(fun_expr) {
  # pkg::fun / pkg:::fun
  if (is.call(fun_expr) && length(fun_expr) >= 3L) {
    op <- as.character(fun_expr[[1L]])
    if (op %in% c("::", ":::")) {
      pkg <- as.character(fun_expr[[2L]])
      name <- as.character(fun_expr[[3L]])
      ns <- tryCatch(asNamespace(ns = pkg), error = function(e) NULL)
      if (is.null(ns)) {
        return(NULL)
      }
      return(get0(x = name, envir = ns, mode = "function"))
    }
    return(NULL)
  }

  # Simple symbol — try caller scope then base. `get0()` returns NULL for both
  # "not found" and "found but not a function", so it replaces the `tryCatch`
  # around `get()` that used to guard every lookup.
  if (is.symbol(fun_expr)) {
    name <- as.character(fun_expr)
    fn <- get0(x = name, envir = parent.frame(), mode = "function")
    if (!is.null(fn)) {
      return(fn)
    }
    return(get0(x = name, envir = baseenv(), mode = "function"))
  }

  NULL
}


# ---- Argument matching ------------------------------------------------------

#' Assign the formal names that positional arguments match
#'
#' Mirrors R's argument matching on names alone, and returns one name per
#' argument \emph{in source order} (empty string when the argument is not
#' matched to a named formal). Named arguments first claim the formal they match
#' (exact, then partial); positional arguments then fill the remaining formals in
#' formal order and stop permanently once \code{...} is reached, since positional
#' matching never reaches formals that follow \code{...}.
#' @keywords internal
.mfae_assign_arg_names <- function(arg_nms, fml_nms) {
  out <- arg_nms
  non_dots <- fml_nms[fml_nms != "..."]
  dots_pos <- if (any(fml_nms == "...")) {
    which(fml_nms == "...")[[1L]]
  } else {
    Inf
  }

  # Named arguments claim their formal (exact match first, then unique prefix)
  consumed <- character(0L)
  for (nm in arg_nms[nzchar(arg_nms)]) {
    hit <- which(non_dots == nm)
    if (length(hit) == 0L) {
      hit <- which(startsWith(non_dots, nm))
      if (length(hit) > 1L) {
        hit <- integer(0L) # ambiguous partial match
      }
    }
    if (length(hit) > 0L) {
      consumed <- c(consumed, non_dots[hit[[1L]]])
    }
  }

  # Positional arguments fill the remaining formals in formal order
  avail <- non_dots[!non_dots %in% consumed]
  avail_pos <- match(avail, fml_nms)
  next_avail <- 1L
  for (i in seq_along(out)) {
    if (nzchar(out[[i]])) {
      next
    }
    if (next_avail > length(avail) || avail_pos[[next_avail]] > dots_pos) {
      next # captured by `...`, or no formal left
    }
    out[[i]] <- avail[[next_avail]]
    next_avail <- next_avail + 1L
  }
  out
}

#' Match a call's arguments to a formals list
#'
#' Kept for callers that work on a language object instead of source positions.
#' Argument order is preserved exactly as written.
#' @keywords internal
.mfae_match_args <- function(expr, fmls) {
  args <- as.list(x = expr)[-1L]
  arg_nms <- names(args) %||% rep("", length(args))
  names(args) <- .mfae_assign_arg_names(arg_nms, names(fmls))
  as.call(c(list(expr[[1L]]), args))
}
