#' @rdname detect_unmatched_nocov_marker
#' @export
package_unmatched_nocov_marker <- function(
  path = NULL,
  dirs = "R",
  verbose = TRUE
) {
  path <- path %||% "."
  if (is.null(path) || !nzchar(path)) {
    cli::cli_abort(c("x" = "{.arg path} is required"))
  }
  path <- normalizePath(path = path, mustWork = FALSE)
  if (!is_pkg(path = path)) {
    cli::cli_abort("{.path {path}} is not an R package (no DESCRIPTION found).")
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
        pattern = "\\.R$",
        full.names = TRUE,
        recursive = TRUE
      )
    )
  }

  n <- length(files)
  if (n == 0L) {
    if (verbose) {
      cli::cli_alert_info(
        "No {.code .R} files found to scan in {.path {path}}."
      )
    }
    return(invisible(TRUE))
  }

  n_found <- integer(length = n)
  if (verbose) {
    cli::cli_progress_bar(
      name = "Detecting unmatched nocov markers",
      total = n,
      format = paste0(
        "{cli::pb_spin} Scanning package R files ",
        "{cli::pb_current}/{cli::pb_total} | {cli::pb_percent}"
      )
    )
  }

  for (i in seq_along(files)) {
    if (verbose) {
      cli::cli_progress_update(status = basename(files[[i]]))
    }
    n_found[[i]] <- package_scan_nocov_file(
      path = files[[i]],
      package_path = path,
      verbose = verbose
    )
  }

  if (verbose) {
    cli::cli_progress_done()
  }

  n_bad <- sum(n_found)
  n_fail <- sum(n_found > 0L)
  if (verbose) {
    if (n_bad == 0L) {
      cli::cli_alert_success(
        "All {.code nocov} markers are consistent in {.val {n}} file{?s}."
      )
    } else {
      cli::cli_alert_danger(
        "Found {.val {n_bad}} mismatched {.code nocov} marker{?s} in {.val {n_fail}} of {.val {n}} file{?s}."
      )
    }
  }

  invisible(n_bad == 0L)
}

# ---------------------------------------------------------------------------
# Check one file of a package and report its problems with a package-relative
# file label. Returns the number of mismatched markers found.
# ---------------------------------------------------------------------------
package_scan_nocov_file <- function(path, package_path, verbose) {
  scan <- scan_nocov_file(path = path)
  if (length(scan$markers) == 0L) {
    return(0L)
  }

  label <- substring(path, nchar(package_path) + 2L)
  if (verbose) {
    report_nocov_problems(scan = scan, label = label)
  }

  length(scan$problems)
}
