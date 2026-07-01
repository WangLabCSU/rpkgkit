#' @describeIn detect_lost_glue_brace Scans all \code{.R} files in an R package
#'   (and optionally \code{tests/testthat/}), aggregated with per-file reporting.
#'
#' @export
package_lost_glue_brace <- function(path = NULL, test_included = TRUE, ...) {
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
    file_results[[i]] <- scan_file_braces(file = files[i])
  }
  n_ok <- sum(vapply(
    X = file_results,
    FUN = `[[`,
    FUN.VALUE = logical(length = 1L),
    "ok"
  ))
  n_fail <- length(file_results) - n_ok
  if (n_fail == 0L) {
    cli::cli_alert_success("All {n_ok} file{?s} have balanced glue braces.")
    return(invisible(TRUE))
  }
  cli::cli_alert_danger(
    "Found mismatched braces in {n_fail} of {length(files)} file{?s}:"
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


#‘ @keywords internal
scan_file_braces <- function(file) {
  lines <- readLines(con = file)
  text <- paste(lines, collapse = "\n")
  exprs <- parse_safely(text = text, path = file)
  parse_data <- utils::getParseData(exprs)
  strings_info <- find_glue_cli_strings(parse_data = parse_data)
  if (length(strings_info) == 0L) {
    return(list(ok = TRUE, file = file, errors = list()))
  }
  errors <- list()
  for (info in strings_info) {
    result <- check_brace_balance(s = info$content)
    if (!result$balanced) {
      errors <- c(
        errors,
        list(list(
          line = info$line1,
          caret = format_brace_error(
            line_content = lines[info$line1],
            str_content = info$content,
            line_num = info$line1,
            col_offset = info$col1,
            result = result
          )
        ))
      )
    }
  }
  list(ok = length(errors) == 0L, file = file, errors = errors)
}
