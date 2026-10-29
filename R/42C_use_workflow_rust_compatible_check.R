#' Create a Rust-compatible R-CMD-check Workflow
#'
#' @description
#' Copies the built-in `R-CMD-Check.yaml` workflow template to the target
#' package's `.github/workflows/` directory, so that `R CMD check` runs on
#' GitHub Actions with a toolchain that can download, compile and link Rust
#' crates (packages built on `extendr`/`rextendr`).
#'
#' @section Why not the `usethis` workflow:
#' `usethis::use_github_action("check-standard")` only sets up R and then calls
#' `R CMD check` on a matrix of operating systems. For packages with Rust code
#' this is not enough:
#'
#' * No Rust toolchain is installed, so the runner default is used. On Windows
#'   that default is an **MSVC** toolchain, while R and Rtools are **GNU**
#'   based, so the static library produced by `cargo` cannot be linked, and the
#'   resulting build noise (`cargo` warnings, linker messages) makes
#'   `R CMD check` report a WARNING.
#'
#' The template used here follows the official `extendr` CI:
#'
#' * `dtolnay/rust-toolchain` installs the requested toolchain, and on Windows
#'   additionally the `x86_64-pc-windows-gnu` target that Rtools can link.
#' * The R matrix covers Windows, macOS, Ubuntu release and Ubuntu devel, with
#'   `fail-fast: false` so one broken platform does not hide the others.
#' * `R_REMOTES_NO_ERRORS_FROM_WARNINGS` keeps `remotes`/`pak` download noise
#'   from turning into check failures.
#'
#' @param path Character. Path to the package root directory. If \code{NULL}
#'   (the default), uses the current working directory.
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
#' use_workflow_rust_compatible_check(temp)
#' use_workflow_rust_compatible_check(temp, overwrite = TRUE)
#' }
use_workflow_rust_compatible_check <- function(
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

  # Source workflow template from inst/
  workflow_src <- system.file(
    "actions",
    "rust_compatible_check",
    "R-CMD-Check.yaml",
    package = "rpkgkit"
  )

  if (!nzchar(workflow_src) || !file.exists(workflow_src)) {
    cli::cli_abort(c(
      "x" = "Workflow template {.file R-CMD-Check.yaml} was not found.",
      ">" = "Reinstall {.pkg rpkgkit} to restore {.path inst/actions/rust_compatible_check/}."
    ))
  }

  # ── Copy workflow file to .github/workflows/ ──
  workflow_target <- file.path(path, ".github", "workflows")
  dir.create(workflow_target, recursive = TRUE, showWarnings = FALSE)

  workflow_dst <- file.path(workflow_target, "R-CMD-check.yaml")

  if (file.exists(workflow_dst) && isFALSE(overwrite)) {
    cli::cli_abort(c(
      "x" = "{.file {workflow_dst}} already exists. Use `overwrite = TRUE` to overwrite."
    ))
  }
  file.copy(from = workflow_src, to = workflow_dst, overwrite = TRUE)

  cli::cli_inform(c(
    "v" = "Created workflow: {.path {workflow_dst}}",
    ">" = "It triggers on push to {.val main} and on pull requests targeting {.val main}.",
    ">" = "Rust crates are compiled with a pinned toolchain and the {.val x86_64-pc-windows-gnu} target on Windows, so they link against Rtools."
  ))

  invisible(workflow_dst)
}
