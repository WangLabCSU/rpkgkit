#' Get the version of the Positron IDE
#'
#' @param long Whether to return the full version including the build number
#'   (e.g. "2025.01.0-123"). Defaults to FALSE.
#' @return A character string with the version number, or NA_character_ if not
#'   running inside Positron and the version cannot be located.
#' @export
get_positron_version <- function(long = FALSE) {
  # 1. Check whether the R session is running inside Positron
  in_positron <- identical(Sys.getenv("POSITRON"), "1")

  if (in_positron) {
    # 2. Positron sets these environment variables for its R sessions
    var <- if (long) "POSITRON_LONG_VERSION" else "POSITRON_VERSION"
    ver <- Sys.getenv(var, unset = "")
    if (nzchar(ver)) {
      return(ver)
    }

    # 3. Fallback: helper function injected by Positron into the R session
    get_version <- get0(
      ".ps.positron_version",
      envir = .GlobalEnv,
      mode = "function"
    )
    if (!is.null(get_version)) {
      ver <- tryCatch(get_version(), error = function(e) "")
      if (nzchar(ver)) return(as.character(ver))
    }
  }

  # 4. Not in Positron: try the command-line tool `positron --version`
  cli <- Sys.which("positron")
  if (nzchar(cli)) {
    out <- tryCatch(
      system2(cli, "--version", stdout = TRUE, stderr = FALSE),
      error = function(e) character()
    )
    if (length(out) > 0) return(trimws(out[1]))
  }

  # 5. Version could not be determined
  NA_character_
}
