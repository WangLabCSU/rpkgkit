is_pkg <- function(path) {
  dir.exists(path) && file.exists(file.path(path, "DESCRIPTION"))
}

get_wd <- function() {
  if (rlang::is_installed("rstudioapi") && interactive()) {
    current_wd <- dirname(rstudioapi::getActiveDocumentContext()$path)
  } else {
    current_wd <- getwd()
  }
  if (is_pkg(dirname(current_wd))) {
    dirname(current_wd)
  } else {
    current_wd
  }
}
