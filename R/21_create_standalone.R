# This document was last modified on 2026-05-20.
#'
#' Creates a new standalone R script with YAML metadata header.
#' If `path` is an R package, the file is created in the `R/` subdirectory.
#'
#' @param standalone_name Character. The name suffix for the standalone file
#'   (e.g., "my_utils" creates "standalone-my_utils.R").
#' @param path Character. Directory path where to create the file.
#'   Defaults to the current working directory (\code{"."}).
#' @param standalone_head List. Metadata for the file header with elements:
#'   \itemize{
#'     \item `license`: Character. License URL or identifier.
#'       Defaults to "https://unlicense.org".
#'     \item `imports`: Character vector. Package dependencies to import.
#'       Defaults to NULL.
#'     \item `dependency`: Character vector. Hard dependencies for the
#'       standalone file. Defaults to NULL.
#'     \item `description`: Character. A short description of the standalone
#'       file. Defaults to "To be filled.".
#'   }
#' @param open Logical. Whether to open the file in RStudio editor.
#'   Defaults to TRUE.
#' @param ... Additional arguments (must be empty).
#'
#' @return Invisibly returns the path to the created file.
#'
#' @examples
#' \donttest{
#' create_standalone("my_utils", path = tempdir())
#' }
#' @export
create_standalone <- function(
  standalone_name = NULL,
  path = NULL,
  standalone_head = list(
    license = "https://unlicense.org",
    imports = NULL,
    dependency = NULL,
    description = "This file provides..."
  ),
  open = rlang::is_interactive(),
  ...
) {
  rlang::check_dots_empty()
  filename <- paste0("standalone-", standalone_name, ".R")

  # Merge user-provided standalone_head with defaults so missing fields fall back
  standalone_head <- utils::modifyList(
    list(
      license = "https://unlicense.org",
      imports = NULL,
      dependency = NULL,
      description = "This file provides..."
    ),
    standalone_head
  )

  path <- path %||% "."

  if (is_pkg(path)) {
    target_dir <- file.path(path, "R")
  } else {
    target_dir <- path
  }
  target_path <- file.path(target_dir, filename)

  if (file.exists(target_path)) {
    cli::cli_abort(
      "{.path {target_path}} already exists."
    )
  }

  repo_info <- tryCatch(
    {
      if (is_pkg(path)) {
        url <- system2(
          "git",
          c("-C", path, "remote", "get-url", "origin"),
          stdout = TRUE
        )

        url <- sub("\\.git$", "", trimws(url))
        url <- sub("^https://github\\.com/", "", url)
        url <- sub("^git@github\\.com:", "", url)
        url <- sub("/", "/", url)
        url
      } else if (is_pkg(dirname(path)) && basename(path) == "R") {
        url <- system2(
          "git",
          c("-C", dirname(path), "remote", "get-url", "origin"),
          stdout = TRUE
        )

        url <- sub("\\.git$", "", trimws(url))
        url <- sub("^https://github\\.com/", "", url)
        url <- sub("^git@github\\.com:", "", url)
        url <- sub("/", "/", url)
        url
      } else {
        basename(normalizePath(path, mustWork = FALSE))
      }
    },
    error = function(e) basename(path)
  )

  today <- format(Sys.time(), "%Y-%m-%d")

  head_lines <- c(
    "# ---",
    sprintf("# repo: %s", repo_info),
    sprintf("# file: %s", filename),
    sprintf("# last-updated: %s", today),
    sprintf("# license: %s", standalone_head$license),
    sprintf(
      "# imports: %s",
      toString(standalone_head$imports %||% "")
    ),
    sprintf(
      "# dependency: %s",
      toString(standalone_head$dependency %||% "")
    ),
    "# ---",
    "#",
    sprintf("# %s", standalone_head$description),
    "#",
    paste0("# nocov", " start") # * make this function can be tested
  )

  writeLines(head_lines, con = target_path)

  cli::cli_alert_success("Created standalone file: {.path {target_path}}")

  if (isTRUE(open) && rlang::is_installed("rstudioapi")) {
    cli::cli_text(
      "{cli::col_red(cli::symbol$checkbox_off)} File opened in editor."
    )
    rstudioapi::navigateToFile(target_path)
  }

  invisible(target_path)
}
