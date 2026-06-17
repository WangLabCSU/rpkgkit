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
