#' Apply `convert_int_literals()` to an R Package
#'
#' @description
#' Walks the `R/` and `tests/` directories of an R package and runs
#' [convert_int_literals()] on every `.R` / `.r` file.
#'
#' @param path Character path to the package root. If `NULL` and RStudio is
#'   available, the active document's project / working directory is used
#'   only when it looks like a package root (`DESCRIPTION` present).
#' @param dirs Character vector of subdirectories relative to `path` to
#'   search. Defaults to `c("R", "tests")`.
#' @param recursive Logical; recurse into subdirectories. Default `TRUE`.
#' @param ... Additional arguments. Currently unused and must be empty.
#'
#' @return
#' Invisibly returns a character vector of modified file paths.
#'
#' @examples
#' \donttest{
#' tmp_pkg <- tempdir()
#' usethis::create_package(tmp_pkg, open = FALSE)
#' writeLines("foo <- seq_len(42)", file.path(tmp_pkg, "R/foo.R"))
#' package_convert_int_literals(tmp_pkg)
#' message(readLines(file.path(tmp_pkg, "R/foo.R")))
#' }
#'
#' @export
package_convert_int_literals <- function(
  path = NULL,
  dirs = c("R", "tests"),
  recursive = TRUE,
  ...
) {
  rlang::check_dots_empty(...)
  rlang::check_bool(recursive)

  path <- path %||% "."

  if (!is_pkg(path)) {
    cli::cli_abort(c(
      "x" = "{.path {path}} does not look like an R package root.",
      "i" = "Expected a {.file DESCRIPTION} file."
    ))
  }

  path <- normalizePath(path, winslash = "/", mustWork = TRUE)

  files <- character()
  for (d in dirs) {
    dir_path <- file.path(path, d)
    if (!dir.exists(dir_path)) {
      next
    }
    files <- c(
      files,
      list.files(
        dir_path,
        pattern = "\\.[Rr]$",
        full.names = TRUE,
        recursive = recursive
      )
    )
  }

  n <- length(files)
  if (!n) {
    cli::cli_alert_info("No R files found under {.path {path}}")
    return(invisible(character()))
  }

  changed <- character()
  cli::cli_progress_bar(
    name = "Adding L suffixes",
    total = n,
    format = "{cli::pb_spin} Converting integer literals in package {cli::pb_current}/{cli::pb_total} | {cli::pb_percent}"
  )

  for (f in files) {
    cli::cli_progress_update(status = basename(f))
    original <- paste(readLines(f, warn = FALSE), collapse = "\n")
    convert_int_literals(path = f, verbose = FALSE)
    updated <- paste(readLines(f, warn = FALSE), collapse = "\n")
    if (!identical(original, updated)) {
      changed <- c(changed, f)
    }
  }

  cli::cli_progress_done()

  n_changed <- length(changed)
  cli::cli_alert_success(
    "Processed {n} file{?s}, updated {n_changed}"
  )

  invisible(changed)
}
