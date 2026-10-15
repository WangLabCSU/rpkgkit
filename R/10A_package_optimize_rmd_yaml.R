#' Enrich the YAML headers of README.Rmd and vignettes/*.Rmd of a package
#'
#' Applies [optimize_rmd_yaml()] to `README.Rmd` and every `.Rmd` under
#' `vignettes/`, with a progress bar. See [optimize_rmd_yaml()] for the
#' compatibility rules and the meaning of the shared arguments.
#'
#' @param path Package root directory. `NULL` means the current directory.
#' @param readme Process README.Rmd?
#' @param vignettes Process .Rmd files in vignettes/?
#' @export
#' @inheritParams optimize_rmd_yaml
#' @return The paths of the files that were changed (invisibly).
#' @examples
#' \dontrun{
#' package_optimize_rmd_yaml()
#' package_optimize_rmd_yaml(readme_format = "github_document", date = "desc")
#'
#' package_optimize_rmd_yaml(
#'   extra = list(lang = "zh-CN"),                   # merged with the defaults
#'   extra_readme = list(always_allow_html = NULL),  # drop a README default
#'   extra_vignette = list(
#'     bibliography = "refs.bib",
#'     `link-citations` = TRUE,
#'     params = list(eval = FALSE)
#'   )
#' )
#' }
package_optimize_rmd_yaml <- function(
  path = NULL,
  readme = TRUE,
  vignettes = TRUE,
  readme_format = c("gfm", "github_document", "html"),
  date = c("auto", "desc", "none"),
  extra = NULL,
  extra_readme = NULL,
  extra_vignette = NULL
) {
  path <- path %||% "."
  readme_format <- match_arg(readme_format)
  date <- match_arg(date)
  rlang::check_installed(c("desc", "yaml"))

  pkg <- normalizePath(path, mustWork = TRUE)
  if (!is_pkg(pkg)) {
    cli::cli_abort(c("x" = "No {.file DESCRIPTION} found in {.path {pkg}}"))
  }
  extra_by_type <- .ory_extra_by_type(extra, extra_readme, extra_vignette)
  meta <- .ory_meta(pkg)

  # ---- Collect files -------------------------------------------------------
  files <- character()
  types <- character()
  if (isTRUE(readme)) {
    f <- file.path(pkg, "README.Rmd")
    if (file.exists(f)) {
      files <- c(files, f)
      types <- c(types, "readme")
    }
  }
  if (isTRUE(vignettes)) {
    vdir <- file.path(pkg, "vignettes")
    if (dir.exists(vdir)) {
      vf <- list.files(vdir, pattern = "\\.[Rr]md$", full.names = TRUE)
      vf <- vf[!grepl("^_", basename(vf))]
      files <- c(files, vf)
      types <- c(types, rep("vignette", length(vf)))
    }
  }

  n <- length(files)
  if (n == 0L) {
    cli::cli_alert_warning("No README.Rmd or vignettes/*.Rmd found.")
    return(invisible(character()))
  }

  # ---- Process each file (with progress bar) -------------------------------
  changed <- character()
  cli::cli_progress_bar(
    name = "Optimizing YAML headers",
    total = n,
    format = paste0(
      "{cli::pb_spin} Optimizing YAML headers in package ",
      "{cli::pb_current}/{cli::pb_total} | {cli::pb_percent} | ",
      "{cli::pb_status}"
    )
  )

  for (i in seq_len(n)) {
    f <- files[i]
    cli::cli_progress_update(status = basename(f))
    if (
      .ory_process_file(
        f,
        types[i],
        meta,
        readme_format,
        date,
        extra_by_type[[types[i]]]
      )
    ) {
      changed <- c(changed, f)
    }
  }

  cli::cli_progress_done()

  n_changed <- length(changed)
  cli::cli_alert_success(
    "Processed {n} file{?s}, updated {n_changed}"
  )
  invisible(changed)
}
