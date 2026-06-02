#' Manage NEWS.md file for R packages
#'
#' @description
#' Functions to help manage the NEWS.md file in R packages according to CRAN
#' guidelines. Includes functions to add new entries and check the format.
#'
#' @details
#' The NEWS.md format follows CRAN recommendations:
#' - Version headers use `#` followed by "package version (date)"
#' - Major changes use `##` with category names (e.g., "NEW FEATURES", "BUG FIXES")
#' - Individual items use bullet points starting with `*`
#' - Contributor acknowledgments use `(@username)` at the end of items
#' - Dates should be in YYYY-MM-DD format
#'
#' @name news_md
#'
#'
NULL

#' Add a new entry to NEWS.md
#'
#' @description
#' Adds a new entry to the NEWS.md file following CRAN guidelines.
#' Can create a new version section if needed or add to an existing one.
#'
#' @param entry Text of the news entry (without leading "* ").
#' @param version Package version number. If NULL, uses the version from DESCRIPTION.
#' @param category Category of the change (e.g., "NEW FEATURES", "BUG FIXES",
#'   "MINOR IMPROVEMENTS", "DOCUMENTATION"). Default is "NEW FEATURES".
#' @param contributor GitHub username or name for attribution (optional).
#' @param path Path to the package root. If NULL, uses current working directory.
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
#' # Add a bug fix entry
#' news_md_add_entry("Fixed issue with parsing large files.",
#'                   category = "BUG FIXES",
#'                   contributor = "johndoe")
#'
#' # Add a new feature with specific version
#' news_md_add_entry("Added new function for data validation.",
#'                   version = "1.2.0",
#'                   category = "NEW FEATURES")
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
  path <- path %||% get_wd()
  category <- match_arg(
    category,
    c("NEW FEATURES", "BUG FIXES", "MINOR IMPROVEMENTS", "DOCUMENTATION")
  )

  # Get version from DESCRIPTION if not provided
  if (is.null(version)) {
    desc_path <- file.path(path, "DESCRIPTION")
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
  version_header <- sprintf("# %s %s (%s)", basename(path), version, date)

  # Find existing version section
  # Header format: "# pkgname X.Y.Z (YYYY-MM-DD)", so match version before "("
  version_pattern <- sprintf(
    "^#\\s+%s\\s+%s\\s+\\(",
    basename(path),
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

#' Check NEWS.md format for CRAN compliance
#'
#' @description
#' Validates the NEWS.md file against CRAN guidelines and common best practices.
#' Reports issues found and provides suggestions for fixes.
#'
#' @param path Path to the package root. If NULL, uses current working directory.
#' @param strict If TRUE, treats warnings as errors. Default is FALSE.
#' @param verbose If TRUE, prints detailed information about checks performed.
#'
#' @return A list with components:
#'   \describe{
#'     \item{valid}{Logical indicating if NEWS.md passes all checks.}
#'     \item{errors}{Character vector of error messages.}
#'     \item{warnings}{Character vector of warning messages.}
#'     \item{suggestions}{Character vector of improvement suggestions.}
#'   }
#' @export
#' @rdname news_md
#' @examples
#' \dontrun{
#' result <- news_md_check()
#' if (!result$valid) {
#'   print(result$errors)
#'   print(result$warnings)
#' }
#' }
news_md_check <- function(path = NULL, strict = FALSE, verbose = TRUE) {
  path <- path %||% get_wd()
  news_path <- file.path(path, "NEWS.md")

  result <- list(
    valid = TRUE,
    errors = character(0),
    warnings = character(0),
    suggestions = character(0)
  )

  # Check if file exists
  if (!file.exists(news_path)) {
    result$valid <- FALSE
    result$errors <- c(result$errors, "NEWS.md file not found")
    return(result)
  }

  lines <- readLines(news_path, warn = FALSE)

  if (verbose) {
    cli::cli_alert_info("Checking NEWS.md with {length(lines)} lines")
  }

  # Track state
  has_version_header <- FALSE
  has_entries <- FALSE
  in_version_section <- FALSE
  current_version <- NULL

  prev_line <- ""
  line_num <- 0

  for (i in seq_along(lines)) {
    line <- lines[i]
    line_num <- i

    # Check for version header (# package version (date))
    if (grepl("^#\\s+\\S+\\s+\\S+\\s+\\(", line)) {
      has_version_header <- TRUE
      in_version_section <- TRUE

      # Validate version header format
      if (
        !grepl(
          "^#\\s+\\S+\\s+[0-9]+\\.[0-9]+\\.[0-9]+[^a-zA-Z]*\\s+\\([0-9]{4}-[0-9]{2}-[0-9]{2}\\)",
          line
        )
      ) {
        msg <- sprintf(
          "Line %d: Version header should follow format '# pkgname X.Y.Z (YYYY-MM-DD)'",
          line_num
        )
        if (strict) {
          result$valid <- FALSE
          result$errors <- c(result$errors, msg)
        } else {
          result$warnings <- c(result$warnings, msg)
        }
      }

      # Extract version for tracking
      matches <- regmatches(
        line,
        regexpr("[0-9]+\\.[0-9]+\\.[0-9]+[^\\)]*", line)
      )
      if (length(matches) > 0) {
        current_version <- matches
      }

      # Check blank line before version header (except first)
      if (line_num > 1 && nzchar(trimws(prev_line))) {
        msg <- sprintf(
          "Line %d: Blank line recommended before version header",
          line_num
        )
        result$suggestions <- c(result$suggestions, msg)
      }
    }

    # Check for category headers (## CATEGORY)
    if (grepl("^##\\s+", line)) {
      if (!in_version_section) {
        msg <- sprintf(
          "Line %d: Category header found outside version section",
          line_num
        )
        result$valid <- FALSE
        result$errors <- c(result$errors, msg)
      }

      # Check category naming conventions
      category <- trimws(sub("^##\\s+", "", line))
      standard_categories <- c(
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

      if (!toupper(category) %in% toupper(standard_categories)) {
        msg <- sprintf(
          "Line %d: Non-standard category '%s'. Consider using standard categories like: %s",
          line_num,
          category,
          paste(standard_categories[1:4], collapse = ", ")
        )
        result$suggestions <- c(result$suggestions, msg)
      }

      # Check blank line before category header
      if (nzchar(trimws(prev_line)) && !grepl("^#", prev_line)) {
        msg <- sprintf(
          "Line %d: Blank line recommended before category header",
          line_num
        )
        result$suggestions <- c(result$suggestions, msg)
      }
    }

    # Check for bullet points (* item)
    if (grepl("^\\s*\\*\\s+", line)) {
      has_entries <- TRUE

      # Check for proper spacing
      if (!grepl("^\\* [A-Z]", line)) {
        msg <- sprintf(
          "Line %d: Bullet points should start with '* ' followed by capital letter",
          line_num
        )
        result$suggestions <- c(result$suggestions, msg)
      }

      # Check for period at end (if not a short phrase)
      trimmed <- trimws(sub("^\\s*\\*\\s+", "", line))
      if (nchar(trimmed) > 50 && !grepl("[.!?]\\s*$", trimmed)) {
        msg <- sprintf(
          "Line %d: Longer entries should end with punctuation",
          line_num
        )
        result$suggestions <- c(result$suggestions, msg)
      }

      # Check for contributor attribution format (@username)
      if (grepl("@[a-zA-Z][a-zA-Z0-9_-]*", line)) {
        if (!grepl("\\(\\s*@[a-zA-Z][a-zA-Z0-9_-]*\\s*\\)", line)) {
          msg <- sprintf(
            "Line %d: Contributor mentions should be in parentheses: (@username)",
            line_num
          )
          result$suggestions <- c(result$suggestions, msg)
        }
      }

      # Check for issue/PR references
      if (grepl("#[0-9]+", line)) {
        if (!grepl("\\(#[0-9]+\\)", line)) {
          msg <- sprintf(
            "Line %d: Issue/PR references should be in parentheses: (#123)",
            line_num
          )
          result$suggestions <- c(result$suggestions, msg)
        }
      }
    }

    # Check for dates in entries (should be in header, not entries)
    if (grepl("^\\s*\\*", line) && grepl("[0-9]{4}-[0-9]{2}-[0-9]{2}", line)) {
      msg <- sprintf(
        "Line %d: Dates should be in version headers, not individual entries",
        line_num
      )
      result$suggestions <- c(result$suggestions, msg)
    }

    prev_line <- line
  }

  # Final checks
  if (!has_version_header) {
    result$valid <- FALSE
    result$errors <- c(
      result$errors,
      "No version headers found. Use format: # pkgname X.Y.Z (YYYY-MM-DD)"
    )
  }

  if (!has_entries) {
    result$warnings <- c(result$warnings, "No bullet point entries found")
  }

  # Check for trailing whitespace
  trailing_ws <- grep("\\s+$", lines)
  if (length(trailing_ws) > 0) {
    msg <- sprintf(
      "Lines with trailing whitespace: %s",
      paste(trailing_ws, collapse = ", ")
    )
    result$suggestions <- c(result$suggestions, msg)
  }

  # Check file ends with newline
  if (length(lines) > 0 && !grepl("^\\s*$", lines[length(lines)])) {
    result$suggestions <- c(
      result$suggestions,
      "File should end with a blank line"
    )
  }

  # Summary message
  if (verbose) {
    if (result$valid) {
      cli::cli_alert_success("NEWS.md passed all required checks")
    } else {
      cli::cli_alert_danger("NEWS.md has {length(result$errors)} error(s)")
    }

    if (length(result$warnings) > 0) {
      cli::cli_alert_warning("{length(result$warnings)} warning(s)")
    }

    if (length(result$suggestions) > 0) {
      cli::cli_alert_info(
        "{length(result$suggestions)} suggestion(s) for improvement"
      )
    }
  }

  result
}

#' Display NEWS.md content in a formatted way
#'
#' @description
#' Reads and displays the NEWS.md file content with optional filtering.
#'
#' @param path Path to the package root. If NULL, uses current working directory.
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
#' # Show latest version news
#' news_md_show(version = "latest")
#'
#' # Show last 3 versions
#' news_md_show(max_versions = 3)
#' }
news_md_show <- function(path = NULL, version = NULL, max_versions = NULL) {
  path <- path %||% get_wd()

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
    start_idx <- version_starts[1]
    end_idx <- if (max_versions >= length(version_starts)) {
      length(lines)
    } else {
      version_starts[max_versions + 1] - 1
    }
  } else {
    start_idx <- 1
    end_idx <- length(lines)
  }

  content <- lines[start_idx:end_idx]
  cat(content, sep = "\n")

  invisible(content)
}
