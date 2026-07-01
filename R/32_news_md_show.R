#' Display NEWS.md content in a formatted way
#'
#' @description
#' Reads and displays the NEWS.md file content with optional filtering.
#'
#' @param path Path to the package root. If \code{NULL} (the default), uses
#'   the current working directory.
#' @param version Show only entries for a specific version. Use "latest" for most recent.
#' @param max_versions Maximum number of versions to display. NULL shows all.
#'
#' @return Invisibly returns the content as a character vector.
#' @export
#'
#' @rdname news_md
#'
#' @examples
#' \dontrun{
#' temp <- tempdir()
#' usethis::create_package(temp)
#' file.create(file.path(temp, "NEWS.md"))
#' news_md_add_entry("Added `foo()`", path = temp)
#'
#' # Show latest version news
#' news_md_show(version = "latest", path = temp)
#'
#' # Show last 3 versions
#' news_md_show(max_versions = 3, path = temp)
#' }
news_md_show <- function(path = NULL, version = NULL, max_versions = NULL) {
  path <- path %||% "."
  news_path <- file.path(path, "NEWS.md")

  if (!file.exists(news_path)) {
    cli::cli_abort(c("x" = "NEWS.md not found at {.path {news_path}}"))
  }

  lines <- readLines(news_path, warn = FALSE)

  # Find version sections
  version_pattern <- "^#\\s+"
  version_starts <- grep(version_pattern, lines)

  if (length(version_starts) == 0) {
    cli::cli_warn("No version sections found in NEWS.md")
    return(invisible(lines))
  }

  # Determine which versions to show
  if (!is.null(version)) {
    if (version == "latest") {
      start_idx <- version_starts[1]
      end_idx <- if (length(version_starts) > 1) {
        version_starts[2] - 1
      } else {
        length(lines)
      }
    } else {
      # Find specific version
      found <- FALSE
      for (i in seq_along(version_starts)) {
        if (grepl(version, lines[version_starts[i]])) {
          start_idx <- version_starts[i]
          end_idx <- if (i < length(version_starts)) {
            version_starts[i + 1] - 1
          } else {
            length(lines)
          }
          found <- TRUE
          break
        }
      }
      if (!found) {
        cli::cli_abort(c("x" = "Version '{version}' not found in NEWS.md"))
      }
    }
  } else if (!is.null(max_versions)) {
    start_idx <- version_starts[1L]
    end_idx <- if (max_versions >= length(version_starts)) {
      length(lines)
    } else {
      version_starts[max_versions + 1L] - 1L
    }
  } else {
    start_idx <- 1L
    end_idx <- length(lines)
  }

  content <- lines[start_idx:end_idx]
  md_colorfully_show(content)

  invisible(content)
}

#' @keywords internal
md_colorfully_show <- function(content) {
  colorful_cli <- create_colorful_cli_env(cli_func = "cli_inform")

  for (line in content) {
    # Replace backtick-wrapped text (including backticks) with green cli formatting
    formatted <- gsub("(`[^`]+`)", "{.green \\1}", line, perl = TRUE)
    # If line starts with #, wrap with blue formatting
    if (grepl("^#", formatted)) {
      formatted <- paste0("{.blue ", formatted, "}")
    }
    colorful_cli$cli_inform(formatted)
  }

  invisible()
}
