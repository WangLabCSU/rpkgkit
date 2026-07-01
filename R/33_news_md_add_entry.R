#' Add a new entry to NEWS.md
#'
#' @description
#' Adds a new entry to the NEWS.md file following CRAN guidelines.
#' Can create a new version section if needed or add to an existing one.
#'
#' @param entry Text of the news entry (without leading "* ").
#' @param version Package version number. If NULL, uses the version from DESCRIPTION.
#' @param category Category of the change (e.g., "NEW FEATURES", "BUG FIXES",
#'   "MINOR IMPROVEMENTS", "DOCUMENTATION", "DEPRECATED",
#'   "DEFUNCT", "BREAKING CHANGES", "PERFORMANCE", "TESTING",
#'   "INTERNAL CHANGES"). Default is "NEW FEATURES".
#' @param contributor GitHub username or name for attribution (optional).
#' @param path Path to the package root. If \code{NULL} (the default), uses
#'   the current working directory.
#' @param date Date of the release. If NULL, uses today's date (YYYY-MM-DD format).
#' @param open_section If TRUE and the version section exists but isn't open
#'   (has content after it), creates a new section. If FALSE, adds to existing section.
#'
#' @return Invisibly returns the path to the NEWS.md file.
#' @export
#'
#' @rdname news_md
#'
#' @examples
#' \dontrun{
#' temp <- tempdir()
#' usethis::create_package(temp)
#' file.create(file.path(temp, "NEWS.md"))
#' # Add a bug fix entry
#' news_md_add_entry("Fixed issue with parsing large files.",
#'                   category = "BUG FIXES",
#'                   contributor = "johndoe",
#'                   path = temp)
#'
#' # Add a new feature with specific version
#' news_md_add_entry("Added new function for data validation.",
#'                   version = "1.2.0",
#'                   category = "NEW FEATURES",
#'                   path = temp)
#' }
news_md_add_entry <- function(
  entry,
  version = NULL,
  category = "NEW FEATURES",
  contributor = NULL,
  path = NULL,
  date = NULL,
  open_section = TRUE
) {
  path <- path %||% "."
  category <- match_arg(
    category,
    c(
      "NEW FEATURES",
      "BUG FIXES",
      "MINOR IMPROVEMENTS",
      "DOCUMENTATION",
      "DEPRECATED",
      "DEFUNCT",
      "BREAKING CHANGES",
      "PERFORMANCE",
      "TESTING",
      "INTERNAL CHANGES"
    )
  )

  # Get version from DESCRIPTION if not provided
  desc_path <- file.path(path, "DESCRIPTION")
  if (is.null(version)) {
    if (!file.exists(desc_path)) {
      cli::cli_abort(c(
        "x" = "DESCRIPTION file not found at {.path {desc_path}}",
        "i" = "Please provide {.arg path} to package root or {.arg version}"
      ))
    }
    version <- read.dcf(desc_path)[, "Version"]
  }

  # Set date if not provided
  if (is.null(date)) {
    date <- format(Sys.Date(), "%Y-%m-%d")
  }

  # Format contributor if provided
  contributor_str <- if (!is.null(contributor)) {
    sprintf(" (@%s)", contributor)
  } else {
    ""
  }

  # Get package name from DESCRIPTION (must exist if we reach here)
  if (!file.exists(desc_path)) {
    cli::cli_abort(c(
      "x" = "DESCRIPTION file not found at {.path {desc_path}}",
      "i" = "Please provide {.arg path} to package root"
    ))
  }
  pkg_name <- read.dcf(desc_path)[, "Package"]

  # Vectorized entry formatting: ensure each starts with "* " and has contributor
  entry <- trimws(entry)
  needs_star <- !grepl("^\\*", entry)
  entry[needs_star] <- paste0("* ", entry[needs_star])
  if (!is.null(contributor)) {
    has_attr <- grepl("\\([^)]+\\)\\s*$", entry)
    entry[!has_attr] <- sub("\\s*$", contributor_str, entry[!has_attr])
  }

  news_path <- file.path(path, "NEWS.md")

  # Read existing NEWS.md or create new
  if (file.exists(news_path)) {
    lines <- readLines(news_path, warn = FALSE)
  } else {
    lines <- character(0)
  }

  # Create version header
  version_header <- sprintf("# %s %s (%s)", pkg_name, version, date)

  # Find existing version section
  # Header format: "# pkgname X.Y.Z (YYYY-MM-DD)", so match version before "("
  version_pattern <- sprintf(
    "^#\\s+%s\\s+%s\\s+\\(",
    pkg_name,
    gsub("\\.", "\\\\.", version)
  )
  version_idx <- grep(version_pattern, lines)

  if (length(version_idx) == 0) {
    # No existing version section - create new one at the top
    category_header <- sprintf("## %s", category)
    new_lines <- c(
      version_header,
      "",
      category_header,
      "",
      entry,
      "",
      if (length(lines) > 0) "" else NULL,
      lines
    )
  } else {
    # Version section exists
    idx <- version_idx[1]

    # Check if this section has content (not just header)
    # Find next version header or end of file
    next_version_idx <- grep("^#\\s+", lines[(idx + 1):length(lines)])
    if (length(next_version_idx) == 0) {
      section_end <- length(lines)
    } else {
      section_end <- idx + next_version_idx[1] - 1
    }

    # Check if section is "open" (last meaningful content is a category we can add to)
    section_content <- lines[(idx + 1):section_end]
    non_empty_idx <- which(nzchar(trimws(section_content)))

    if (length(non_empty_idx) == 0 || !open_section) {
      # Section is empty or we want a new section - add new category
      category_header <- sprintf("## %s", category)

      # Insert after version header
      insert_pos <- idx + 1

      # Check if category already exists right after version header
      existing_cat_pattern <- sprintf("^##\\s+%s\\s*$", category)
      cat_idx <- grep(existing_cat_pattern, lines)

      if (
        length(cat_idx) > 0 &&
          cat_idx[1] > idx &&
          (length(next_version_idx) == 0 ||
            cat_idx[1] < idx + next_version_idx[1])
      ) {
        # Category exists, add entry there
        # Find where to insert (after category header and blank line)
        insert_pos <- cat_idx[1] + 1
        while (
          insert_pos <= section_end && !nzchar(trimws(lines[insert_pos]))
        ) {
          insert_pos <- insert_pos + 1
        }

        new_lines <- c(
          lines[1:(insert_pos - 1)],
          entry,
          "",
          lines[insert_pos:length(lines)]
        )
      } else {
        # Add new category section
        new_lines <- c(
          lines[1:idx],
          "",
          category_header,
          "",
          entry,
          "",
          lines[(idx + 1):length(lines)]
        )
      }
    } else {
      # Section has content - check if our category exists
      existing_cat_pattern <- sprintf("^##\\s+%s\\s*$", category)
      cat_idx <- grep(existing_cat_pattern, lines[idx:section_end])

      if (length(cat_idx) > 0) {
        # Category exists in this section
        cat_pos <- idx + cat_idx[1] - 1
        # Find position to insert (after category header and blank lines)
        insert_pos <- cat_pos + 1
        while (
          insert_pos <= section_end && !nzchar(trimws(lines[insert_pos]))
        ) {
          insert_pos <- insert_pos + 1
        }

        new_lines <- c(
          lines[1:(insert_pos - 1)],
          entry,
          "",
          lines[insert_pos:length(lines)]
        )
      } else {
        # Add new category to existing version section
        category_header <- sprintf("## %s", category)
        insert_pos <- idx + 1

        new_lines <- c(
          lines[1:idx],
          "",
          category_header,
          "",
          entry,
          "",
          lines[(idx + 1):length(lines)]
        )
      }
    }
  }

  # Write back to file
  writeLines(new_lines, news_path)

  cli::cli_inform(c(
    "v" = "Added {length(entry)} entr{?y/ies} to {.path {news_path}}",
    ">" = "Version: {.pkg {version}}, Category: {.field {category}}"
  ))

  invisible(news_path)
}
