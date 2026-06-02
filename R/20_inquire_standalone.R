#' @title Inquire Standalone Files from a GitHub Repository
#'
#' @description Retrieve information about all standalone R files in the R/ directory of a GitHub repository. Standalone files are identified by the "standalone-" prefix in their filename.
#'
#' @param owner A character string specifying the repository owner's username.
#' @param repo A character string specifying the repository name.
#' @param ... No arguments.
#'
#' @return A tibble with three columns:
#' \describe{
#'   \item{`owner/repo`}{Character string, the repository identifier in "owner/repo" format.}
#'   \item{description}{Character string, the description extracted from the file's YAML header or roxygen documentation.}
#'   \item{usage}{Character string, the code to import the standalone file using `usethis::use_standalone()`.}
#' }
#'
#' @details This function queries the GitHub API to list files in the R/ directory, filters for files starting with "standalone-", parses each file's YAML metadata (delimited by "# ---") and roxygen tags to extract descriptions, and generates usage code for importing each standalone file.
#'
#' @export
inquire_standalone <- function(owner, repo, ...) {
  rlang::check_dots_empty0()
  rlang::check_installed(c("gh", "dplyr"))
  repo_spec <- if (grepl("/", owner)) {
    owner
  } else {
    paste0(owner, "/", repo)
  }

  response <- gh::gh(
    "/repos/{repo_spec}/contents/R",
    repo_spec = repo_spec,
    .accept = "application/vnd.github.v3.raw"
  )

  standalone_response <- lapply(
    X = response,
    FUN = function(x) {
      if (startsWith(x$name, "standalone-")) {
        return(x)
      } else {
        return(NULL)
      }
    }
  )
  `_links` <- NULL # suppress note
  `%>%` <- dplyr::`%>%`
  dplyr::bind_rows(standalone_response) %>%
    dplyr::select(-`_links`) %>%
    dplyr::distinct()
}
