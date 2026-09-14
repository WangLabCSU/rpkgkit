#' Add a `BugReports` field to a package's `DESCRIPTION`
#'
#' @description
#' Sets the `BugReports` field of a package's `DESCRIPTION` file. By default,
#' the GitHub issues page URL is derived from the configured `git` remote
#' (`origin`).
#'
#' * Requires that the target directory is an R package root (contains a
#'   `DESCRIPTION` file).
#' * Both `https://` and `git@` style remotes are supported (see [use_url()]).
#'
#' @param url Character. The bug reports URL (usually the GitHub issues
#'   page). If `NULL` (the default), it is derived from the `git` remote
#'   configuration by appending `/issues` to the repository URL.
#' @param path Path to the package root. If `NULL` (the default), the current
#'   working directory is used.
#' @param ... Must be empty. Reserved for future arguments.
#'
#' @return Invisibly returns the URL that was written.
#' @export
#'
#' @examples
#' \donttest{
#' tmpdir <- tempdir()
#' usethis::create_package(path = tmpdir)
#' use_bugreports(
#'   url = "https://github.com/WangLabCSU/rpkgkit/issues",
#'   path = tmpdir
#' )
#' }
use_bugreports <- function(url = NULL, path = NULL, ...) {
  rlang::check_dots_empty()
  rlang::check_installed(c("usethis", "desc"))
  path <- path %||% "."
  if (!is_pkg(path = path)) {
    cli::cli_abort(c(
      "x" = "{.path {path}} is not an R package root.",
      ">" = "No {.file DESCRIPTION} found."
    ))
  }
  usethis::proj_set(path = path)

  if (is.null(url)) {
    url <- paste0(git_remote_url(), "/issues")
  }
  desc::desc_set("BugReports", url, file = path)
  cli::cli_inform(c(v = "Setting {.field BugReports} field to {.url {url}}."))
  invisible(url)
}
