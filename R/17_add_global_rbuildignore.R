#' Global `.Rbuildignore` patterns
#'
#' Default regular-expression patterns used by [add_global_rbuildignore()].
#'
#' @export
GLOBAL_RBUILDIGNORE_PATTERN <- c(
  "",
  "# ---- Global rbuildignore patterns ----",
  "",
  "# R build artifacts",
  "^\\.Rhistory$",
  "^\\.Rdata$",
  "^\\.Rcheck$",
  "^\\.Rapp\\.Rproj$",
  "^\\.Rapp\\.Rproj\\.user$",
  "^\\.Rapp\\.history$",
  "",
  "# Git",
  "^\\.git$",
  "^\\.gitignore$",
  "^\\.gitattributes$",
  "",
  "# IDE / dev tools",
  "^\\.codebuddy$",
  "^\\.fresh$",
  "^\\.vscode$",
  "^\\.lintr$",
  "^\\.positai$",
  "^\\.claude$",
  "^\\..Rcheck$",
  "^AGENTS\\.md",
  "",
  "# CI/CD",
  "^\\.github$",
  "^codecov\\.yml$",
  "",
  "# Documentation build artifacts",
  "^docs$",
  "^pkgdown$",
  "^_pkgdown\\.yml$",
  "^_pkgdown\\.yaml$",
  "^pkgdown\\.yaml$",
  "^pkgdown\\.yml$",
  "^README\\.Rmd$",
  "^cran-comments\\.md$",
  "",
  "# CRAN / development",
  "^CRAN-SUBMISSION$",
  "^revdep$",
  "^codemeta\\.json$",
  "^CITATION\\.cff$",
  "",
  "# Other common files",
  "^\\.imgbotconfig$",
  "^CODE_OF_CONDUCT\\.md$",
  "^CONTRIBUTING\\.md$",
  "^Rplots\\.pdf$",
  "^jarl\\.toml$",
  "^index\\.qmd$",
  "^index\\.html$",
  "^index\\.md$"
)

#' Add global .Rbuildignore patterns
#'
#' @description
#' Appends a curated set of common files and directories to `.Rbuildignore`
#' to exclude them from R package builds. This supplements the auto-generated
#' `.Rbuildignore` created by `usethis::create_package()`.
#'
#' Already-present patterns are silently skipped. The curated set covers:
#' R build artifacts, Git files, IDE/dev tool directories, CI/CD config,
#' documentation build artifacts, CRAN/development files, and other common
#' files that should not be shipped with a package.
#'
#' @param ... Additional regex patterns (character strings) to add beyond
#'   the selected patterns. Each must already be in `.Rbuildignore` regex
#'   format (e.g. `"^\\.myfile$"`).
#' @param pattern Character vector of `.Rbuildignore` patterns. By default,
#'   uses [rpkgkit::GLOBAL_RBUILDIGNORE_PATTERN].
#' @param replace_default Logical. If `FALSE` (the default), `pattern` is
#'   appended to [rpkgkit::GLOBAL_RBUILDIGNORE_PATTERN]. If `TRUE`, `pattern` is used instead
#'   of the defaults.
#' @param path Character. Path to the package root directory. If \code{NULL}
#'   (the default), uses the current working directory.
#'
#' @return Invisibly returns the path to `.Rbuildignore`.
#' @export
#'
#' @examples
#' \dontrun{
#' add_global_rbuildignore()
#'
#' # With additional custom patterns
#' add_global_rbuildignore("^\\.myconfig$", "^data-raw$")
#'
#' # Use only a custom pattern set
#' add_global_rbuildignore(
#'   pattern = c("^\\.github$", "^docs$"),
#'   replace_default = TRUE
#' )
#' }
add_global_rbuildignore <- function(
  ...,
  pattern = GLOBAL_RBUILDIGNORE_PATTERN,
  replace_default = FALSE,
  path = NULL
) {
  path <- path %||% "."
  if (!is_pkg(path)) {
    cli::cli_abort(c(
      "x" = "{.path {path}} is not an R package root.",
      ">" = "No {.file DESCRIPTION} found."
    ))
  }

  ignore_file <- file.path(path, ".Rbuildignore")

  # Read existing content
  if (file.exists(ignore_file)) {
    existing <- readLines(ignore_file, warn = FALSE)
  } else {
    existing <- character(0L)
  }

  # Extract existing patterns (non-comment, non-empty lines)
  existing_pats <- existing[!grepl("^\\s*(#|$)", existing)]

  if (!is.character(pattern)) {
    cli::cli_abort("{.arg pattern} must be a character vector.")
  }
  if (
    !is.logical(replace_default) ||
      length(replace_default) != 1L ||
      is.na(replace_default)
  ) {
    cli::cli_abort(
      "{.arg replace_default} must be a single non-missing logical value."
    )
  }

  default_block <- if (replace_default) {
    pattern
  } else {
    unique(c(GLOBAL_RBUILDIGNORE_PATTERN, pattern))
  }

  # Filter default block: keep blanks/headers, drop already-present patterns
  keep <- vapply(
    default_block,
    \(line) grepl("^\\s*(#|$)", line) || !(line %in% existing_pats),
    logical(1L)
  )
  new_lines <- default_block[keep]

  # Handle user-provided patterns
  user_pats <- unlist(list(...))
  if (length(user_pats) > 0L) {
    new_user <- user_pats[!(user_pats %in% existing_pats)]
    if (length(new_user) > 0L) {
      new_lines <- c(new_lines, "", "# Additional patterns", new_user)
    }
  }

  # Nothing to add
  pat_count <- sum(!grepl("^\\s*(#|$)", new_lines))
  if (pat_count == 0L) {
    cli::cli_alert_info(
      "All patterns already present in {.file .Rbuildignore}."
    )
    return(invisible(ignore_file))
  }

  writeLines(c(existing, new_lines), ignore_file)

  cli::cli_alert_success(
    "Added {pat_count} pattern(s) to {.file .Rbuildignore}."
  )
  invisible(ignore_file)
}
