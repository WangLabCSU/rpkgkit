#' Check that all exported functions are listed in pkgdown reference
#'
#' Parses the `NAMESPACE` and `_pkgdown.yml` (if present) and reports any
#' exported functions that are missing from the pkgdown reference index.
#'
#' @param pkg Character. Path to the package root directory.
#'   Defaults to the current RStudio project or `"."`.
#'
#' @return Invisibly returns a character vector of missing function names,
#'   or `NULL` if `_pkgdown.yml` does not exist. Prints a summary via `cli`.
#'
#' @examples
#' \dontrun{
#' check_pkgdown_reference()
#' }
#' @export
check_pkgdown_reference <- function(pkg = NULL) {
  if (is.null(pkg) || !nzchar(pkg)) {
    pkg <- "."
  }

  pkgdown_file <- file.path(pkg, "_pkgdown.yml")

  if (!file.exists(pkgdown_file)) {
    cli::cli_abort(c(
      "x" = "No {.path _pkgdown.yml} found in this package: {.path {pkg}}."
    ))
  }

  rlang::check_installed("yaml")

  namespace_file <- file.path(pkg, "NAMESPACE")
  if (!file.exists(namespace_file)) {
    cli::cli_abort(c("x" = "No {.path NAMESPACE} found in {.path {pkg}}."))
  }

  ns_lines <- readLines(namespace_file, warn = FALSE)
  exported <- unique(gsub(
    "^export\\(([^)]+)\\).*",
    "\\1",
    grep("^export\\(", ns_lines, value = TRUE)
  ))

  pkgdown <- yaml::read_yaml(pkgdown_file)
  reference <- pkgdown[["reference"]]

  if (is.null(reference)) {
    cli::cli_alert_warning(c(
      "{.path _pkgdown.yml} has no {.field reference} section."
    ))
    return(invisible())
  }

  listed <- if (!is.null(reference$contents)) {
    reference$contents
  } else {
    unique(unlist(lapply(reference, `[[`, "contents")))
  }

  missing <- setdiff(exported, listed)

  if (length(missing) == 0L) {
    cli::cli_alert_success(
      "All {length(exported)} exported functions are listed in pkgdown reference."
    )
    return(invisible(character()))
  }

  cli::cli_alert_danger(
    "{length(missing)} exported function{?s} missing from pkgdown reference:"
  )

  for (func in missing) {
    cli::cli_ul("{.fun {func}}")
  }

  invisible(missing)
}
