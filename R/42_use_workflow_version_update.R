#' Create a GitHub Actions workflow to auto-update R package version
#'
#' @description
#' Copies the built-in `version_update.yml` workflow template to the target
#' package's `.github/workflows/` directory. The workflow automatically bumps
#' the R package version based on commit messages, or manually via
#' `workflow_dispatch` with a specified version type.
#'
#' Version bump rules (from commit messages, case-insensitive):
#' * **major** / **breaking** - increments the major version (X.0.0)
#' * **feat** / **feature** / **minor** - increments the minor version (x.Y.0)
#' * **patch** / **fix** / **bug** - increments the patch version (x.y.Z)
#' * Otherwise, no version bump occurs
#'
#' The `workflow_dispatch` input always overrides commit message detection.
#'
#' @param path Character. Path to the package root directory. Defaults to the
#'   current working directory (\code{"."}).
#' @param overwrite Logical. If `TRUE`, overwrite an existing workflow file.
#'   Defaults to `FALSE`.
#'
#' @return Invisibly returns the path to the created workflow file.
#' @export
#'
#' @examples
#' \dontrun{
#' temp <- tempdir()
#' usethis::create_package(temp)
#' use_workflow_version_update(temp)
#' use_workflow_version_update(temp, overwrite = TRUE)
#' }
use_workflow_version_update <- function(path = ".", overwrite = FALSE) {
  if (!is_pkg(path)) {
    cli::cli_abort(c(
      "x" = "{.path {path}} is not an R package root.",
      ">" = "No {.file DESCRIPTION} found."
    ))
  }

  # Locate the template shipped with the package
  template <- system.file(
    "workflow",
    "version_update.yml",
    package = "rpkgkit",
    mustWork = TRUE
  )

  workflow_dir <- file.path(path, ".github", "workflows")
  dir.create(workflow_dir, recursive = TRUE, showWarnings = FALSE)

  workflow_path <- file.path(workflow_dir, "version_update.yml")

  if (file.exists(workflow_path) && !overwrite) {
    cli::cli_abort(c(
      "x" = "{.path {workflow_path}} already exists.",
      ">" = "Use {.code overwrite = TRUE} to overwrite."
    ))
  }

  file.copy(template, workflow_path, overwrite = TRUE)

  cli::cli_inform(c(
    "v" = "Created workflow: {.path {workflow_path}}",
    ">" = "It triggers on push to {.val main/master} and via {.field workflow_dispatch}. Version bump is inferred from commit messages or manual input.",
    "i" = "It is recommended to add a devel version badge to your {.file README.md} via {.code badger::badge_devel(color = \"blue\")}."
  ))

  invisible(workflow_path)
}
