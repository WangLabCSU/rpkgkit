#' Create an RStudio Addin registration entry for a package function
#'
#' `use_tidy_addin()` writes an entry into `inst/rstudio/addins.dcf`, which
#' makes an exported function available from the RStudio Addins menu.
#'
#' @param fn_name Name of the function (it must already be exported in
#'   `NAMESPACE`).
#' @param desc    Description of the addin.
#' @param Interactive Whether this is an interactive addin (maps to the
#'   `Interactive` field of the dcf file).
#' @param path    Root directory of the R package.
#'
#' @return Invisibly, the path of the dcf file that was written (`NULL` if the
#'   operation was cancelled).
#' @export
#' @examples
#' \dontrun{
#' # Inside a package that exports `my_addin()`
#' use_tidy_addin("my_addin", "Open my Shiny gadget", Interactive = TRUE)
#' }
use_tidy_addin <- function(
  fn_name,
  desc,
  Interactive = FALSE,
  path = NULL
) {
  # ---- 0. Argument checks ------------------------------------------------
  rlang::check_string(fn_name, "fn_name")
  rlang::check_string(desc, "desc")
  rlang::check_bool(Interactive, "Interactive")
  rlang::check_installed("desc", "parse DESCRIPTION")
  desc <- gsub("\\s*\n\\s*", " ", desc) # strip newlines

  # ---- 1. Check that path is an R package --------------------------------
  path <- path %||% "."
  path <- normalizePath(path, mustWork = FALSE)
  if (!is_pkg(path)) {
    cli::cli_abort(
      "{.path {path}} is not an R package directory (no DESCRIPTION found)."
    )
  }
  desc_file <- file.path(path, "DESCRIPTION")
  pkg <- unname(desc::desc_get("Package", file = desc_file))

  # ---- 2. Check that fn_name is exported in NAMESPACE --------------------
  ns_file <- file.path(path, "NAMESPACE")
  if (!file.exists(ns_file)) {
    cli::cli_abort(c(
      "Cannot find {.file NAMESPACE}.",
      "i" = "Please run {.code devtools::document()} first."
    ))
  }
  ns <- .uta_parse_namespace(ns_file)
  is_exported <- fn_name %in%
    ns$exports ||
    any(vapply(ns$export_patterns, function(p) grepl(p, fn_name), logical(1)))
  if (!is_exported) {
    cli::cli_abort(c(
      "{.fn {fn_name}} is not exported in NAMESPACE.",
      "i" = "Please add {.code #' @export} and re-run {.code devtools::document()}."
    ))
  }

  # ---- 3. Obtain the function body ---------------------------------------
  body_expr <- NULL
  if (.uta_is_documented(path)) {
    # Already documented: use pkg::fn_name |> rlang::fn_body directly
    body_expr <- tryCatch(
      {
        if (!requireNamespace(pkg, quietly = TRUE)) {
          stop("package not available")
        }
        getExportedValue(pkg, fn_name) |> rlang::fn_body()
      },
      error = function(e) NULL
    )
  }
  if (is.null(body_expr)) {
    # Not documented / package not installed or loaded: scan files under R/
    # for the definition
    body_expr <- .uta_find_fn_body(fn_name, path)
  }
  if (is.null(body_expr)) {
    cli::cli_abort(
      "Cannot find a definition of {.fn {fn_name}} under {.path {file.path(path, 'R')}}."
    )
  }

  # ---- 4. Check for rstudioapi / shiny / miniUI calls --------------------
  if (!.uta_uses_pkg(body_expr, "rstudioapi", ns)) {
    ok <- .uta_confirm(
      "The body of {.fn {fn_name}} does not call any {.pkg rstudioapi} function."
    )
    if (!ok) {
      cli::cli_alert_info("Cancelled, no addin was written.")
      return(invisible(NULL))
    }
  }
  if (Interactive) {
    uses_ui <- .uta_uses_pkg(body_expr, "shiny", ns) ||
      .uta_uses_pkg(body_expr, "miniUI", ns)
    if (!uses_ui) {
      ok <- .uta_confirm(
        "{.arg Interactive} is {.code TRUE}, but the body of {.fn {fn_name}} does not call any {.pkg shiny} or {.pkg miniUI} function."
      )
      if (!ok) {
        cli::cli_alert_info("Cancelled, no addin was written.")
        return(invisible(NULL))
      }
    }
  }

  # ---- 5. Write inst/rstudio/addins.dcf (new entry goes at the top) ------
  dcf_dir <- file.path(path, "inst", "rstudio")
  dcf_file <- file.path(dcf_dir, "addins.dcf")

  # Already registered under the same Binding: do not add it twice
  if (file.exists(dcf_file) && fn_name %in% .uta_read_bindings(dcf_file)) {
    cli::cli_alert_info(
      "{.fn {fn_name}} is already registered in {.path {dcf_file}}, nothing was added."
    )
    return(invisible(dcf_file))
  }

  new_lines <- c(
    paste0("Name: ", fn_name),
    paste0("Description: ", desc),
    paste0("Binding: ", fn_name),
    paste0("Interactive: ", tolower(as.character(Interactive)))
  )

  old_lines <- character()
  if (file.exists(dcf_file)) {
    old_lines <- readLines(dcf_file, encoding = "UTF-8", warn = FALSE)
    # Drop leading blank lines so no extra blank line precedes the new entry
    while (length(old_lines) > 0L && !nzchar(trimws(old_lines[1L]))) {
      old_lines <- old_lines[-1L]
    }
  }

  lines <- if (length(old_lines) > 0L) {
    c(new_lines, "", old_lines) # separate entries with a blank line
  } else {
    new_lines
  }

  dir.create(dcf_dir, recursive = TRUE, showWarnings = FALSE)
  # Write UTF-8 bytes to avoid mojibake in non-UTF-8 locales
  writeLines(enc2utf8(lines), dcf_file, useBytes = TRUE)

  cli::cli_alert_success("Wrote addin {.val {fn_name}}: {.path {dcf_file}}")
  invisible(dcf_file)
}


# ============================ internal helpers ==============================

# Parse NAMESPACE (it is itself parseable R code)
.uta_parse_namespace <- function(ns_file) {
  exprs <- parse(ns_file, keep.source = FALSE, encoding = "UTF-8")
  exports <- character()
  export_patterns <- character()
  imports_all <- character()
  imports_from <- data.frame(pkg = character(), sym = character())

  for (e in exprs) {
    if (!is.call(e) || !is.name(e[[1L]])) {
      next
    }
    fn <- as.character(e[[1L]])
    args <- vapply(
      as.list(e)[-1L],
      function(a) as.character(a)[1L],
      character(1)
    )
    switch(
      fn,
      export = exports <- c(exports, args),
      exportPattern = export_patterns <- c(export_patterns, args),
      import = imports_all <- c(imports_all, args),
      importFrom = if (length(args) >= 2L) {
        imports_from <- rbind(
          imports_from,
          data.frame(pkg = args[1L], sym = args[-1L])
        )
      }
    )
  }
  list(
    exports = exports,
    export_patterns = export_patterns,
    imports_all = imports_all,
    imports_from = imports_from
  )
}

# Whether devtools::document() has been run: NAMESPACE carries a roxygen2
# header and man/ contains at least one Rd file
.uta_is_documented <- function(path) {
  header <- readLines(file.path(path, "NAMESPACE"), n = 1L, warn = FALSE)
  has_header <- length(header) == 1L &&
    grepl("Generated by roxygen2", header, fixed = TRUE)
  has_rd <- length(list.files(file.path(path, "man"), pattern = "\\.Rd$")) > 0L
  has_header && has_rd
}

# Walk every file under R/, find the assignment that defines fn_name and
# return its function body
.uta_find_fn_body <- function(fn_name, path) {
  files <- list.files(
    file.path(path, "R"),
    pattern = "\\.[Rr]$",
    full.names = TRUE
  )
  for (f in files) {
    exprs <- tryCatch(
      parse(f, keep.source = FALSE, encoding = "UTF-8"),
      error = function(e) NULL
    )
    if (is.null(exprs)) {
      next
    }
    for (e in exprs) {
      if (
        is.call(e) &&
          length(e) == 3L &&
          is.name(e[[1L]]) &&
          as.character(e[[1L]]) %in% c("<-", "=", "<<-")
      ) {
        lhs <- e[[2L]]
        if (
          (is.name(lhs) || is.character(lhs)) &&
            identical(as.character(lhs), fn_name)
        ) {
          rhs <- e[[3L]]
          if (is.call(rhs) && identical(rhs[[1L]], as.name("function"))) {
            return(rhs[[3L]]) # function(args) body
          }
          return(rhs)
        }
      }
    }
  }
  NULL
}

# Whether the body uses a package: pkg::, library()/requireNamespace(), or a
# symbol imported through NAMESPACE
.uta_uses_pkg <- function(body, pkg, ns) {
  txt <- paste(deparse(body), collapse = "\n")

  if (grepl(sprintf("\\b%s:::?", pkg), txt)) {
    return(TRUE)
  }
  if (
    grepl(
      sprintf(
        "\\b(library|require|requireNamespace|loadNamespace)\\(\\s*[\"']?%s\\b",
        pkg
      ),
      txt
    )
  ) {
    return(TRUE)
  }

  imported <- ns$imports_from$sym[ns$imports_from$pkg == pkg]
  if (pkg %in% ns$imports_all && requireNamespace(pkg, quietly = TRUE)) {
    imported <- union(imported, getNamespaceExports(pkg))
  }
  any(all.names(body) %in% imported)
}

# Warn and ask whether to continue; a non-interactive session cannot ask, so
# only warn and continue
.uta_confirm <- function(msg, .envir = parent.frame()) {
  cli::cli_alert_warning(msg, .envir = .envir)
  if (!rlang::is_interactive()) {
    cli::cli_alert_info(
      "Non-interactive session, cannot ask for confirmation; continuing."
    )
    return(TRUE)
  }
  isTRUE(utils::askYesNo("Add this addin anyway?", default = FALSE))
}

# Read the Bindings already registered in addins.dcf
.uta_read_bindings <- function(dcf_file) {
  con <- file(dcf_file, encoding = "UTF-8")
  mat <- tryCatch(read.dcf(con, fields = "Binding"), error = function(e) NULL)
  if (is.null(mat)) {
    return(character())
  }
  as.character(stats::na.omit(mat[, "Binding"]))
}
