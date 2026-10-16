#' Create a `.clangd` configuration file
#'
#' @description
#' Writes a `.clangd` configuration file at `path` with `CompileFlags` set to
#' include headers from the system R installation and from common C++ interface
#' packages (`Rcpp`, `RcppEigen`, `RcppArmadillo`). If `path` is the root of an
#' R package (contains a `DESCRIPTION` file), an additional `If:` block is
#' appended that disables background indexing for the `R/` source directory,
#' since it only contains R code, not C++ source. In that case `.clangd` is
#' also added to `.Rbuildignore` (inside a scoped project, so the active
#' project of the calling session is restored afterwards).
#'
#' * `.clangd` is the configuration file read by the clangd language server.
#'   It is typically placed in the project root.
#' * The system R include directory is obtained via [base::R.home()] with
#'   component `"include"`.
#' * Package include directories are obtained via [base::system.file()] with
#'   `package = <pkg>`.
#' * Packages that are not installed (or that have no `include/` directory)
#'   are skipped with a [cli::cli_warn()] warning.
#'
#' @param path Character. Path to the directory where `.clangd` should be
#'   written. If `NULL` (the default), the current working directory is used.
#' @param include Character vector of package names whose `include/`
#'   directories should be added to `CompileFlags.Add`. Defaults to
#'   `c("Rcpp", "RcppEigen", "RcppArmadillo")`. Pass `character(0)` to add
#'   only the system R include path. Custom names such as `"BH"` are
#'   supported; if the package is not installed, its include path is
#'   skipped and a warning is emitted.
#' @param overwrite Logical. If `TRUE`, overwrite an existing `.clangd`
#'   file. Defaults to `FALSE`.
#' @param open Logical. Whether to open the created file in the editor.
#'   Defaults to [rlang::is_interactive()]. Only takes effect when
#'   `rstudioapi` is installed.
#' @param ... Must be empty. Reserved for future arguments.
#'
#' @return Invisibly returns the path to the created `.clangd` file.
#' @export
#'
#' @examples
#' \donttest{
#' tmp <- tempdir()
#' use_clangd(path = tmp)
#'
#' # Custom include library names
#' use_clangd(
#'   path = tmp,
#'   include = c("Rcpp", "BH"),
#'   overwrite = TRUE
#' )
#' }
use_clangd <- function(
  path = NULL,
  include = c("Rcpp", "RcppEigen", "RcppArmadillo"),
  overwrite = FALSE,
  open = rlang::is_interactive(),
  ...
) {
  rlang::check_dots_empty()
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

  target_path <- file.path(path, ".clangd")
  if (file.exists(target_path)) {
    if (!isTRUE(overwrite)) {
      cli::cli_abort(c(
        x = "{.file {target_path}} already exists.",
        `>` = "Use {.code overwrite = TRUE} to overwrite."
      ))
    }
    cli::cli_alert_warning("Overwriting {.file {target_path}}.")
  }

  include_paths <- .clangd_collect_includes(include)
  yaml_lines <- .clangd_build_config(
    include_paths = include_paths,
    is_pkg_root = is_pkg_root
  )

  dir.create(path = path, showWarnings = FALSE, recursive = TRUE)
  writeLines(text = yaml_lines, con = target_path)

  # Keep `.clangd` out of the built tarball. Run inside a scoped project so the
  # user's active project is restored afterwards.
  if (is_pkg_root) {
    usethis::with_project(
      path = path,
      force = TRUE,
      quiet = TRUE,
      code = usethis::use_build_ignore(".clangd")
    )
  }

  cli::cli_inform(c(v = "Created {.file {target_path}}."))

  if (isTRUE(open) && rlang::is_installed("rstudioapi")) {
    rstudioapi::navigateToFile(target_path)
  }

  invisible(target_path)
}

# Collect `-I` include paths: the system R include directory, followed by
# the `include/` directory of each named package (when present).
.clangd_collect_includes <- function(packages) {
  paths <- R.home("include")
  for (pkg in packages) {
    inc <- tryCatch(
      system.file("include", package = pkg),
      error = function(e) ""
    )
    if (nzchar(inc)) {
      paths <- c(paths, inc)
    } else {
      cli::cli_warn(
        "Package {.pkg {pkg}} is not installed; skipping its include path."
      )
    }
  }
  paths
}

# Build the YAML lines for `.clangd` (pure function, no file-system side
# effects). When `is_pkg_root = TRUE`, an `---`-separated second block is
# appended that disables indexing for the R source directory.
.clangd_build_config <- function(include_paths, is_pkg_root) {
  flag_lines <- paste0("    - -I", include_paths)

  main_block <- c(
    "CompileFlags:",
    "  Add:",
    flag_lines,
    "Diagnostics:",
    "  UnusedIncludes: Ignore",
    "Index:",
    "  Background: Build"
  )

  blocks <- list(main_block)

  if (isTRUE(is_pkg_root)) {
    blocks[[length(blocks) + 1L]] <- c(
      "---",
      "If:",
      "  PathMatch: R/.*",
      "Index:",
      "  Background: None"
    )
  }

  unlist(blocks, use.names = FALSE)
}
