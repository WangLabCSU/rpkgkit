#' Convert Knitr Chunk Headers in R Markdown Files
#'
#' @description
#' Converts legacy knitr chunk headers in R Markdown (`.Rmd`) files to the
#' current header syntax using `knitr::convert_chunk_header()`.
#'
#' When `path` points to an R package root (a directory containing a
#' `DESCRIPTION` file), the conversion is applied to all `.Rmd` files found
#' under the package `vignettes/` directory (including subdirectories) and to
#' the package `README.Rmd` file when present.
#'
#' When `path` points to a single file, that file is converted and written
#' back in place.
#'
#' @param path Path to an R package root directory or an R Markdown file.
#'   If `NULL` (the default), the current working directory is used.
#' @param ... Additional arguments passed to `knitr::convert_chunk_header()`.
#'
#' @return Invisibly returns a character vector of file paths that were
#'   converted.
#'
#' @examplesIf rlang::is_installed("knitr")
#' tmp <- tempfile(fileext = ".Rmd")
#' writeLines(c("```{r, echo=TRUE, fig.width=10}", "x <- 1", "```"), tmp)
#' convert_knitr_chunk_header(tmp)
#' readLines(tmp)
#'
#' @export
convert_knitr_chunk_header <- function(path = NULL, ...) {
  rlang::check_installed("knitr")

  path <- path %||% "."

  if (is_pkg(path)) {
    files <- pkg_rmd_files(path)
    if (length(files) == 0L) {
      cli::cli_alert_info(
        "No {.code .Rmd} files found in package {.path {path}}."
      )
      return(invisible(character()))
    }
  } else {
    if (!file.exists(path)) {
      cli::cli_abort(c(
        "x" = "File {.path {path}} does not exist."
      ))
    }
    if (dir.exists(path)) {
      cli::cli_abort(c(
        "x" = "{.path {path}} is a directory, not an R Markdown file.",
        ">" = "If it is an R package root, add a {.file DESCRIPTION} file."
      ))
    }
    files <- path
  }

  for (file in files) {
    cli::cli_alert_info(
      "Converting knitr chunk headers in {.path {file}}"
    )
    converted <- knitr::convert_chunk_header(input = file, ...)
    if (!is.null(converted)) {
      writeLines(converted, con = file)
    }
  }

  invisible(files)
}

pkg_rmd_files <- function(path) {
  vignette_dir <- file.path(path, "vignettes")
  vignette_files <- if (dir.exists(vignette_dir)) {
    list.files(
      path = vignette_dir,
      pattern = "\\.Rmd$",
      full.names = TRUE,
      recursive = TRUE,
      ignore.case = TRUE
    )
  } else {
    character()
  }

  readme_file <- file.path(path, "README.Rmd")
  if (!file.exists(readme_file)) {
    readme_file <- character()
  }

  unique(c(vignette_files, readme_file))
}
