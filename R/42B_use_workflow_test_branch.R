#' Create a GitHub Actions Workflow to Sync Main to Test Branch
#'
#' @description
#' Copies the built-in `sync_test_branch.yml` workflow template and the
#' corresponding `sync-test-branch` composite action to the target package's
#' `.github/` directory. The workflow triggers on push to `main`/`master` and
#' force-pushes the main branch contents onto the `test` branch.
#'
#' **Safety mechanism**: If the `test` branch contains commits that are not
#' reachable from `main` (i.e., unmerged work-in-progress), the sync is
#' skipped to avoid overwriting unmerged changes.
#'
#' This enables convenient isolated debugging: work on the `test` branch,
#' push experimental changes, and each push to `main` will reset `test`
#' to match `main` (as long as no unmerged work exists on `test`).
#'
#' @param path Character. Path to the package root directory. If \code{NULL}
#'   (the default), uses the current working directory.
#' @param overwrite Logical. If `TRUE`, overwrite existing workflow and action
#'   files. Defaults to `FALSE`.
#'
#' @return Invisibly returns the path to the created workflow file.
#' @export
#'
#' @examples
#' \dontrun{
#' temp <- tempdir()
#' usethis::create_package(temp)
#' use_workflow_test_branch(temp)
#' use_workflow_test_branch(temp, overwrite = TRUE)
#' }
use_workflow_test_branch <- function(
  path = NULL,
  overwrite = FALSE
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
    "sync-test-branch",
    package = "rpkgkit"
  )

  # ── Copy action files to .github/actions/sync-test-branch/ ──
  action_target <- file.path(path, ".github", "actions", "sync-test-branch")
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

  workflow_src <- file.path(action_source, "sync_test_branch.yaml")
  workflow_dst <- file.path(workflow_target, "sync_test_branch.yml")

  if (file.exists(workflow_dst) && isFALSE(overwrite)) {
    cli::cli_abort(c(
      "x" = "{.file {workflow_dst}} already exists. Use `overwrite = TRUE` to overwrite."
    ))
  }
  file.copy(from = workflow_src, to = workflow_dst, overwrite = TRUE)

  cli::cli_inform(c(
    "v" = "Created workflow: {.path {workflow_dst}}",
    ">" = "It triggers on push to {.val main} and force-pushes contents to the {.val test} branch.",
    ">" = "If {.val test} has unmerged work, the sync is skipped automatically."
  ))

  invisible(workflow_dst)
}
