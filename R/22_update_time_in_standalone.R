#' Update the last-updated field in standalone R files
#'
#' Updates the `last-updated` field in the YAML header of standalone files
#' to today's date. Supports single file or batch update for all standalone
#' files in a directory.
#'
#' @param path Character. Path to a standalone file or a directory. If `NULL`
#'   and `rstudioapi` is available, uses the currently active document.
#'   Defaults to NULL.
#'
#' @return Invisibly returns a character vector of updated file paths.
#'
#' @examples
#' \dontrun{
#' update_time_in_standalone(tempdir())
#' }
#' @export
update_time_in_standalone <- function(path = NULL) {
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
      pattern = "^standalone-",
      full.names = TRUE
    )
  } else if (dir.exists(path)) {
    files <- list.files(path, pattern = "^standalone-", full.names = TRUE)
  } else {
    cli::cli_abort("{.path {path}} does not exist.")
  }

  if (length(files) == 0L) {
    cli::cli_inform("No standalone files found.")
    return(invisible(character()))
  }

  today <- format(Sys.time(), "%Y-%m-%d")

  updated <- vapply(
    X = files,
    FUN = function(f) {
      lines <- readLines(f, warn = FALSE)
      idx <- grep("^#\\s+last-updated:\\s*", lines)

      if (length(idx) == 0L) {
        cli::cli_warn("No {.field last-updated} field found in {.path {f}}.")
        return(FALSE)
      }

      lines[idx] <- sprintf("# last-updated: %s", today)
      writeLines(lines, con = f)
      TRUE
    },
    FUN.VALUE = logical(1)
  )

  cli::cli_alert_success(
    "Updated {.field last-updated} to {.val {today}} in {sum(updated)} file{?s}."
  )

  invisible(files[updated])
}
