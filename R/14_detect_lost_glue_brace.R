#' Detect Lost Glue Brace in `glue` and `cli` Expressions
#'
#' @description
#' Check whether `{` and `}` are balanced in all `glue()` / `glue_data()`
#' and `cli_*()` string arguments within an R file. The file is parsed into
#' an AST, then each string literal that is an argument to a target function
#' is checked with a stack-based brace matcher. Any mismatches are reported
#' with line number and a visual caret (`^^^^`) marker under the problematic
#' region.
#'
#' @param path A character string specifying the path to the R file to inspect.
#'   If `NULL` and RStudio is available, the currently active document path is used.
#'
#' @return Invisibly returns `TRUE` if all expressions are balanced, `FALSE`
#'   otherwise. Side-effect messages are emitted via [cli].
#'
#' @examples
#' \donttest{
#' file <- tempfile()
#' writeLines("glue(\"{a\")", file)
#' detect_lost_glue_brace(file)
#' }
#'
#' @export
detect_lost_glue_brace <- function(path = NULL) {
  path <- path %||% rstudioapi::getActiveDocumentContext()$path
  lines <- readLines(path, warn = FALSE)
  text <- paste(lines, collapse = "\n")
  exprs <- parse_safely(text, path)
  parse_data <- utils::getParseData(exprs)

  strings_info <- find_glue_cli_strings(parse_data)

  if (length(strings_info) == 0L) {
    cli::cli_alert_success("No need to fix")
    return(invisible(TRUE))
  }

  error_lines <- integer()

  for (info in strings_info) {
    result <- check_brace_balance(info$content)

    if (!result$balanced) {
      error_lines <- c(error_lines, info$line1)

      message(
        format_brace_error(
          line_content = lines[info$line1],
          str_content = info$content,
          line_num = info$line1,
          col_offset = info$col1,
          result = result
        )
      )
    }
  }

  if (length(error_lines) == 0L) {
    cli::cli_alert_success("No need to fix")
    invisible(TRUE)
  } else {
    cli::cli_alert_danger(
      "Found {length(error_lines)} line{?s} with mismatched braces: {.val {error_lines}}"
    )
    invisible(FALSE)
  }
}


# ---------------------------------------------------------------------------
# Helper: parse source text safely
# ---------------------------------------------------------------------------
parse_safely <- function(text, path) {
  tryCatch(
    parse(text = text, keep.source = TRUE),
    error = function(e) cli::cli_abort("Could not parse {.path {path}}.")
  )
}

# ---------------------------------------------------------------------------
# Find all string literals inside glue / cli function calls
#
# Walks the AST parse data recursively: for each SYMBOL_FUNCTION_CALL whose
# name starts with "glue", "glue_data", or "cli_", we climb up to the
# enclosing call expression and recursively collect every descendant
# STR_CONST token.
# ---------------------------------------------------------------------------
find_glue_cli_strings <- function(parse_data) {
  target_calls <- parse_data[
    parse_data$token == "SYMBOL_FUNCTION_CALL" &
      grepl("^(glue|glue_data|cli_)", parse_data$text),
  ]

  if (nrow(target_calls) == 0L) {
    return(list())
  }

  parent_map <- stats::setNames(parse_data$parent, parse_data$id)

  # Recursively collect STR_CONST tokens under a given node
  collect_str_descendants <- function(node_id) {
    children <- parse_data[parse_data$parent == node_id, ]
    result <- list()
    for (j in seq_len(nrow(children))) {
      if (children$token[j] == "STR_CONST") {
        result <- c(
          result,
          list(list(
            id = children$id[j],
            line1 = children$line1[j],
            col1 = children$col1[j],
            text = children$text[j]
          ))
        )
      }
      result <- c(result, collect_str_descendants(children$id[j]))
    }
    result
  }

  str_list <- list()
  seen_ids <- integer()

  for (k in seq_len(nrow(target_calls))) {
    # SYMBOL_FUNCTION_CALL's parent is the function-ref sub-expression
    # (e.g. "glue::glue" as a whole); its grandparent is the actual call
    # expression that contains both the function reference and arguments.
    func_ref_parent <- target_calls$parent[k]
    call_expr_id <- parent_map[[as.character(func_ref_parent)]]
    if (is.na(call_expr_id) || call_expr_id <= 0) {
      next
    }

    desc_strs <- collect_str_descendants(call_expr_id)
    for (s in desc_strs) {
      if (!(s$id %in% seen_ids)) {
        s$content <- substr(s$text, 2L, nchar(s$text) - 1L)
        str_list <- c(str_list, list(s))
        seen_ids <- c(seen_ids, s$id)
      }
    }
  }

  str_list
}

# ---------------------------------------------------------------------------
# Check brace balance with a stack-based scan
#
# Scans the string character by character. Every `{` pushes its position,
# every `}` pops (if the stack is non-empty) or is recorded as extra.
#
# Returns a list:
#   $balanced        - logical
#   $unmatched_opens - integer vector of positions of unmatched `{`
#   $unmatched_closes- integer vector of positions of unmatched `}`
#   $hl_start        - content position where the highlight region begins
#   $hl_end          - content position where the highlight region ends
# ---------------------------------------------------------------------------
check_brace_balance <- function(s) {
  stack <- integer() # positions of pending `{`
  extra_closes <- integer() # positions of unmatched `}`

  chars <- strsplit(s, NULL)[[1L]]

  for (i in seq_along(chars)) {
    if (chars[i] == "{") {
      stack <- c(stack, i)
    } else if (chars[i] == "}") {
      if (length(stack) > 0L) {
        stack <- stack[-length(stack)]
      } else {
        extra_closes <- c(extra_closes, i)
      }
    }
  }

  balanced <- length(stack) == 0L && length(extra_closes) == 0L

  # Determine the highlight region
  if (balanced) {
    hl_start <- hl_end <- NA_integer_
  } else if (length(stack) > 0L && length(extra_closes) > 0L) {
    # Both missing and extra braces: highlight from the first unmatched `{`
    # to the first extra `}` that follows it.
    first_open <- min(stack)
    first_extra_close <- extra_closes[extra_closes > first_open][1L]
    if (is.na(first_extra_close)) {
      first_extra_close <- max(extra_closes)
    }
    hl_start <- first_open
    hl_end <- first_extra_close
  } else if (length(stack) > 0L) {
    # Only missing closing braces: highlight from the first unmatched `{`
    # to the end of the string.
    hl_start <- min(stack)
    hl_end <- nchar(s)
  } else {
    # Only extra closing braces: highlight from the immediately preceding
    # `{` to the first extra `}` — the broken cli/glue expression fragment.
    first_extra <- extra_closes[1L]
    prev_brace <- find_nearest_open_before(s, first_extra)
    hl_start <- if (is.na(prev_brace)) first_extra else prev_brace
    hl_end <- first_extra
  }

  list(
    balanced = balanced,
    unmatched_opens = stack,
    unmatched_closes = extra_closes,
    hl_start = hl_start,
    hl_end = hl_end
  )
}

# ---------------------------------------------------------------------------
# Walk backward from position `pos` to find the nearest `{` in string `s`.
# Returns NA_integer_ if none is found.
# ---------------------------------------------------------------------------
find_nearest_open_before <- function(s, pos) {
  chars <- strsplit(s, NULL)[[1L]]
  for (i in seq(pos - 1L, 1L)) {
    if (chars[i] == "{") return(i)
  }
  NA_integer_
}

# ---------------------------------------------------------------------------
# Format a visual error message for a brace mismatch
#
# Produces output like:
#
#   "Hello, {name!"
#           ^^^^^^
#
# The top line is the original source line, the second line has `^` markers
# aligned under the problematic region.
# ---------------------------------------------------------------------------
format_brace_error <- function(
  line_content,
  str_content,
  line_num,
  col_offset,
  result
) {
  hl_start <- result$hl_start
  hl_end <- result$hl_end

  # Map highlight region (1-indexed within str_content) to line columns.
  # col_offset is the column of the opening quote `"` or `'`.
  #   str_content[1]  -> line column col_offset + 1
  #   str_content[i]  -> line column col_offset + i
  line_hl_start <- col_offset + hl_start
  line_hl_end <- col_offset + hl_end

  # Build the caret line
  caret_line <- paste0(
    strrep(" ", line_hl_start - 1L),
    strrep("^", line_hl_end - line_hl_start + 1L)
  )

  paste0(line_content, "\n", caret_line)
}
