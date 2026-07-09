#' Add or update a changelog entry in a standalone R file
#'
#' Appends a new changelog entry at the top of the `Changelog` section in a
#' standalone file. Also updates the `last-updated` field in the YAML header
#' to today's date. If no `Changelog` section exists, one is created after
#' the YAML header.
#'
#' @param path Character. Path to a standalone file, a directory, or `NULL`.
#'   If `NULL` and `rstudioapi` is available, uses the currently active document.
#'   If a directory, searches for standalone files matching the pattern.
#' @param description Character. Description of the changelog entry.
#'   If `NULL`, an interactive prompt is used (not yet implemented).
#' @param date Character. Date string in `YYYY-MM-DD` format.
#'   Defaults to today.
#'
#' @return Invisibly returns the path to the updated file.
#'
#' @examples
#' \donttest{
#' add_changelog_in_standalone(tempdir(), "Added new feature")
#' }
#' @export
add_changelog_in_standalone <- function(
  path = NULL,
  description = NULL,
  date = NULL
) {
  if (is.null(description) || is.na(description) || !nzchar(description)) {
    cli::cli_abort("{.arg description} is required.")
  }

  if (is.null(date)) {
    date <- format(Sys.time(), "%Y-%m-%d")
  }

  if (is.null(path) && rlang::is_installed("rstudioapi")) {
    path <- rstudioapi::getActiveDocumentContext()$path
  }

  if (is.null(path) || is.na(path) || !nzchar(path)) {
    cli::cli_abort("{.arg path} is required.")
  }

  if (file.exists(path) && !dir.exists(path)) {
    files <- path
  } else if (is_pkg(path)) {
    files <- list.files(
      file.path(path, "R"),
      pattern = "^standalone-|^vendor-",
      full.names = TRUE
    )
  } else if (dir.exists(path)) {
    files <- list.files(
      path,
      pattern = "^standalone-|^vendor-",
      full.names = TRUE
    )
  } else {
    cli::cli_abort("{.path {path}} does not exist.")
  }

  if (length(files) == 0L) {
    cli::cli_inform("No standalone files found.")
    return(invisible(character()))
  }

  updated <- vapply(
    files,
    function(f) {
      lines <- readLines(f, warn = FALSE)

      yaml_end <- which(lines == "# ---" | grepl(pattern = "# =+", x = lines))
      if (length(yaml_end) < 2L) {
        cli::cli_warn("No valid YAML header found in {.path {f}}.")
        return(FALSE)
      }
      yaml_end <- yaml_end[2L]

      lastupdated_idx <- grep(
        "^#\\s+last-updated:\\s*",
        lines,
        ignore.case = TRUE
      )
      if (length(lastupdated_idx) > 0L) {
        lines[lastupdated_idx] <- sprintf("# last-updated: %s", date)
      }

      changelog_idx <- grep("^#\\s+Changelog:", lines)

      if (length(changelog_idx) == 0L) {
        insert_pos <- yaml_end + 1L
        blank_before <- if (lines[insert_pos] == "#") 1L else 0L
        if (blank_before == 1L) {
          insert_pos <- insert_pos + 1L
        }
        new_lines <- c(
          "#",
          "# ## Changelog:",
          "#",
          sprintf("# %s:", date),
          sprintf("# * %s", description),
          "#"
        )
        lines <- append(lines, new_lines, after = insert_pos - 1L)
      } else {
        idx <- changelog_idx[1L]
        blank_comment <- if (lines[idx + 1L] == "#") 1L else 0L

        new_lines <- c(
          "#",
          sprintf("# %s:", date),
          sprintf("# %s", description)
        )

        if (blank_comment == 1L) {
          insert_pos <- idx + 2L
        } else {
          insert_pos <- idx + 1L
        }

        if (lines[insert_pos] == "#") {
          insert_pos <- insert_pos + 1L
        }

        lines <- append(lines, new_lines, after = insert_pos - 1L)
      }

      writeLines(lines, con = f)
      TRUE
    },
    FUN.VALUE = logical(1L)
  )

  cli::cli_alert_success(
    "Added changelog entry ({date}) for {.path {files}}."
  )

  invisible(files[updated])
}
