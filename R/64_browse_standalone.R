#' @title Browse Standalone R Files Across GitHub
#'
#' @description Search GitHub for all `standalone-*.R` files and return the file
#'   and repository metadata of the matches as a tibble.
#'
#' @param per_page Number of items to request per page, between 1 and 100.
#'   Defaults to `100L`, the largest page GitHub serves.
#' @param limit Number of records to return. Defaults to `200L`; use `Inf` to
#'   request every record GitHub exposes. Each page of `per_page` records costs
#'   one search request, so a large `limit` can take a while.
#' @param ... No arguments.
#' @param token A GitHub personal access token. When `NULL` (the default) the
#'   token is read from the `GITHUB_PAT` or `GITHUB_TOKEN` environment variable;
#'   without a token GitHub only allows 60 requests per hour.
#'
#' @return A tibble with columns:
#' \describe{
#'   \item{repo}{Character. Repository identifier in "owner/repo" format.}
#'   \item{name}{Character. File name (e.g. "standalone-utils.R").}
#'   \item{path}{Character. File path within the repository (e.g. "R/standalone-utils.R").}
#'   \item{sha}{Character. File SHA.}
#'   \item{url}{Character. GitHub API URL for the file.}
#'   \item{html_url}{Character. GitHub HTML URL for the file.}
#'   \item{git_url}{Character. Git blob URL for the file.}
#'   \item{repo_url}{Character. Repository URL on GitHub.}
#'   \item{repo_description}{Character. Repository description from GitHub.}
#' }
#'
#' @details The crawl runs in Rust. It queries the GitHub Code Search API
#'   (\code{GET /search/code}) with
#'   \code{filename:standalone- language:R -filename:import-}, pages through the
#'   results until \code{limit} rows are collected, drops the hits whose name does
#'   not start with "standalone-" and removes duplicates. The search API ranks by
#'   relevance and exposes at most 1,000 results, which covers the vast majority
#'   of standalone files on GitHub.
#'
#' @note Without a token GitHub applies strict rate limits (60 requests per
#'   hour). Set \code{GITHUB_PAT} in \code{~/.Renviron} to lift them.
#'
#' @examples
#' \dontrun{
#'   browse_standalone()
#' }
#'
#' @export
browse_standalone <- function(
  per_page = 100L,
  limit = 200L,
  ...,
  token = NULL
) {
  rlang::check_dots_empty()
  rlang::check_installed("tibble")
  # rpkgkit: not int
  rlang::check_number_whole(per_page, min = 1, max = 100)
  # rpkgkit: not int
  rlang::check_number_whole(limit, min = 1, allow_infinite = TRUE)

  cli::cli_progress_step(
    "Searching GitHub for standalone-*.R files",
    spinner = TRUE
  )

  rows <- .standalone_tibble(
    browse_standalone_rs(
      per_page = as.integer(per_page),
      limit = as.numeric(limit),
      token = .standalone_token(token)
    )
  )

  cli::cli_progress_done()
  if (nrow(rows) == 0L) {
    warning("No standalone files found.")
  }
  rows
}
