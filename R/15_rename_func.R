#' Rename Function Definitions in an R File
#'
#' @description
#' Renames function definitions in an R file to follow a consistent naming
#' convention. Supports `"snake_case"`, `"camelCase"`, `"PascalCase"`, and
#' `"google"` (dot-separated) naming styles. All references to the renamed
#' functions within the file are also updated.
#'
#' @param path A character string specifying the path to the R file to modify.
#'   If `NULL` and RStudio is available, the currently active document path is used.
#' @param style Naming convention to apply. One of:
#'   - `"snake_case"`: all lowercase with underscores (e.g., `my_function`)
#'   - `"camelCase"`: lower camel case (e.g., `myFunction`)
#'   - `"PascalCase"`: upper camel case (e.g., `MyFunction`)
#'   - `"google"`: dot-separated lowercase (e.g., `my.function`)
#' @param ... Additional arguments. Currently unused and must be empty.
#'
#' @return
#' Invisibly returns the path to the modified file.
#'
#' @details
#' Function definitions are identified using the pattern
#' `name <- function(`, `name = function(`, or the R 4.1+ shorthand
#' `name <- \\(` / `name = \\(`. Both the definition site and all
#' call sites / references within the file are updated. The conversion handles
#' mixed existing styles (snake_case, camelCase, PascalCase, dot.separated)
#' and normalizes function names to the target style.
#'
#' @examples
#' \donttest{
#' temp <- tempfile(fileext = ".R")
#' writeLines("foo_bar <- function(){message('foo_bar')}", temp)
#' rename_func(temp, style = "camelCase")
#' readLines(temp)
#' rename_func(temp, style = "snake_case")
#' readLines(temp)
#' }
#'
#' @export
rename_func <- function(
  path = NULL,
  style = c("snake_case", "camelCase", "PascalCase", "google"),
  ...
) {
  rlang::check_dots_empty()

  path <- if (is.null(path) && rlang::is_installed("rstudioapi")) {
    rstudioapi::getActiveDocumentContext()$path
  } else if (is.null(path)) {
    cli::cli_abort(c("x" = "{.arg path} is required when not in RStudio."))
  } else {
    path
  }

  style <- match_arg(
    style,
    c("snake_case", "camelCase", "PascalCase", "google")
  )

  lines <- readLines(path, warn = FALSE)

  # Detect function definitions: `?name`? <- function(  or  `?name`? = function(
  old_names <- detect_func_defs(lines)

  if (length(old_names) == 0L) {
    cli::cli_alert_info("No function definitions found in {.file {path}}")
    return(invisible(path))
  }

  # Convert each function name to the target style
  new_names <- vapply(
    old_names,
    to_style,
    character(1L),
    style = style,
    USE.NAMES = FALSE
  )

  # Drop names that are already in the target style
  changed <- old_names != new_names
  old_names <- old_names[changed]
  new_names <- new_names[changed]

  if (length(old_names) == 0L) {
    cli::cli_alert_info(
      "All function names already in {.val {style}} style."
    )
    return(invisible(path))
  }

  # Sort by descending name length so shorter names don't clobber longer ones
  ord <- order(nchar(old_names), decreasing = TRUE)
  old_names <- old_names[ord]
  new_names <- new_names[ord]

  text <- paste(lines, collapse = "\n")
  n_renamed <- 0L

  for (i in seq_along(old_names)) {
    # Escape regex special characters in the name (dots, etc.)
    escaped <- gsub(
      "([.\\\\|()\\[\\{^$*+?])",
      "\\\\\\1",
      old_names[i],
      perl = TRUE
    )
    # Use negative look-behind / look-ahead to match whole R identifiers
    pattern <- paste0("(?<![a-zA-Z0-9._])", escaped, "(?![a-zA-Z0-9._])")

    if (grepl(pattern, text, perl = TRUE)) {
      text <- gsub(pattern, new_names[i], text, perl = TRUE)
      n_renamed <- n_renamed + 1L
    }
  }

  writeLines(text, path)
  cli::cli_alert_success(
    "Renamed {n_renamed} function{?s} to {.val {style}} style in {.file {path}}"
  )

  invisible(path)
}

# ---------------------------------------------------------------------------
# Helper: detect function definitions line by line
# ---------------------------------------------------------------------------

detect_func_defs <- function(lines) {
  # Match: name <- function( / name = function(  or  name <- \( / name = \(
  # Allows optional backtick quoting on the name
  pattern <- "`?((?:[a-zA-Z._][a-zA-Z0-9._]*)|(?:`[^`]+`))`?\\s*(?:<-|=)\\s*(?:function\\s*\\(|\\\\\\s*\\()"
  names <- character()

  for (line in lines) {
    m <- regexec(pattern, line, perl = TRUE)
    match_data <- regmatches(line, m)[[1L]]
    if (length(match_data) > 1L) {
      # Strip surrounding backticks (if any) and trim whitespace
      nm <- gsub("^`|`$", "", match_data[2L])
      names <- c(names, nm)
    }
  }

  unique(names)
}

# ---------------------------------------------------------------------------
# Helper: convert an R identifier to a target naming style
# ---------------------------------------------------------------------------

to_style <- function(name, style) {
  # Step 1 -- insert underscore before uppercase-letter transitions
  # e.g. "myFunctionName" -> "my_Function_Name"
  name <- gsub("([a-z0-9])([A-Z])", "\\1_\\2", name, perl = TRUE)

  # Step 2 -- split by common separators (underscore, dot) and normalize
  name <- gsub("[_.]+", " ", name)

  # Step 3 -- lowercase and split into words
  words <- strsplit(tolower(name), " ")[[1L]]
  words <- words[nzchar(words)]

  if (length(words) == 0L) {
    return(name)
  }

  switch(
    style,
    snake_case = paste(words, collapse = "_"),
    camelCase = {
      head <- words[1L]
      if (length(words) > 1L) {
        tail <- paste0(
          toupper(substr(words[-1L], 1L, 1L)),
          substr(words[-1L], 2L, nchar(words[-1L])),
          collapse = ""
        )
        paste0(head, tail)
      } else {
        head
      }
    },
    PascalCase = paste0(
      toupper(substr(words, 1L, 1L)),
      substr(words, 2L, nchar(words)),
      collapse = ""
    ),
    google = paste(words, collapse = ".")
  )
}
