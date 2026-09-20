#' @rdname detect_print_and_cat
#' @export
package_print_and_cat <- function(
  path = NULL,
  dirs = c("R", file.path("tests", "testthat")),
  test_included = lifecycle::deprecated(),
  fix = FALSE,
  ...
) {
  if (lifecycle::is_present(test_included)) {
    lifecycle::deprecate_warn(
      when = "0.1.15",
      what = "package_print_and_cat(test_included = )",
      with = "package_print_and_cat(dirs = )"
    )
    rlang::check_bool(test_included)
    dirs <- if (test_included) {
      c("R", file.path("tests", "testthat"))
    } else {
      "R"
    }
  }

  path <- path %||% "."
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
    cli::cli_alert_info("No {.code .R} files found to scan in {.path {path}}.")
    return(invisible(TRUE))
  }

  results <- logical(length = n)
  cli::cli_progress_bar(
    name = "Detecting print and cat calls",
    total = n,
    format = paste0(
      "{cli::pb_spin} Scanning package R files ",
      "{cli::pb_current}/{cli::pb_total} | {cli::pb_percent}"
    )
  )

  for (i in seq_along(files)) {
    cli::cli_progress_update(status = basename(files[[i]]))
    results[[i]] <- detect_print_and_cat(
      path = files[[i]],
      fix = fix,
      verbose = FALSE,
      ...
    )
  }

  cli::cli_progress_done()

  n_ok <- sum(results)
  n_fail <- n - n_ok
  if (n_fail == 0L) {
    cli::cli_alert_success(
      "All {n_ok} file{?s} have no {.fn print} or {.fn cat} calls."
    )
  } else {
    cli::cli_alert_danger(
      "Found {.fn print}/{.fn cat} calls in {n_fail} of {n} file{?s}."
    )
  }

  invisible(n_fail == 0L)
}
