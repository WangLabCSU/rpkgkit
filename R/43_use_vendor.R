#' Use a Vendor Package
#'
#' Reference a permissively-licensed R package from GitHub for inclusion in
#' your own R package. This function:
#' - Creates `inst/vendor/pkg/` with LICENSE files and a README
#' - Creates `R/vendor-pkg.R` with attribution header and optional vendored code
#' - Updates `DESCRIPTION` (`Authors@R` and `Copyright` fields)
#' - Prints an acknowledgement snippet for your README
#'
#' @param pkg GitHub repository specification in `"owner/repo"` form or a full
#'   GitHub URL (e.g. `"https://github.com/owner/repo"`).
#' @param ... File paths within the vendor package to copy into your package
#'   and append to the vendor R file. If empty (default), only the
#'   infrastructure is set up.
#' @param branch Github repository branch name.  Defaults to `"main"`
#' @param path Path to the target package directory. If \code{NULL}
#'   (the default), uses the current working directory.
#'
#' @return Invisibly returns `NULL`, called for side effects.
#' @export
#'
#' @examples
#' \dontrun{
#' use_vendor("wurli/pedant")
#' use_vendor("https://github.com/wurli/pedant", "R/add_double_colons.R")
#' }
use_vendor <- function(
  pkg,
  ...,
  branch = "main",
  path = NULL
) {
  rlang::check_installed(c("httr2", "desc"))
  path <- path %||% "."

  path <- normalizePath(path, mustWork = FALSE)

  # -- Check path is an R package --
  if (!is_pkg(path)) {
    cli::cli_abort(c("x" = "{.path {path}} is not an R package."))
  }

  # -- Parse owner/repo from pkg --
  spec <- repo_spec_parse(pkg = pkg, branch = branch)

  # -- Get vendor DESCRIPTION (local or GitHub) and check license --
  cli::cli_alert_info(
    "Fetching repository information for {.emph {spec$owner}/{spec$repo}}..."
  )
  desc_info <- httr2::request(spec$desc_url) |>
    httr2::req_perform() |>
    httr2::resp_body_string()

  desc_vendor <- desc::description$new(text = desc_info)

  license_spdx <- vendor_desc_license(desc = desc_vendor)
  author_info <- vendor_desc_authors(desc = desc_vendor)

  # -- Create inst/vendor/pkg/ with LICENSE files and README --
  vendor_declare_source_license(
    path = path,
    owner = spec$owner,
    repo = spec$repo,
    branch = branch,
    repo_url = spec$repo_url
  )

  # -- Create R/vendor-pkg.R --
  vendor_create_r_file(
    path = path,
    repo = spec$repo,
    repo_url = spec$repo_url,
    author_str = author_info$author_str,
    license = license_spdx,
    owner = spec$owner,
    branch = branch,
    dots = rlang::list2(...),
    desc_vendor = desc_vendor
  )

  # -- Update DESCRIPTION --
  vendor_update_desc(
    path = path,
    author_info = author_info,
    repo = spec$repo,
    repo_url = spec$repo_url
  )

  # -- Step 6: Print acknowledgement snippet --
  cli_inform_colored <- add_colors_to_cli(cli::cli_inform)
  cli_inform_colored(
    "{.red {(cli::symbol$checkbox_off)}} \
    {.cyan Consider pasting the following statement into README.md}"
  )
  message("")
  message(sprintf(
    paste0(
      "## Acknowledgements\n\n",
      "We would like to thank the following people and projects:\n\n",
      "- The authors of the [%s](%s) package &mdash; **%s** &mdash; ",
      "whose code is included (under %s license) in `R/vendor-%s.R`.\n"
    ),
    spec$repo,
    spec$repo_url,
    author_info$author_str,
    license_spdx,
    spec$repo
  ))

  invisible(NULL)
}


#' Helper: parse a GitHub repo spec from user input
#' @keywords internal
repo_spec_parse <- function(pkg, branch = "main") {
  spec <- sub("^https?://github\\.com/", "", pkg)
  spec <- sub("\\.git$", "", spec)

  if (!grepl("/", spec)) {
    cli::cli_abort(
      "{.pkg {pkg}} must be in {.emph owner/repo} form or a GitHub URL."
    )
  }

  parts <- strsplit(spec, "/")[[1L]]
  list(
    owner = parts[1L],
    repo = parts[2L],
    repo_url = sprintf(
      "https://github.com/%s/%s",
      parts[1L],
      parts[2L]
    ),
    desc_url = sprintf(
      "https://raw.githubusercontent.com/%s/%s/%s/DESCRIPTION",
      parts[1L],
      parts[2L],
      branch
    )
  )
}


#' Helper: read license SPDX from the vendor's DESCRIPTION License field
#' @keywords internal
vendor_desc_license <- function(desc) {
  # Extract the primary SPDX identifier (first token before "|" or "+")
  spdx <- trimws(strsplit(desc$get_field("License"), "[|+]")[[1L]][1L])

  permissive <- c(
    "MIT",
    "Apache-2.0",
    "Apache 2.0",
    "BSD-2-Clause",
    "BSD-3-Clause",
    "Unlicense",
    "CC0-1.0",
    "CC0"
  )

  if (!(spdx %in% permissive)) {
    cli::cli_abort(c(
      "x" = "Vendor package uses {spdx} license.",
      ">" = "Only {.val {permissive}} can be vendored."
    ))
  }

  cli::cli_alert_success("Vendor package uses {spdx} license.")
  spdx
}


#' Helper: extract author info from vendor DESCRIPTION
#' @keywords internal
vendor_desc_authors <- function(desc) {
  author_field <- desc$get_authors()

  author_names <- vapply(
    X = author_field,
    FUN = function(p) {
      x <- trimws(paste(p$given %||% "", p$family %||% ""))
      if (nzchar(x)) x else ""
    },
    FUN.VALUE = character(1L)
  )

  author_str <- if (length(author_names) == 1L) {
    author_names
  } else {
    paste(
      toString(author_names[-length(author_names)]),
      "and",
      author_names[length(author_names)]
    )
  }

  list(
    author_field = author_field,
    author_names = author_names,
    author_str = author_str
  )
}


#' Helper: set up inst/vendor/pkg/ with LICENSE files and README
#' @keywords internal
vendor_declare_source_license <- function(
  path = NULL,
  owner = character(1L),
  repo = character(1L),
  branch = character(1L),
  repo_url = character(1L)
) {
  path <- path %||% "."
  vendor_dir <- file.path(path, "inst", "vendor", repo)
  dir.create(vendor_dir, recursive = TRUE, showWarnings = FALSE)
  cli::cli_alert_success("Created directory {.file {vendor_dir}}.")

  # Download LICENSE / LICENSE.md / LICENSE.txt via raw.githubusercontent.com
  license_names <- c("LICENSE", "LICENSE.md", "LICENSE.txt")
  found_any <- FALSE

  for (name in license_names) {
    raw_url <- sprintf(
      "https://raw.githubusercontent.com/%s/%s/%s/%s",
      owner,
      repo,
      branch,
      name
    )

    resp <- tryCatch(
      httr2::request(raw_url) |>
        httr2::req_error(is_error = function(resp) FALSE) |>
        httr2::req_perform(),
      error = function(e) NULL
    )

    if (!is.null(resp) && httr2::resp_status(resp) == 200L) {
      content <- httr2::resp_body_string(resp)
      writeLines(content, file.path(vendor_dir, name))
      cli::cli_alert_success("Copied {.file {name}}.")
      found_any <- TRUE
    }
  }

  if (!found_any) {
    cli::cli_warn("No LICENSE files found in the {.emph {owner}/{repo}} root.")
  }

  # Create README.md
  writeLines(
    sprintf(
      "This directory contains license from the %s package (%s)",
      repo,
      repo_url
    ),
    file.path(vendor_dir, "README.md")
  )
  cli::cli_alert_success("Created {.path inst/vendor/{repo}/README.md}.")
  invisible(TRUE)
}


# Helper: create R/vendor-pkg.R
#' @keywords internal
vendor_create_r_file <- function(
  path = NULL,
  repo = character(1L),
  repo_url = character(1L),
  author_str = character(1L),
  license = character(1L),
  owner = character(1L),
  branch = character(1L),
  dots = list(),
  desc_vendor = NULL
) {
  path <- path %||% "."
  r_path <- file.path(path, "R", sprintf("vendor-%s.R", repo))

  files_to_copy <- lapply(X = dots, FUN = function(file) {
    ext <- if (!endsWith(file, ".R")) {
      paste0(file, ".R")
    } else {
      file
    }
  }) |>
    unlist()

  # -- Download all files first (needed for Imports analysis) --
  downloaded_contents <- list()
  if (length(files_to_copy) > 0) {
    cli::cli_progress_bar(
      "Downloading src",
      type = "download",
      total = length(files_to_copy)
    )
    for (f in files_to_copy) {
      content <- vendor_download_file(
        owner = owner,
        repo = repo,
        branch = branch,
        path = file.path("R", f)
      )
      downloaded_contents[[f]] <- content
      cli::cli_progress_update()
    }
    cli::cli_progress_done()
  }

  # -- Extract metadata --
  vendor_version <- if (!is.null(desc_vendor)) {
    tryCatch(
      desc_vendor$get_field("Version"),
      error = function(e) "unknown"
    )
  } else {
    "unknown"
  }

  all_content <- unlist(downloaded_contents, use.names = FALSE)
  imports <- .vendor_extract_imports(all_content)
  imports_str <- if (length(imports) > 0) {
    toString(imports)
  } else {
    "none"
  }

  # -- Build header --
  r_lines <- c(
    "# ==============================================================================",
    sprintf("# The following code is adapted from the '%s' package.", repo),
    sprintf("# Source: %s", repo_url),
    sprintf("# Authors: %s", author_str),
    sprintf(
      "# License: %s + file LICENSE (See inst/vendor/%s/LICENSE)",
      license,
      repo
    ),
    sprintf(
      "# Generated by: rpkgkit::use_vendor(\"%s/%s\"%s)",
      owner,
      repo,
      if (!is.null(files_to_copy)) {
        toString(paste0(", \"", files_to_copy, "\""))
      } else {
        ""
      }
    ),
    sprintf("# Last-updated: %s", Sys.Date()),
    sprintf("# Vendor version: %s", vendor_version),
    sprintf("# Imports: %s", imports_str),
    "# ==============================================================================",
    "#",
    "# nocov start"
  )

  # -- Append file contents --
  for (f in names(downloaded_contents)) {
    r_lines <- c(
      r_lines,
      "",
      "# ------------------------------------------------------------------------------",
      sprintf("# File: %s", f),
      "# ------------------------------------------------------------------------------",
      "",
      downloaded_contents[[f]]
    )
  }

  r_lines <- c(r_lines, "", "# nocov end")
  writeLines(r_lines, r_path)
  cli::cli_alert_success("Created {.file {r_path}}.")
  invisible(TRUE)
}


#' Helper: extract package names from vendored code for the Imports header field
#'
#' Scans file content for:
#' - Roxygen \verb{@import pkg} and \verb{@importFrom pkg ...} tags
#' - \verb{pkg::function()} calls in non-roxygen lines
#' @param content_lines Character vector of file lines.
#' @return Sorted, unique character vector of package names.
#' @keywords internal
.vendor_extract_imports <- function(content_lines) {
  if (length(content_lines) == 0L) {
    return(character(0L))
  }

  # 1) Roxygen @import pkgname  (may have multiple packages on one line)
  import_lines <- grep("^#'\\s+@import\\s+", content_lines, value = TRUE)
  import_pkgs <- character(0L)
  if (length(import_lines) > 0L) {
    raw <- gsub("^#'\\s+@import\\s+", "", import_lines)
    import_pkgs <- unique(trimws(unlist(strsplit(raw, "\\s+"))))
  }

  # 2) Roxygen @importFrom pkgname function
  ifrom_lines <- grep("^#'\\s+@importFrom\\s+", content_lines, value = TRUE)
  ifrom_pkgs <- character(0L)
  if (length(ifrom_lines) > 0L) {
    ifrom_pkgs <- unique(gsub(
      "^#'\\s+@importFrom\\s+(\\S+).*",
      "\\1",
      ifrom_lines
    ))
  }

  # 3) pkg::function() calls (skip roxygen comment lines)
  code_lines <- grep("^#'", content_lines, value = TRUE, invert = TRUE)
  all_pkg_calls <- unlist(regmatches(
    code_lines,
    gregexpr("[a-zA-Z][a-zA-Z0-9.]*::", code_lines)
  ))
  call_pkgs <- unique(gsub("::$", "", all_pkg_calls))

  # Combine and filter common R namespace values that are not packages
  exclude <- c("base")
  all_pkgs <- unique(c(import_pkgs, ifrom_pkgs, call_pkgs))
  all_pkgs <- setdiff(all_pkgs, exclude)
  sort(all_pkgs)
}


#' Helper: update DESCRIPTION with vendor authors and copyright
#' @keywords internal
vendor_update_desc <- function(
  path = NULL,
  author_info = character(1L),
  repo = character(1L),
  repo_url = character(1L)
) {
  path <- path %||% "."
  desc <- desc::desc(file = file.path(path, "DESCRIPTION"))

  # -- Update Authors@R --
  existing_authors <- desc$get_authors()

  already_present <- any(vapply(
    X = existing_authors,
    FUN = function(p) {
      grepl(pattern = repo_url, x = p$comment %||% "", fixed = TRUE)
    },
    FUN.VALUE = logical(1L)
  ))

  if (already_present) {
    cli::cli_alert_info(
      "Authors for {repo} already present in Authors@R, skipping."
    )
  } else {
    for (p in author_info$author_field) {
      p_roles <- p$role %||% character(0L)
      if (length(p_roles) == 0L) {
        p_roles <- "aut"
      }

      if ("cre" %in% p_roles || "aut" %in% p_roles) {
        new_role <- c("aut", "cph")
        new_comment <- sprintf(
          "Author of the included %s code (%s)",
          repo,
          repo_url
        )
      } else {
        new_role <- c("ctb", "cph")
        new_comment <- sprintf(
          "Contributor to the included %s code (%s)",
          repo,
          repo_url
        )
      }

      desc$add_author(
        given = p$given %||% "",
        family = p$family %||% "",
        email = p$email %||% NULL,
        role = new_role,
        comment = new_comment
      )
    }
    cli::cli_alert_success("Added {.pkg {repo}} authors to {.field Authors@R}.")
  }

  # -- Update Copyright field --
  copyright_val <- sprintf(
    "%s (for the %s code included in R/vendor-%s.R)",
    author_info$author_str,
    repo,
    repo
  )

  if (desc$has_fields("Copyright")) {
    existing <- desc$get("Copyright")
    desc$set("Copyright", paste0(existing[1L], "; ", copyright_val))
  } else {
    desc$set("Copyright", copyright_val)
  }

  desc$write()
  cli::cli_alert_success("Updated DESCRIPTION.")
  invisible(TRUE)
}


# Helper: download a text file from a GitHub repository via the Contents API
#' @keywords internal
vendor_download_file <- function(
  owner = character(1L),
  repo = character(1L),
  branch = character(1L),
  path = character(1L)
) {
  raw_url <- sprintf(
    "https://raw.githubusercontent.com/%s/%s/%s/%s",
    owner,
    repo,
    branch,
    path
  )

  raw <- tryCatch(
    httr2::request(raw_url) |>
      httr2::req_perform() |>
      httr2::resp_body_string(),
    error = function(e) {
      cli::cli_warn("{.emph {owner}/{repo}/{path}} {e$message}")
      NULL
    }
  )

  strsplit(raw, "\n", fixed = TRUE)[[1L]]
}
