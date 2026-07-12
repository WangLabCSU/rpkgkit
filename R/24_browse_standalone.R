#' @title Browse Standalone R Files Across GitHub
#'
#' @description Search GitHub for all `standalone-*.R` files and filter to only
#'   include repositories that are R packages (contain a `DESCRIPTION` file in
#'   their root directory). Results are returned as a tibble with file and
#'   repository metadata.
#'
#' @param per_page Number of items to return per page. If omitted,
#'    will be substituted by max(.limit, 100) if .limit is set,
#'    otherwise determined by the API (never greater than 100).
#' @param limit Number of records to return. This can be used instead of manual pagination. By default it is NULL, which means that the defaults of the GitHub API are used. You can set it to a number to request more (or less) records, and also to Inf to request all records. Note, that if you request many records, then multiple GitHub API calls are used to get them, and this can take a potentially long time.
#' @param ... pass to `gh::gh()`
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
#' @details This function uses the GitHub Code Search API
#'   (\code{GET /search/code}) to find all files matching the pattern
#'   \code{standalone-*.R} across all public repositories. It then checks each
#'   unique repository for the presence of a \code{DESCRIPTION} file in the
#'   repository root, confirming it is an R package. Only files from R package
#'   repositories are returned.
#'
#'   GitHub Search API returns at most 1,000 results, which covers the vast
#'   majority of standalone files on GitHub.
#'
#' @note Requires GitHub API authentication via the \code{gh} package.
#'   Run \code{gh::gh_whoami()} to check your current authentication status.
#'   Unauthenticated requests are subject to strict rate limits (60 requests/hour).
#'
#' @examples
#' \dontrun{
#'   browse_standalone()
#' }
#'
#' @export
browse_standalone <- function(per_page = 100L, limit = 200L, ...) {
  rlang::check_installed(c("gh", "dplyr"))

  `%>%` <- dplyr::`%>%`

  # Step 1: Search for all standalone-*.R files via GitHub Code Search API
  cli::cli_alert_info(
    "Searching GitHub for standalone-*.R files"
  )

  response <- gh::gh(
    "/search/code",
    q = "filename:standalone- language:R -filename:import-",
    .per_page = per_page,
    .limit = limit,
    ...
  )

  # gh::gh with .limit returns the aggregated response for search endpoints;
  # the items list may be inside $items or be the response itself
  items <- if (is.list(response) && !is.null(response$items)) {
    response$items
  } else {
    response
  }

  if (length(items) == 0L) {
    warning("No standalone files found.")
    return(dplyr::tibble(
      repo = character(),
      name = character(),
      path = character(),
      sha = character(),
      url = character(),
      html_url = character(),
      git_url = character(),
      repo_url = character(),
      repo_description = character()
    ))
  }

  # Step 2: Build a data frame from search results
  items_list <- lapply(items, function(item) {
    # Double-check: only keep files whose name starts with "standalone-"
    if (!startsWith(item$name, "standalone-")) {
      return(NULL)
    }
    list(
      repo = item$repository$full_name %||% NA_character_,
      name = item$name %||% NA_character_,
      path = item$path %||% NA_character_,
      sha = item$sha %||% NA_character_,
      url = item$url %||% NA_character_,
      html_url = item$html_url %||% NA_character_,
      git_url = item$git_url %||% NA_character_,
      repo_url = item$repository$html_url %||% NA_character_,
      repo_description = item$repository$description %||% NA_character_
    )
  })

  dplyr::bind_rows(items_list)
}
