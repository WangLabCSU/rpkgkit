#' @describeIn detect_print_and_cat Scans all \code{.R} files in an R package
#'   (and optionally \code{tests/testthat/}), aggregated with per-file reporting.
#'
#' @export
package_print_and_cat <- function(
  path = NULL,
  test_included = TRUE,
  fix = FALSE,
  ...
) {
  path <- path %||% "."
  path <- normalizePath(path = path, mustWork = FALSE)
  if (!is_pkg(path = path)) {
    cli::cli_abort("{.path {path}} is not an R package (no DESCRIPTION found).")
  }
  files <- list.files(
    path = file.path(path, "R"),
    pattern = "\\.R$",
    full.names = TRUE
  )
  if (test_included) {
    test_dir <- file.path(path, "tests", "testthat")
    if (dir.exists(paths = test_dir)) {
      files <- c(
        files,
        list.files(path = test_dir, pattern = "\\.R$", full.names = TRUE)
      )
    }
  }
  if (length(files) == 0L) {
    cli::cli_alert_info("No {.code .R} files found to scan in {.path {path}}.")
    return(invisible(TRUE))
  }
  cli::cli_alert_info("Scanning {length(files)} file{?s}...")
  file_results <- vector(mode = "list", length = length(files))
  names(file_results) <- basename(path = files)
  for (i in seq_along(files)) {
    file_results[[i]] <- scan_file_print_cat(file = files[i], fix = fix)
  }
  n_ok <- sum(vapply(
    X = file_results,
    FUN = `[[`,
    FUN.VALUE = logical(length = 1L),
    "ok"
  ))
  n_fail <- length(file_results) - n_ok
  if (n_fail == 0L) {
    cli::cli_alert_success(
      "All {n_ok} file{?s} have no {.fn print} or {.fn cat} calls."
    )
    return(invisible(TRUE))
  }
  cli::cli_alert_danger(
    "Found {.fn print}/{.fn cat} calls in {n_fail} of {length(files)} file{?s}:"
  )
  for (i in seq_along(file_results)) {
    res <- file_results[[i]]
    if (res$ok) {
      next
    }
    cli::cli_text("{.strong {names(file_results)[i]}}")
    for (err in res$errors) {
      cli::cli_text("  Line {err$line}:")
      message(paste0("    ", err$caret), sep = "\n")
    }
    cli::cli_text()
  }
  invisible(FALSE)
}


# ---------------------------------------------------------------------------
# Internal: scan a single file for print/cat calls
# ---------------------------------------------------------------------------
scan_file_print_cat <- function(file, fix = FALSE) {
  lines <- readLines(con = file, warn = FALSE)
  text <- paste(lines, collapse = "\n")
  exprs <- parse_safely(text = text, path = file)
  parse_data <- utils::getParseData(exprs)
  calls_info <- find_print_cat_calls(parse_data = parse_data)
  if (length(calls_info) == 0L) {
    return(list(ok = TRUE, file = file, errors = list()))
  }
  if (fix) {
    original_lines <- lines
    call_entries <- Filter(f = function(x) x$type == "call", x = calls_info)
    if (length(call_entries) > 0L) {
      lines_to_fix <- unique(
        x = vapply(
          X = call_entries,
          FUN = `[[`,
          FUN.VALUE = integer(length = 1L),
          "line1"
        )
      )
      for (l in lines_to_fix) {
        lines[l] <- gsub(
          pattern = "\\b(print|cat)\\(",
          replacement = "message(",
          x = lines[l]
        )
      }
      writeLines(text = lines, con = file)
    }
  }
  report_lines <- if (fix) {
    original_lines
  } else {
    lines
  }
  errors <- list()
  for (info in calls_info) {
    caret_width <- nchar(x = info$text) +
      if (info$type == "call") {
        1L
      } else {
        0L
      }
    caret <- paste0(
      strrep(x = " ", times = info$col1 - 1L),
      strrep(x = "^", times = caret_width)
    )
    errors <- c(
      errors,
      list(list(
        line = info$line1,
        caret = paste0(report_lines[info$line1], "\n", caret)
      ))
    )
  }
  list(ok = FALSE, file = file, errors = errors)
}
