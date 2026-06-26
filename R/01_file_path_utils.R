# nocov start

is_pkg <- function(path) {
  dir.exists(path) && file.exists(file.path(path, "DESCRIPTION"))
}

get_wd <- function() {
  current_wd <- NULL
  if (rlang::is_installed("rstudioapi") && interactive()) {
    current_wd <- dirname(rstudioapi::getActiveDocumentContext()$path)
  }
  if (is.null(current_wd)) {
    current_wd <- "."
  }
  if (is_pkg(dirname(current_wd))) {
    return(dirname(current_wd))
  }
  current_wd
}

# nocov end
