#' @describeIn make_func_arg_explicit Processes all \code{.R} files in a
#'   package's \code{R/} directory, making function arguments explicit.
#'
#' @export
package_func_arg_explicit <- function(path = ".", skip_functions = NULL, ...) {
  rlang::check_dots_empty0()
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
  cli::cli_alert_info("Processing {length(files)} file{?s}...")
  n_ok <- 0L
  for (f in files) {
    make_func_arg_explicit(path = f, skip_functions = skip_functions)
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
