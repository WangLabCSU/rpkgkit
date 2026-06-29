#' Create a zzz.R file from a template
#'
#' @description
#' Copies the built-in `zzz_template.R` to the target package's `R/` directory
#' and replaces template placeholders (all-caps words) with values from the
#' package `DESCRIPTION` file.
#'
#' Template placeholders replaced:
#' * `PKG` — package name
#' * `PKG-package` — `{pkgname}-package`
#' * `TITLE` — package title
#' * `DESCRIPTION` — package description (multiline values get `#' ` prefix)
#' * `LICENSE` — license type
#'
#' @param path Character. Path to the package root directory. Defaults to
#'   the current working directory (\code{"."}).
#' @param file_name Character. Output file name. Defaults to `"<pkg_name>-package.R"`.
#' @param overwrite Logical. If `TRUE`, overwrite an existing file.
#'   Defaults to `FALSE`.
#' @param open Logical. Whether to open the created file in the default editor.
#' @param ... Not used.
#'
#' @return Invisibly returns the path to the created file.
#' @export
#'
#' @examples
#' \dontrun{
#' dir <- tempdir()
#' usethis::create_package(dir)
#' use_zzz(dir)
#' }
use_zzz <- function(
  path = ".",
  file_name = paste0(get_package_name(path = path), "-package.R"),
  overwrite = FALSE,
  open = rlang::is_interactive(),
  ...
) {
  rlang::check_dots_empty0()
  rlang::check_installed("usethis")
  if (!is_pkg(path = path)) {
    cli::cli_abort(c(
      x = "{.path {path}} is not an R package root.",
      `>` = "No {.file DESCRIPTION} found."
    ))
  }

  usethis::proj_set(path = path)

  desc <- read.dcf(file = file.path(path, "DESCRIPTION"))
  pkg <- desc[, "Package"]
  title <- desc[, "Title"]
  description <- gsub(
    pattern = "\n",
    replacement = "\n#' ",
    x = desc[, "Description"]
  )
  license <- desc[, "License"]
  template <- system.file(
    "R_template",
    "zzz_template.R",
    package = "rpkgkit",
    mustWork = TRUE
  )
  tmpl <- readLines(con = template, warn = FALSE)
  tmpl <- gsub(pattern = "\\bPKG\\b", replacement = pkg, x = tmpl)
  tmpl <- gsub(pattern = "\\bTITLE\\b", replacement = title, x = tmpl)
  tmpl <- gsub(
    pattern = "\\bDESCRIPTION\\b",
    replacement = description,
    x = tmpl
  )
  tmpl <- gsub(pattern = "\\bLICENSE\\b", replacement = license, x = tmpl)
  tmpl <- c(
    tmpl,
    "",
    "## usethis namespace: start",
    "## usethis namespace: end",
    "NULL"
  )
  target_path <- file.path(path, "R", file_name)
  if (file.exists(target_path)) {
    if (!isTRUE(x = overwrite)) {
      cli::cli_abort(c(
        x = "{.file {target_path}} already exists.",
        `>` = "Use {.code overwrite = TRUE} to overwrite."
      ))
    }
    cli::cli_alert_warning("Overwriting {.file {target_path}}.")
  }
  dir.create(
    path = dirname(path = target_path),
    showWarnings = FALSE,
    recursive = TRUE
  )
  writeLines(text = tmpl, con = target_path)
  cli::cli_inform(c(v = "Created {.file {target_path}} from template."))

  usethis::use_package(package = "cli")

  if (isTRUE(x = open) && rlang::is_installed("rstudioapi")) {
    cli::cli_text(
      "{cli::col_red(cli::symbol$checkbox_off)} File opened in editor."
    )
    rstudioapi::navigateToFile(target_path)
  }
  invisible(target_path)
}
