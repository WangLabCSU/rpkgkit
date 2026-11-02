#' @rdname detect_fn_arg_path
#' @export
package_fn_arg_path <- function(
  path = NULL,
  arg_pattern = "path|file|filename",
  allow = "NULL",
  dirs = "R",
  verbose = TRUE,
  ...
) {
  rlang::check_dots_empty()
  path <- path %||% "."
  if (!nzchar(path)) {
    cli::cli_abort(c("x" = "{.arg path} is required"))
  }
  path <- normalizePath(path = path, mustWork = FALSE)
  if (!is_pkg(path = path)) {
    cli::cli_abort("{.path {path}} is not an R package (no DESCRIPTION found).")
  }

  ns <- .uta_parse_namespace(file.path(path, "NAMESPACE"))
  if (length(ns$exports) == 0L && length(ns$export_patterns) == 0L) {
    cli::cli_alert_info("No exported functions found in {.file NAMESPACE}.")
    return(invisible(TRUE))
  }

  files <- character()
  for (dir in dirs) {
    dir_path <- file.path(path, dir)
    if (!dir.exists(dir_path)) {
      next
    }
    files <- c(
      files,
      list.files(
        path = dir_path,
        pattern = "\\.[Rr]$",
        full.names = TRUE,
        recursive = TRUE
      )
    )
  }

  n <- length(files)
  if (n < 1L) {
    cli::cli_alert_info("No {.code .R} files found to scan in {.path {path}}.")
    return(invisible(TRUE))
  }

  n_hits <- 0L
  n_bad_files <- 0L
  for (f in files) {
    scanned <- scan_fn_arg_path(
      file = f,
      arg_pattern = arg_pattern,
      exports = ns$exports,
      export_patterns = ns$export_patterns,
      allow = allow
    )
    k <- length(scanned$hits)
    if (k > 0L) {
      n_hits <- n_hits + k
      n_bad_files <- n_bad_files + 1L
      if (verbose) {
        report_fn_arg_hits(
          file = f,
          lines = scanned$lines,
          hits = scanned$hits,
          root = path
        )
      }
    }
  }

  if (n_hits == 0L) {
    cli::cli_alert_success(
      "No exported function has a default path argument ({n} file{?s} scanned)."
    )
  } else {
    cli::cli_alert_danger(
      "Found {n_hits} argument{?s} with a default path in {n_bad_files} of {n} file{?s}."
    )
  }

  invisible(n_hits == 0L)
}
