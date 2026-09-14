#' Add a `URL` field to a package's `DESCRIPTION`
#'
#' @description
#' Sets the `URL` field of a package's `DESCRIPTION` file. By default, the
#' GitHub repository URL is detected from the configured `git` remote
#' (`origin`). An additional pkgdown website URL can optionally be appended.
#'
#' * Requires that the target directory is an R package root (contains a
#'   `DESCRIPTION` file).
#' * Both `https://` and `git@` style remotes are converted to a browser
#'   URL (a trailing `.git` suffix is removed).
#'
#' @param url Character. The primary URL (usually the GitHub repository).
#'   If `NULL` (the default), it is detected from the `git` remote
#'   configuration.
#' @param pkgdown_url Character. An optional pkgdown website URL, appended
#'   after `url`.
#' @param path Path to the package root. If `NULL` (the default), the current
#'   working directory is used.
#' @param ... Must be empty. Reserved for future arguments.
#'
#' @return Invisibly returns the URLs that were written.
#' @export
#'
#' @examples
#' \donttest{
#' tmpdir <- tempdir()
#' usethis::create_package(path = tmpdir)
#' use_url(
#'   url = "https://github.com/WangLabCSU/rpkgkit",
#'   pkgdown_url = "https://wanglabcsu.github.io/rpkgkit/",
#'   path = tmpdir
#' )
#' }
use_url <- function(url = NULL, pkgdown_url = NULL, path = NULL, ...) {
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
    url <- git_remote_url()
  }
  urls <- c(url, pkgdown_url)
  desc::desc_set_urls(urls = urls, file = path)
  cli::cli_inform(c(v = "Setting {.field URL} field to {.url {urls}}."))
  invisible(urls)
}

git_remote_url <- function(remote = "origin") {
  remotes <- usethis::git_remotes()
  url <- unname(remotes[remote])[[1L]]
  if (is.na(url)) {
    url <- unname(remotes[1L])
  }
  if (length(url) == 0L || is.na(url)) {
    cli::cli_abort(c(
      "x" = "No {.git git} remote configured for this repository.",
      ">" = "Provide {.arg url} explicitly or add a remote first."
    ))
  }
  url <- sub(
    pattern = "^git@([^:]+):",
    replacement = "https://\\1/",
    x = url
  )
  sub(pattern = "\\.git$", replacement = "", x = url)
}
