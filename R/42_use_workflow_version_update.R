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
#' @section NEWS.md guard:
#' Before writing anything, the action compares the version it is about to set
#' with the highest version documented in `NEWS.md` (heading lines such as
#' `# pkg 1.2.3 (2026-01-01)`). The bump is **skipped** when the new version is
#' greater than that maximum, so that no release is shipped without a matching
#' `NEWS.md` entry. When `NEWS.md` is missing or holds no version heading, the
#' check is bypassed with a warning.
#'
#' @section Rust crate version:
#' When the package ships Rust code, the action also reads the `version` key of
#' the `[package]` table in `src/rust/Cargo.toml` and rewrites it to the new
#' version. The rest of the manifest is left untouched and the same `NEWS.md`
#' guard applies, so the crate version never exceeds the highest version
#' documented in `NEWS.md`. The file is skipped when it is absent or declares no
#' literal version (for example `version.workspace = true`).
#'
#' @param path Character. Path to the package root directory. If \code{NULL}
#'   (the default), uses the current working directory.
#' @param overwrite Logical. If `TRUE`, overwrite an existing workflow file.
#'   Defaults to `FALSE`.
#' @param color badge color
#' @param ... pass to `badger::badge_devel`
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
use_workflow_version_update <- function(
  path = NULL,
  overwrite = FALSE,
  color = "blue",
  ...
) {
  path <- path %||% "."
  if (!is_pkg(path)) {
    cli::cli_abort(c(
      "x" = "{.path {path}} is not an R package root.",
      ">" = "No {.file DESCRIPTION} found."
    ))
  }

  # Source action files from inst/
  action_source <- system.file(
    "actions",
    "version-bumper",
    package = "rpkgkit"
  )

  # ── Copy action files to .github/actions/version-bumper/ ──
  action_target <- file.path(path, ".github", "actions", "version-bumper")
  dir.create(
    file.path(action_target, "dist"),
    recursive = TRUE,
    showWarnings = FALSE
  )

  action_files <- c("action.yml", "dist/index.js", "dist/licenses.txt")
  for (file in action_files) {
    src <- file.path(action_source, file)
    dst <- file.path(action_target, file)
    if (file.exists(dst) && isFALSE(overwrite)) {
      cli::cli_abort(c(
        "x" = "{.file {dst}} already exists. Use `overwrite = TRUE` to overwrite."
      ))
    }
    file.copy(from = src, to = dst, overwrite = TRUE)
  }

  # ── Copy workflow file to .github/workflows/ ──
  workflow_target <- file.path(path, ".github", "workflows")
  dir.create(workflow_target, recursive = TRUE, showWarnings = FALSE)

  workflow_src <- file.path(action_source, "version_bumper.yaml")
  workflow_dst <- file.path(workflow_target, "version_update.yml")

  if (file.exists(workflow_dst) && isFALSE(overwrite)) {
    cli::cli_abort(c(
      "x" = "{.file {workflow_dst}} already exists. Use `overwrite = TRUE` to overwrite."
    ))
  }
  file.copy(from = workflow_src, to = workflow_dst, overwrite = TRUE)

  cli::cli_inform(c(
    "v" = "Created workflow: {.path {workflow_dst}}",
    ">" = "It triggers on push to {.val main/master} and via {.field workflow_dispatch}.\
     Version bump is inferred from commit messages or manual input."
  ))
  cli_inform_colored <- add_colors_to_cli(cli::cli_inform)
  cli_inform_colored(
    "{.red {(cli_symbol$checkbox_off)}} \
    {.cyan It is recommended to add a devel version badge to your {.file README.md} via} {.code badger::badge_devel(color = \"blue\")}"
  )

  invisible(workflow_dst)
}
