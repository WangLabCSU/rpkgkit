#' @rdname use_r
#' @param dirs Package-relative directories scanned by `use_r()`. Defaults to
#'   `"R"` and `"tests/testthat"`; missing directories are ignored.
#' @export
use_r <- function(
  path = NULL,
  dirs = c("R", file.path("tests", "testthat")),
  ...
) {
  rlang::check_dots_empty()
  rlang::check_installed("usethis")
  path <- path %||% "."
  if (!is_pkg(path = path)) {
    cli::cli_abort(c(
      "x" = "{.path {path}} is not an R package root.",
      ">" = "No {.file DESCRIPTION} found."
    ))
  }
  path <- normalizePath(path = path, mustWork = TRUE)

  scan <- ur_scan_rs(path, dirs)
  hits <- data.frame(
    feature = scan$feature,
    version = scan$version,
    label = scan$label,
    file = scan$file,
    line = scan$line,
    col = scan$col,
    count = scan$count,
    local = as.logical(scan$local),
    stringsAsFactors = FALSE
  )

  if (nrow(hits) == 0L) {
    n_files <- length(scan$files)
    cli::cli_alert_info(
      "No version-specific base R features found in {n_files} file{?s}."
    )
    cli::cli_alert_info("{.file DESCRIPTION} left unchanged.")
    return(invisible(NULL))
  }

  local_hits <- hits[hits$local, , drop = FALSE]
  if (nrow(local_hits) > 0L) {
    provided <- unique(local_hits$feature)
    cli::cli_alert_info(
      "Ignoring {.code {provided}}: defined by the package itself."
    )
  }

  global_hits <- hits[!hits$local, , drop = FALSE]
  min_version <- scan$min_version
  if (!nzchar(min_version)) {
    cli::cli_alert_info("{.file DESCRIPTION} left unchanged.")
    return(invisible(NULL))
  }

  cli::cli_alert_info(
    "Detected base R features that require R >= {min_version}:"
  )
  features <- unique(global_hits[c("feature", "version", "label")])
  ord <- order(numeric_version(features$version))
  features <- features[ord, , drop = FALSE]
  for (i in seq_len(nrow(features))) {
    feature <- features$feature[[i]]
    rows <- global_hits[global_hits$feature == feature, , drop = FALSE]
    label <- features$label[[i]]
    version <- features$version[[i]]
    uses <- sum(rows$count)
    n_used <- nrow(rows)
    first_file <- rows$file[[1]]
    first_line <- rows$line[[1]]
    cli::cli_li(
      "{.code {feature}} ({label}) requires R >= {version}; {uses} use{?s} in {n_used} file{?s}, first at {.file {first_file}}:{first_line}."
    )
  }

  usethis::proj_set(path = path)
  usethis::use_package(
    package = "R",
    type = "Depends",
    min_version = min_version
  )

  invisible(min_version)
}
