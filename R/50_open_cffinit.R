#' Open the CFF initializer
#'
#' Opens the CFF (Citation File Format) initializer web application in the
#' default browser.
#'
#' @param ... Unused arguments, for future extensibility.
#' @return Invisible `TRUE`, called for side effects.
#' @family open functions
#' @seealso [browseURL()]
#' @export
open_cffinit <- function(...) {
  rlang::check_dots_empty()
  utils::browseURL(
    "https://citation-file-format.github.io/cff-initializer-javascript/#/"
  )
  invisible(TRUE)
}
