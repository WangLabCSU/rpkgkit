#' Render an R Markdown or R document to Markdown format
#'
#' @param path Path to the input file. If NULL and rstudioapi is available,
#'   uses the currently active document in RStudio.
#' @param output_format Output format to render to. Defaults to "md_document".
#' @param ... Additional arguments passed to rmarkdown::render.
#'
#' @return The output file path from rmarkdown::render.
#'
#' @examples
#' \dontrun{
#' rlang::is_installed("rmarkdown")
#' tmp <- tempfile(fileext = ".Rmd")
#' writeLines(c("---", "title: Test", "---", "", "Hello, world!"), tmp)
#' render_rmd(tmp)
#' }
#' @export
render_rmd <- function(path = NULL, output_format = "md_document", ...) {
  rlang::check_installed("rmarkdown")
  path <- if (is.null(path) && rlang::is_installed("rstudioapi")) {
    rstudioapi::getActiveDocumentContext()$path
  }
  if (is.null(path)) {
    cli::cli_abort(("c" = "{.arg path} is required"))
  }
  rmarkdown::render(input = path, output_format = output_format, ...)
}
