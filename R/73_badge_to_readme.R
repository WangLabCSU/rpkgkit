#' Insert a badge into README badges block
#'
#' @description
#' Adds a markdown badge (typically from \pkg{badger}) to the
#' `<!-- badges: start -->` ... `<!-- badges: end -->` block in
#' `README.Rmd` or `README.md`.
#'
#' If both files exist, only `README.Rmd` is updated.
#'
#' @param badge Character. Badge markdown, e.g. the output of
#'   `badger::badge_code_size()`.
#' @param path Character. Path to the package root. If \code{NULL}
#'   (the default), uses the current working directory.
#' @param ... Not used.
#'
#' @return Invisibly returns the path to the modified README file.
#' @export
#'
#' @examples
#' \donttest{
#' tmpdir <- tempdir()
#' usethis::create_package(path = tmpdir, open = FALSE)
#' badger::badge_last_commit(alt = "last-commit") |> badge_to_readme()
#' }
badge_to_readme <- function(badge, path = NULL, ...) {
  rlang::check_dots_empty()
  path <- path %||% "."

  if (!is_pkg(path = path)) {
    cli::cli_abort(c(
      x = "{.path {path}} is not an R package root.",
      `>` = "No {.file DESCRIPTION} found."
    ))
  }

  badge <- as.character(badge)
  if (length(badge) != 1L || !nzchar(trimws(badge))) {
    cli::cli_abort("{.arg badge} must be a non-empty string.")
  }
  badge <- trimws(badge)

  rmd <- file.path(path, "README.Rmd")
  md <- file.path(path, "README.md")
  readme_path <- if (file.exists(rmd)) {
    rmd
  } else if (file.exists(md)) {
    md
  } else {
    cli::cli_abort(c(
      x = "No README found in {.path {path}}.",
      `>` = "Expected {.file README.Rmd} or {.file README.md}."
    ))
  }

  lines <- readLines(con = readme_path, warn = FALSE, encoding = "UTF-8")
  start <- which(trimws(lines) == "<!-- badges: start -->")
  end <- which(trimws(lines) == "<!-- badges: end -->")

  if (length(start) != 1L || length(end) != 1L || end <= start) {
    cli::cli_abort(c(
      x = "Could not find a unique badges block in {.file {readme_path}}.",
      i = "Need one {.code <!-- badges: start -->} and one {.code <!-- badges: end -->}."
    ))
  }

  block <- lines[seq.int(start, end)]
  already <- any(grepl(pattern = badge, x = block, fixed = TRUE))
  if (already) {
    cli::cli_inform(c(i = "Badge already present in {.file {readme_path}}."))
    return(invisible(readme_path))
  }

  insert_at <- end
  new_lines <- c(
    lines[seq_len(insert_at - 1L)],
    badge,
    lines[seq.int(insert_at, length(lines))]
  )
  writeLines(text = new_lines, con = readme_path, useBytes = FALSE)
  cli::cli_inform(c(v = "Added badge to {.file {readme_path}}."))
  invisible(readme_path)
}
