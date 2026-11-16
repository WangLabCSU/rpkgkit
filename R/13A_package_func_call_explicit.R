# Package-level orchestration: directory discovery, progress reporting and
# summarising stay in R (they are all cli/file-system concerns), while every
# file is rewritten by the Rust engine behind make_func_call_explicit().

#' @describeIn make_func_call_explicit Processes all \code{.R} files in a
#'   package's \code{R/} directory, adding explicit namespace qualifiers.
#'
#' @export
package_func_call_explicit <- function(
  path = NULL,
  use_packages = current_packages(),
  ignore_functions = c(
    imported_functions(path),
    get_defined_fn(path)
  ),
  ...
) {
  rlang::check_dots_empty()
  rlang::check_installed("pkgload")
  path <- path %||% "."

  if (is.null(path) || !nzchar(path)) {
    cli::cli_abort(c("x" = "{.arg path} is required"))
  }
  path <- normalizePath(path = path, mustWork = FALSE)
  if (!is_pkg(path = path)) {
    cli::cli_abort("{.path {path}} is not an R package (no DESCRIPTION found).")
  }
  r_dir <- file.path(path, "R")
  if (!dir.exists(paths = r_dir)) {
    cli::cli_abort("No {.path R/} directory found in {.path {path}}.")
  }
  files <- list.files(path = r_dir, pattern = "\\.R$", full.names = TRUE)
  n <- length(files)
  if (n == 0L) {
    cli::cli_alert_info("No {.code .R} files found in {.path {r_dir}}.")
    return(invisible(TRUE))
  }

  cli::cli_alert_info(
    "Processing {n} file{?s} with {.pkg {use_packages}}..."
  )

  # The package lookups are resolved once and shared by every file: reading the
  # exports and datasets of each package is the expensive part.
  context <- mfce_package_context(
    use_packages = use_packages,
    ignore_functions = ignore_functions
  )

  results <- vector("list", n)
  cli::cli_progress_bar(
    name = "Making function calls explicit",
    total = n,
    format = paste0(
      "{cli::pb_spin} Rewriting package R files ",
      "{cli::pb_current}/{cli::pb_total} | {cli::pb_percent}"
    )
  )

  for (i in seq_along(files)) {
    cli::cli_progress_update(status = basename(files[[i]]))
    results[[i]] <- tryCatch(
      mfce_process_file(files[[i]], context),
      error = function(e) e
    )
  }

  cli::cli_progress_done()

  failed <- vapply(results, inherits, logical(1L), what = "error")
  n_fail <- sum(failed)
  n_ok <- n - n_fail

  mfce_warn_not_found(
    unique(unlist(lapply(results[!failed], `[[`, "not_found")))
  )

  if (n_fail == 0L) {
    cli::cli_alert_success("Successfully processed all {n_ok} file{?s}.")
    return(invisible(TRUE))
  }

  cli::cli_alert_danger("Processed {n_ok} of {n} file{?s}, {n_fail} failed.")
  for (i in which(failed)) {
    cli::cli_alert_warning(
      "{.file {basename(files[[i]])}}: {conditionMessage(results[[i]])}"
    )
  }
  invisible(FALSE)
}
