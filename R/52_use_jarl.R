#' Create a `jarl.toml` configuration file
#'
#' @description
#' Writes a `jarl.toml` configuration file for [jarl](https://jarl.etiennebacher.com/),
#' the R linter written in Rust. The file pins down the linting behaviour of
#' every `jarl` invocation in the project, so the command line, the editor
#' integration and the continuous integration workflow all agree.
#'
#' * `jarl.toml` is looked up by `jarl` in the current working directory, then in
#'   its parent directories, and finally in the user configuration directory.
#'   `jarl` reads a single configuration file, the closest one wins.
#' * All lint options live in the `[lint]` table. Command line flags always take
#'   precedence over the file.
#' * `[lint.per-file-ignores]` must come last in the file, otherwise the options
#'   written after it are parsed as glob patterns; the generated file does not
#'   use that table.
#' * When `path` is the root of an R package (contains a `DESCRIPTION` file),
#'   `jarl.toml` is also added to `.Rbuildignore` (inside a scoped project, so the
#'   active project of the calling session is restored afterwards).
#'
#' Read the
#' [configuration reference](https://jarl.etiennebacher.com/reference/config-file)
#' for the full list of options, and the
#' [continuous integration guide](https://jarl.etiennebacher.com/howto/ci)
#' to run `jarl` on every push with the `etiennebacher/setup-jarl` action.
#'
#' @param path Character. Path to the directory where `jarl.toml` should be
#'   written. If `NULL` (the default), the current working directory is used.
#' @param overwrite Logical. If `TRUE`, overwrite an existing `jarl.toml` file.
#'   Defaults to `FALSE`.
#' @param ... Must be empty. Reserved for future arguments.
#'
#' @return Invisibly returns the path to the created `jarl.toml` file.
#' @export
#'
#' @examples
#' tmp <- tempdir()
#' use_jarl(path = tmp, overwrite = TRUE)
#' readLines(file.path(tmp, "jarl.toml"))
use_jarl <- function(path = NULL, overwrite = FALSE, ...) {
  rlang::check_dots_empty()
  rlang::check_bool(overwrite)
  path <- path %||% "."
  if (identical(path, ".")) {
    path <- getwd()
  }
  if (file.exists(path) && !dir.exists(path)) {
    cli::cli_abort(c(
      x = "{.arg path} must be a directory, not a file: {.path {path}}."
    ))
  }
  is_pkg_root <- is_pkg(path = path)

  target_path <- file.path(path, "jarl.toml")
  if (file.exists(target_path)) {
    if (!isTRUE(overwrite)) {
      cli::cli_abort(c(
        x = "{.file {target_path}} already exists.",
        `>` = "Use {.code overwrite = TRUE} to overwrite."
      ))
    }
    cli::cli_alert_warning("Overwriting {.file {target_path}}.")
  }

  dir.create(path = path, showWarnings = FALSE, recursive = TRUE)
  writeLines(text = .jarl_config_lines(), con = target_path)

  # Keep `jarl.toml` out of the built tarball. Run inside a scoped project so
  # the user's active project is restored afterwards.
  if (is_pkg_root) {
    rlang::check_installed(
      "usethis",
      reason = "to add `jarl.toml` to `.Rbuildignore`."
    )
    usethis::with_project(
      path = path,
      force = TRUE,
      quiet = TRUE,
      code = usethis::use_build_ignore("jarl.toml")
    )
  }

  cli::cli_inform(c(v = "Created {.file {target_path}}."))

  cli::cli_bullets(c(
    `*` = "Read {.href [jarl's editor support](https://jarl.etiennebacher.com/reference/config-file)}
           to learn how to invoke jarl in your preferred editor.",
    `*` = "Read {.href [jarl's continuous integration](https://jarl.etiennebacher.com/howto/ci)}
           to learn about GHA workflows that continuously run linting checks."
  ))

  invisible(target_path)
}

# Build the TOML lines for `jarl.toml` (pure function, no file-system side
# effects). Commented-out lines document the options that are most useful in a
# package without enforcing them.
.jarl_config_lines <- function() {
  c(
    "# jarl configuration file",
    "# Reference: https://jarl.etiennebacher.com/reference/config-file",
    "",
    "[lint]",
    "# Rules enabled on top of jarl's default rule set. The `TESTTHAT` group is",
    "# opt-in, so it has to be requested explicitly.",
    'extend-select = ["TESTTHAT"]',
    "",
    "# Files or directories that jarl should not lint.",
    'exclude = ["R/vendor-*.R"]',
    "",
    "# Also lint the R code inside `@examples` and `@examplesIf` tags",
    "# (the default).",
    "check-roxygen = true",
    "",
    "# Rules that `jarl check --fix` is allowed to fix (all rules by default).",
    "# fixable = [\"PERF\"]",
    "",
    "# Rules that `jarl check --fix` must leave untouched.",
    "# unfixable = [\"undesirable_function\"]"
  )
}
