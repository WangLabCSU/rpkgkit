#' Use Hex Sticker in README
#'
#' @description
#' Adds a hex sticker image (optionally wrapped in a hyperlink) at the end of
#' the top-level heading (the line starting with \verb{# }) in \code{README.md}.
#' This is a common pattern for R package README files.
#'
#' @param img_path Character. Path to the image file (e.g.,
#'   \code{"man/figures/logo.png"}).
#' @param url Character. URL the image should link to. If \code{NULL} (default),
#'   no hyperlink is added.
#' @param alt_text Character. Alt text for the image. Defaults to
#'   \code{"package logo"}.
#' @param height Numeric or character. Image height in pixels. Defaults to
#'   \code{139}.
#' @param align Character. Image alignment attribute. Defaults to \code{"right"}.
#' @param path Character. Path to the package root directory. If \code{NULL},
#'   uses the current working directory (with RStudio document detection).
#' @param ... Additional HTML attributes to include in the \verb{<img>} tag as
#'   named arguments.
#'
#' @return Invisibly returns \code{TRUE} on success.
#' @export
#'
#' @examples
#' \dontrun{
#' use_hexsticker("man/figures/logo.png", url = "https://my-pkg-website.com")
#' use_hexsticker("man/figures/logo_white.png", alt_text = "Package logo", height = 139)
#' }
use_hexsticker <- function(
  img_path,
  url = NULL,
  alt_text = "package logo",
  height = 139,
  align = "right",
  path = NULL,
  ...
) {
  # Build <img> tag attributes
  img_attrs <- c(
    src = img_path,
    alt = alt_text,
    align = align,
    height = as.character(height)
  )

  extra_attrs <- list(...)
  if (length(extra_attrs) > 0) {
    extra_named <- stats::setNames(
      vapply(extra_attrs, as.character, character(1)),
      names(extra_attrs)
    )
    img_attrs <- c(img_attrs, extra_named)
  }

  img_attr_str <- paste(
    sprintf('%s="%s"', names(img_attrs), img_attrs),
    collapse = " "
  )
  img_tag <- sprintf("<img %s/>", img_attr_str)

  # Wrap in anchor if url is provided
  html_tag <- if (is.null(url)) {
    img_tag
  } else {
    sprintf('<a href="%s">%s</a>', url, img_tag)
  }

  # Locate README.md
  path <- path %||% get_wd()
  readme_path <- file.path(path, "README.md")

  if (!file.exists(readme_path)) {
    cli::cli_abort(c("x" = "README.md not found at {.path {readme_path}}."))
  }

  lines <- readLines(readme_path, warn = FALSE)

  if (length(lines) == 0L) {
    cli::cli_abort(c("x" = "README.md is empty."))
  }

  # Find the top-level heading (first line starting with "# ")
  heading_idx <- grep("^#\\s", lines)
  if (length(heading_idx) == 0L) {
    cli::cli_abort(c("x" = "No top-level heading found in README.md."))
  }

  add_tag_to_readme <- function(file_path) {
    lines <- readLines(file_path, warn = FALSE)
    if (length(lines) == 0L) return(invisible(FALSE))
    heading_idx <- grep("^#\\s", lines)
    if (length(heading_idx) == 0L) return(invisible(FALSE))
    lines[heading_idx[1L]] <- paste(lines[heading_idx[1L]], html_tag)
    writeLines(lines, file_path)
    invisible(TRUE)
  }

  add_tag_to_readme(readme_path)

  readme_rmd_path <- file.path(path, "README.Rmd")
  if (file.exists(readme_rmd_path)) {
    add_tag_to_readme(readme_rmd_path)
  }

  cli::cli_inform(c(
    "v" = "Added hex sticker reference to {.path {readme_path}}",
    ">" = "Image: {.file {img_path}}"
  ))
  if (file.exists(readme_rmd_path)) {
    cli::cli_inform(c("v" = "Also updated {.path {readme_rmd_path}}"))
  }

  invisible(TRUE)
}
