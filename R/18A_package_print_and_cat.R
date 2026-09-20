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
    results[[i]] <- package_detect_print_and_cat(
      path = files[[i]],
      package_path = path,
      fix = fix,
      ...
    )
  }

  cli::cli_progress_done()

  n_ok <- sum(results)
  n_fail <- n - n_ok
  if (n_fail == 0L) {
    cli::cli_alert_success(
      "All {.val {n_ok}} file{?s} have no {.fn print} or {.fn cat} calls."
    )
  } else {
    cli::cli_alert_danger(
      "Found {.fn print}/{.fn cat} calls in {.val {n_fail}} of {.val {n}} file{?s}."
    )
  }

  invisible(n_fail == 0L)
}

package_detect_print_and_cat <- function(
  path,
  package_path,
  fix,
  pattern_fn_names = DEFAULT_PATTERN_FN_NAMES,
  replace_default_pattern = FALSE,
  include_s3 = TRUE,
  include_refs = FALSE,
  ...
) {
  lines <- readLines(con = path, warn = FALSE)
  exprs <- parse_safely(text = paste(lines, collapse = "\n"), path = path)
  calls_info <- find_print_cat_calls(
    parse_data = utils::getParseData(exprs),
    pattern_fn_names = resolve_pattern_fn_names(
      pattern_fn_names,
      replace_default_pattern
    ),
    include_s3 = include_s3,
    include_refs = include_refs
  )

  if (length(calls_info) == 0L) {
    return(TRUE)
  }

  report_lines <- lines
  if (fix) {
    to_fix <- Filter(
      f = function(x) x$type == "call" && identical(x$kind, "message"),
      x = calls_info
    )
    if (length(to_fix) > 0L) {
      ord <- order(
        vapply(to_fix, `[[`, integer(1L), "line1"),
        vapply(to_fix, `[[`, integer(1L), "col1"),
        decreasing = TRUE
      )
      for (info in to_fix[ord]) {
        lines[[info$line1]] <- replace_fn_at(
          line = lines[[info$line1]],
          col1 = info$col1,
          col2 = info$col2,
          new = "message"
        )
      }
      writeLines(text = lines, con = path)
    }
  }

  relative_path <- substring(path, nchar(package_path) + 2L)
  for (info in calls_info) {
    caret_width <- nchar(x = info$text) + if (info$type == "call") 1L else 0L
    caret <- paste0(
      strrep(x = " ", times = info$col1 - 1L),
      strrep(x = "^", times = caret_width)
    )
    tag <- if (!is.null(info$kind)) paste0(" [", info$kind, "]") else ""
    cli::cli_text(
      "{.file {relative_path}}: {.val {info$line1}}:"
    )
    message(paste0(
      report_lines[[info$line1]],
      cli::col_grey(tag),
      "\n",
      caret
    ))
  }

  FALSE
}
