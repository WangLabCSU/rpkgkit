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

get_package_name <- function(path = NULL) {
  path <- path %||% "."
  if (!is_pkg(path)) {
    stop("The path is not a package")
  }

  desc <- read.dcf(file.path(path, "DESCRIPTION"))
  desc[, "Package"][[1L]]
}

# nocov end
