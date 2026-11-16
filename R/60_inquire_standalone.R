#' @title Inquire Standalone Files from a GitHub Repository
#'
#' @description Retrieve information about all standalone R files in the R/
#'   directory of a GitHub repository. Standalone files are identified by the
#'   "standalone-" prefix in their filename.
#'
#' @param owner A character string specifying the repository owner's username.
#' @param repo A character string specifying the repository name.
#' @param ... No arguments.
#' @param token A GitHub personal access token. When `NULL` (the default) the
#'   token is read from the `GITHUB_PAT` or `GITHUB_TOKEN` environment variable;
#'   without a token GitHub only allows 60 requests per hour.
#'
#' @return A tibble with one row per standalone file:
#' \describe{
#'   \item{name, path, sha, size, url, html_url, git_url, download_url, type}{The
#'     fields of the GitHub contents API entry of the file.}
#'   \item{repo}{Character string, the repository identifier in "owner/repo"
#'     format.}
#'   \item{description}{Character string, the description extracted from the
#'     file's provenance header (the `# ---` block written by
#'     `usethis::use_standalone()`) or from its roxygen documentation, `NA` when
#'     the file has neither.}
#'   \item{usage}{Character string, the code to import the standalone file using
#'     `usethis::use_standalone()`.}
#' }
#'
#' @details The crawl runs in Rust. One request lists the `R/` directory through
#'   the GitHub contents API; the listing is then filtered on the "standalone-"
#'   prefix, sorted by file name and deduplicated, and the provenance header of
#'   each remaining file is read with one download of its raw contents.
#'
#' @examples
#' \dontrun{
#' inquire_standalone("r-lib", "rlang")
#' }
#' @export
inquire_standalone <- function(owner, repo, ..., token = NULL) {
  rlang::check_dots_empty()
  rlang::check_installed("tibble")
  rlang::check_string(owner)
  repo_spec <- if (grepl("/", owner)) {
    owner
  } else {
    paste0(owner, "/", repo)
  }

  on.exit(cli::cli_progress_done())
  cli::cli_progress_step(
    "Listing the standalone files of {.val {repo_spec}}",
    spinner = TRUE
  )
  .standalone_tibble(inquire_standalone_rs(repo_spec, .standalone_token(token)))
}

# Shared with browse_standalone(): the crawlers receive the token as an
# argument, so that the environment is read in exactly one place.
.standalone_token <- function(token = NULL) {
  if (!is.null(token)) {
    rlang::check_string(token, allow_empty = TRUE, arg = "token")
    return(token)
  }
  pat <- Sys.getenv("GITHUB_PAT")
  if (!nzchar(pat)) {
    pat <- Sys.getenv("GITHUB_TOKEN")
  }
  if (nzchar(pat)) pat else ""
}

# The Rust crawlers return a named list of equally long columns.
.standalone_tibble <- function(columns) {
  tibble::as_tibble(as.data.frame(columns, stringsAsFactors = FALSE))
}
