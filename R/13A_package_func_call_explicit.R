#' @describeIn make_func_call_explicit Processes all \code{.R} files in a
#'   package's \code{R/} directory, adding explicit namespace qualifiers.
#'
#' @export
package_func_call_explicit <- function(
  path = NULL,
  use_packages = current_packages(),
  ignore_functions = imported_functions(),
  ...
) {
  rlang::check_dots_empty0()
  rlang::check_installed("pkgload")
  path <- path %||% "."
  path <- normalizePath(path = path, mustWork = FALSE)
  if (!is_pkg(path = path)) {
    cli::cli_abort("{.path {path}} is not an R package (no DESCRIPTION found).")
  }
  r_dir <- file.path(path, "R")
  if (!dir.exists(paths = r_dir)) {
    cli::cli_abort("No {.path R/} directory found in {.path {path}}.")
  }
  files <- list.files(path = r_dir, pattern = "\\.R$", full.names = TRUE)
  if (length(files) == 0L) {
    cli::cli_alert_info("No {.code .R} files found in {.path {r_dir}}.")
    return(invisible(TRUE))
  }
  cli::cli_alert_info(
    "Processing {length(files)} file{?s} with {.pkg {use_packages}}..."
  )
  n_ok <- 0L
  for (f in files) {
    make_func_call_explicit(
      path = f,
      use_packages = use_packages,
      ignore_functions = ignore_functions
    )
    n_ok <- n_ok + 1L
  }
  n_fail <- length(files) - n_ok
  if (n_fail == 0L) {
    cli::cli_alert_success("Successfully processed all {n_ok} file{?s}.")
    invisible(TRUE)
  } else {
    cli_alert_danger_color <- add_colors_to_cli(cli::cli_alert_danger)
    cli_alert_danger_color(
      "Processed {.green {n_ok}} file{?s}, {.red {n_fail}} failed."
    )
    invisible(FALSE)
  }
}
