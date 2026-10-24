#' Check the format of a custom standalone file
#'
#' Checks a standalone file against the layout used by r-lib/rlang
#' (as consumed by [usethis::use_standalone()]). Three points are checked:
#' 1. the header format, and whether each slot has a value;
#' 2. every documented function carries `@noRd` (undocumented functions are
#'    skipped);
#' 3. a `# nocov start` marker exists and precedes all functions
#'    (`# nocov end` is optional).
#'
#' Each check point that reports nothing is announced as a success. Warnings and
#' notes never stop the run, but an error does: the remaining check points are
#' then skipped.
#'
#' Results are printed in the style of `devtools::check()`.
#'
#' @param path Path to the standalone file (a single string).
#' @param ... Unused
#'
#' @return Invisibly, `list(error = , warning = , note = )`, where each element
#'   is an integer.
#' @export
#' @examples
#' \dontrun{
#' check_standalone("R/standalone-purrr.R")
#' }
check_standalone <- function(path = NULL, ...) {
  rlang::check_dots_empty()
  path <- path %||%
    if (rstudioapi::isAvailable()) rstudioapi::getActiveDocumentContext()$path
  if (is.null(path) || !nzchar(path)) {
    cli::cli_abort(c("x" = "{.arg path} is required"))
  }
  if (!file.exists(path) || dir.exists(path)) {
    cli::cli_abort(c("x" = "{.arg path} is not a file"))
  }

  # ---- Run checks -----------------------------------------------------------
  cli::cat_rule(
    left = "standalone check results",
    right = basename(path),
    col = "cyan"
  )

  start <- Sys.time()
  lines <- readLines(path)

  # One entry per check point. Warnings and notes never stop the run; an error
  # does, so the checks that follow are skipped.
  checks <- list(
    "header format" = function() .cs_header(lines, path),
    "@noRd in docs" = function() .cs_noRd(lines),
    "nocoverage start marker" = function() .cs_nocov(lines)
  )

  results <- imap(checks, function(val, name) {
    res <- val()
    if (res$warning == 0L && res$note == 0L && res$error == 0L) {
      inform_success(name)
    }
    res
  })

  summary_by_type <- function(results, type) {
    sum(unlist(lapply(results, base::`[[`, type))) %||%
      integer()
  }

  results_by_type <- list(
    error = summary_by_type(results, "error"),
    warning = summary_by_type(results, "warning"),
    note = summary_by_type(results, "note")
  )
  elapsed <- difftime(Sys.time(), start, units = "secs")

  .cs_report(elapsed = elapsed, results_by_type = results_by_type)

  invisible(results_by_type)
}


# ---- Internal checks (one per check point) ----------------------------------

.cs_new_result <- function() {
  list(error = 0L, warning = 0L, note = 0L)
}

# Check 1: header format and slot values
.cs_header <- function(lines, path = NA_character_) {
  res <- .cs_new_result()
  marker <- "^#\\s*---\\s*$"

  if (!length(lines) || !grepl(marker, lines[1L])) {
    res$error <- res$error + 1L
    inform_error("Line 1 must be the header opening marker `# ---`.")
    return(res)
  }
  ends <- grep(marker, lines)
  ends <- ends[ends > 1L]
  if (!length(ends)) {
    res$error <- res$error + 1L
    inform_error("The header has no closing marker `# ---`.")
    return(res)
  }
  end <- ends[1L]
  # Header body: everything between the two markers
  body <- lines[seq_len(end - 1L)][-1L]
  line_no <- seq_along(body) + 1L

  # Parse `# key: value` lines
  slots <- list()
  for (i in seq_along(body)) {
    txt <- body[i]
    if (grepl("^#\\s*$", txt)) {
      next
    }
    m <- regmatches(
      txt,
      regexec(
        "^#\\s*([A-Za-z][A-Za-z0-9_-]*)\\s*:\\s*(.*?)\\s*$",
        txt,
        perl = TRUE
      )
    )[[1L]]
    if (length(m) != 3L) {
      res$warning <- res$warning + 1L
      inform_warn(sprintf(
        "Line %d doesn't follow the `# key: value` format: %s",
        line_no[i],
        txt
      ))
      next
    }
    key <- m[2L]
    if (key %in% names(slots)) {
      res$warning <- res$warning + 1L
      inform_warn(sprintf("Line %d: slot `%s` is duplicated.", line_no[i], key))
      next
    }
    slots[[key]] <- m[3L]
  }

  required <- c("repo", "file", "last-updated", "license")
  optional <- "imports"

  # Required slots must exist and have a value
  for (key in required) {
    if (!key %in% names(slots)) {
      res$error <- res$error + 1L
      inform_error(sprintf(
        "The header is missing the required slot `%s`.",
        key
      ))
    } else if (!nzchar(slots[[key]])) {
      res$error <- res$error + 1L
      inform_error(sprintf("The header slot `%s` has no value.", key))
    }
  }
  # `imports` is optional, but must not be present and empty
  if ("imports" %in% names(slots) && !nzchar(slots[["imports"]])) {
    res$note <- res$note + 1L
    inform_note(
      "The header slot `imports` is empty; remove it if there are no dependencies."
    )
  }
  # Unknown slots
  unknown <- setdiff(names(slots), c(required, optional))
  if (length(unknown)) {
    res$note <- res$note + 1L
    inform_note(sprintf(
      "The header has non-standard slots: %s.",
      paste0("`", unknown, "`", collapse = ", ")
    ))
  }

  # Per-slot value checks (only for slots that are present and non-empty)
  val <- function(key) {
    if (key %in% names(slots) && nzchar(slots[[key]])) slots[[key]] else NULL
  }

  if (
    !is.null(v <- val("repo")) && !grepl("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", v)
  ) {
    res$warning <- res$warning + 1L
    inform_warn(sprintf("`repo` should look like `owner/repo`, got: %s", v))
  }
  if (!is.null(v <- val("file"))) {
    if (!grepl("\\.[Rr]$", v)) {
      res$warning <- res$warning + 1L
      inform_warn(sprintf("`file` should end in `.R`, got: %s", v))
    }
    # usethis::use_standalone() saves the file as `import-<file>`
    if (!is.na(path) && !basename(path) %in% c(v, paste0("import-", v))) {
      res$note <- res$note + 1L
      inform_note(sprintf(
        "`file` is `%s`, which doesn't match the actual file name `%s`.",
        v,
        basename(path)
      ))
    }
  }
  if (!is.null(v <- val("last-updated"))) {
    d <- if (grepl("^\\d{4}-\\d{2}-\\d{2}$", v)) {
      as.Date(v, format = "%Y-%m-%d")
    } else {
      NA
    }
    if (is.na(d)) {
      res$error <- res$error + 1L
      inform_error(sprintf(
        "`last-updated` must be a valid YYYY-MM-DD date, got: %s",
        v
      ))
    } else if (d > Sys.Date()) {
      res$warning <- res$warning + 1L
      inform_warn(sprintf("`last-updated` is in the future: %s", v))
    }
  }
  if (!is.null(v <- val("license")) && !grepl("^https?://", v)) {
    res$note <- res$note + 1L
    inform_note(sprintf(
      "`license` is best given as a URL (e.g. https://unlicense.org), got: %s",
      v
    ))
  }

  res
}

# Check 2: documented functions must carry @noRd
.cs_noRd <- function(lines) {
  res <- .cs_new_result()
  fns <- .cs_find_functions(lines)
  if (inherits(fns, "error")) {
    res$error <- res$error + 1L
    inform_error(paste0(
      "Can't parse the file, check skipped: ",
      conditionMessage(fns)
    ))
    return(res)
  }
  if (!length(fns$name)) {
    res$note <- res$note + 1L
    inform_note("No top-level function definitions found.")
  }

  for (i in seq_along(fns$name)) {
    doc <- .cs_get_doc(lines, fns$line[i])
    if (!length(doc)) {
      next
    } # no documentation: skip
    if (!any(grepl("@noRd\\b", doc))) {
      res$error <- res$error + 1L
      inform_error(sprintf(
        "`%s` (line %d) is documented but has no `@noRd` tag.",
        fns$name[i],
        fns$line[i]
      ))
    }
  }
  res
}

# Check 3: `# nocov, start` must exist and precede all functions
# (`# nocov, end` is optional and not checked)
.cs_nocov <- function(lines) {
  res <- .cs_new_result()
  fns <- .cs_find_functions(lines)
  if (inherits(fns, "error")) {
    res$error <- res$error + 1L
    inform_error(paste0(
      "Can't parse the file, check skipped: ",
      conditionMessage(fns)
    ))
    return(res)
  }

  starts <- grep("^\\s*#\\s*nocov\\s+start\\b", lines)
  if (!length(starts)) {
    res$error <- res$error + 1L
    inform_error(paste0("Can't find a `# nocov", " start` marker."))
    return(res)
  }
  first <- starts[1L]
  early <- which(fns$line < first)
  if (length(early)) {
    res$error <- res$error + 1L
    inform_error(sprintf(
      paste0("Functions found before `# nocov", " start` (line %d): %s."),
      first,
      paste0(
        "`",
        fns$name[early],
        "` (line ",
        fns$line[early],
        ")",
        collapse = ", "
      )
    ))
  }
  res
}


# ---- Internal helpers -------------------------------------------------------

# Find top-level function definitions: `name <- function(...)` or
# `name <- \(...)`. Returns list(name, line), or the parse error.
.cs_find_functions <- function(lines) {
  exprs <- tryCatch(
    parse(text = lines, keep.source = TRUE),
    error = function(e) e
  )
  if (inherits(exprs, "error")) {
    return(exprs)
  }

  refs <- attr(exprs, "srcref")
  fn_names <- character()
  fn_lines <- integer()
  for (i in seq_along(exprs)) {
    e <- exprs[[i]]
    # `\(x)` lambdas are parsed to the same `function` call as `function(x)`
    is_def <- is.call(e) &&
      length(e) == 3L &&
      is.symbol(e[[1L]]) &&
      as.character(e[[1L]]) %in% c("<-", "=", "<<-") &&
      is.call(e[[3L]]) &&
      identical(e[[3L]][[1L]], as.name("function"))
    if (!is_def) {
      next
    }
    lhs <- e[[2L]]
    nm <- if (is.symbol(lhs) || is.character(lhs)) {
      as.character(lhs)
    } else {
      deparse(lhs)[1L]
    }
    fn_names <- c(fn_names, nm)
    fn_lines <- c(fn_lines, as.integer(refs[[i]][1L]))
  }
  list(name = fn_names, line = fn_lines)
}

# Get the roxygen block (`#'` lines) directly above a function
.cs_get_doc <- function(lines, fn_line) {
  j <- fn_line - 1L
  while (j >= 1L && grepl("^\\s*#'", lines[j])) {
    j <- j - 1L
  }
  if (j + 1L > fn_line - 1L) {
    return(character())
  }
  lines[(j + 1L):(fn_line - 1L)]
}

.cs_report <- function(elapsed, results_by_type) {
  cli::cat_line()
  cli::cat_line("Duration: ", format(round(as.numeric(elapsed), 2)), "s")
  cli::cat_line()

  final_line_paint <- function(value = integer(), name = character()) {
    t <- cli_symbol$tick
    x <- cli_symbol$cross

    if (value == 0) {
      return(cli::col_green(paste(value, name, t)))
    }
    label <- if (value == 1L) {
      paste(value, name, x)
    } else {
      paste(value, paste0(name, "s"), x)
    }
    if (name == "note") cli::col_blue(label) else cli::col_red(label)
  }

  symbol_error <- final_line_paint(results_by_type$error, "error")
  symbol_warn <- final_line_paint(results_by_type$warning, "warning")
  symbol_note <- final_line_paint(results_by_type$note, "note")

  cli::cli_text(symbol_error, " | ", symbol_warn, " | ", symbol_note)
  invisible(NULL)
}

inform_warn <- function(message, ...) {
  cli::cli_text(
    cli::col_magenta(paste(
      cli_symbol$pointer,
      " ",
      message,
      "... WARNING"
    )),
    ...
  )
  cli::cat_line()
}

inform_error <- function(message, ...) {
  cli::cli_text(
    cli::col_red(paste(
      cli_symbol$pointer,
      " ",
      message,
      "... ERROR"
    )),
    ...
  )
  cli::cat_line()
}

inform_note <- function(message, ...) {
  cli::cli_text(
    cli::col_blue(paste(
      cli_symbol$pointer,
      " ",
      message,
      "... NOTE"
    )),
    ...
  )
  cli::cat_line()
}

inform_success <- function(message, ...) {
  cli::cli_alert_success(
    cli::col_grey(
      message
    ),
    ...
  )
}
