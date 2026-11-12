#' Make Function Calls Explicit
#'
#' @description
#' Add double colons (`::`) to function calls from specified packages to make
#' package dependencies explicit in R code.
#'
#' @param path A character string specifying the path to the R file to modify.
#'   If `NULL` and RStudio is available, the currently active document path is used.
#' @param use_packages A character vector of package names to process. Defaults to
#'   `current_packages()`.
#' @param ignore_functions A character vector of function names to ignore.
#'   Defaults to `c(imported_functions(), get_defined_fn(path))`: the functions
#'   imported into `NAMESPACE` plus those defined in the target package, or in
#'   the target file when `path` is not a package root. Pass `character()` to
#'   ignore nothing.
#' @param ... Additional arguments. Currently unused and must be empty.
#'
#' @return
#' Invisibly `TRUE` when the file was read successfully; the file is modified in
#' place as a side effect.
#'
#' @details
#' This function reads the specified R file, identifies function calls from the
#' specified packages, and adds explicit namespace qualifiers (`::`) to those
#' calls. Exported datasets from the same packages are qualified as well (e.g.
#' `penguins` becomes `palmerpenguins::penguins`). The modified code is written
#' back to the original file.
#'
#' The file is tokenized in Rust, following R's lexical rules for strings, raw
#' strings, comments and backtick names. A name is qualified only when it is
#' actually a call or a dataset, so `pkg::fun`, `obj$fun`, `obj@fun`, function
#' definitions (`fun <- function(...)`), formal arguments and the identifiers
#' passed to `data()` are left untouched. In particular, `l$select + 1` is not
#' rewritten even when `dplyr::select` is in `use_packages`.
#'
#' This function replaces the `add_double_colons()` engine adapted from the
#' \href{https://github.com/wurli/pedant}{pedant} package by Jacob Scott et al.,
#' licensed under MIT.
#'
#' @examples
#' \donttest{
#' file <- tempfile(fileext = ".R")
#' writeLines("
#' starwars |>
#'  mutate(name, bmi = mass / ((height / 100)^2)) |>
#'  select(name:mass, bmi)
#' ", file)
#' make_func_call_explicit(
#'   path = file,
#'   use_packages = c("dplyr"),
#'   ignore_functions = c("library", "require")
#' )
#' readLines(file) |> message()
#' }
#'
#' @export
make_func_call_explicit <- function(
  path = NULL,
  use_packages = current_packages(),
  ignore_functions = c(
    imported_functions(),
    get_defined_fn(path)
  ),
  ...
) {
  rlang::check_dots_empty()
  rlang::check_installed("pkgload")

  path <- path %||%
    if (rstudioapi::isAvailable()) rstudioapi::getActiveDocumentContext()$path
  if (is.null(path) || !nzchar(path)) {
    cli::cli_abort(c("x" = "{.arg path} is required"))
  }
  if (!file.exists(path)) {
    cli::cli_abort(c("x" = "{.file {path}} does not exist"))
  }

  context <- mfce_package_context(
    use_packages = use_packages,
    ignore_functions = ignore_functions
  )
  result <- mfce_process_file(path, context)

  mfce_warn_not_found(result$not_found)
  if (result$changed) {
    cli::cli_alert_success(
      "Successfully made function call explicit in {.file {path}}"
    )
  }
  invisible(TRUE)
}

#' Rewrite one file and write it back only when it changed
#'
#' @param path Path to the R file.
#' @param context Package lookups built by `mfce_package_context()`.
#'
#' @return A list with `changed` (logical) and `not_found` (character).
#'
#' @keywords internal
mfce_process_file <- function(path, context) {
  code <- mfce_read_text(path)
  result <- mfce_rewrite(code, context)
  if (result$changed) {
    cat(result$text, file = path, sep = "")
  }
  list(changed = result$changed, not_found = result$not_found)
}

#' Read a file as one string, keeping its final-newline state
#'
#' @keywords internal
mfce_read_text <- function(path) {
  lines <- readLines(path, warn = FALSE)
  if (length(lines) == 0L) {
    return("")
  }
  code <- paste(lines, collapse = "\n")
  if (mfce_has_final_newline(path)) paste0(code, "\n") else code
}

#' `TRUE` when the last byte of `path` is a newline
#'
#' `readLines()` drops that information, but the rewrite must neither add nor
#' remove the final newline of the file it touches.
#'
#' @keywords internal
mfce_has_final_newline <- function(path) {
  con <- file(path, open = "rb")
  on.exit(close(con), add = TRUE)
  tryCatch(
    {
      seek(con, where = -1L, origin = "end")
      identical(readBin(con, what = "raw", n = 1L), as.raw(0x0aL))
    },
    error = function(e) FALSE
  )
}


#' Names of the functions defined by the code being rewritten -----------------
#'
#' Only `path` itself is inspected: no walk through parent directories.
#' - a package root -> every function defined under its R/ directory
#' - anything else  -> the functions defined in that one file
#' Plain values are not functions and are left out. The result is always a
#' character vector, never NULL, so it can be combined with
#' `imported_functions()` (which may return NULL).
#'
#' @param path Path to the R file.
#'
#' @return A character vector of function names.
#' @examples
#' \dontrun{
#' get_defined_fn(".")
#' }
#' @keywords internal
get_defined_fn <- function(path = NULL) {
  path <- path %||% "."

  files <- if (dir.exists(path)) {
    if (!is_pkg(path = path)) {
      character()
    } else {
      r_dir <- file.path(path, "R")
      if (dir.exists(r_dir)) {
        list.files(r_dir, pattern = "\\.[rR]$", full.names = TRUE)
      } else {
        character()
      }
    }
  } else if (file.exists(path)) {
    path
  } else {
    character()
  }

  if (length(files) == 0L) {
    return(character())
  }

  defined_fn <- function(expr) {
    if (!is.call(expr) || !is.name(expr[[1L]])) {
      return(character())
    }
    op <- as.character(expr[[1L]])
    if (!op %in% c("<-", "=", "<<-", "assign")) {
      return(character())
    }
    target <- expr[[2L]]
    value <- expr[[3L]]
    if (
      !is.call(value) ||
        !is.name(value[[1L]]) ||
        !identical(as.character(value[[1L]]), "function")
    ) {
      return(character())
    }
    if (is.name(target)) {
      return(as.character(target))
    }
    if (is.character(target) && length(target) == 1L && !is.na(target)) {
      return(target)
    }
    character()
  }

  out <- unlist(
    lapply(files, function(f) {
      exprs <- tryCatch(parse(f, keep.source = FALSE), error = function(e) NULL)
      if (is.null(exprs)) {
        return(character())
      }
      unlist(lapply(as.list(exprs), defined_fn), use.names = FALSE)
    }),
    use.names = FALSE
  )
  unique(out %||% character())
}


#' Build the package lookups used to qualify names
#'
#' Resolves each package in `use_packages` once, so a whole package can be
#' processed without re-reading namespace exports for every file.
#'
#' @keywords internal
mfce_package_context <- function(
  use_packages = current_packages(),
  ignore_functions = c(imported_functions(), get_defined_fn())
) {
  use_packages <- unique(as.character(use_packages))
  fun_exports <- lapply(use_packages, base::getNamespaceExports)
  data_exports <- lapply(use_packages, function(pkg) {
    res <- as.data.frame(
      utils::data(package = pkg)$results,
      stringsAsFactors = FALSE
    )
    if (nrow(res) <= 0L) {
      return(character(0L))
    }
    items <- res[["Item"]]
    # e.g. "foo (bar)" -> "foo"
    sub("\\s.*$", "", items)
  })

  list(
    use_packages = use_packages,
    ignore_functions = as.character(ignore_functions %||% character()),
    fun_exports = unlist(fun_exports, use.names = FALSE),
    fun_packages = rep(use_packages, lengths(fun_exports)),
    data_exports = unlist(data_exports, use.names = FALSE),
    data_packages = rep(use_packages, lengths(data_exports))
  )
}

mfce_rewrite <- function(code, context) {
  mfce_make_calls_explicit_rs(
    text = code,
    use_packages = context$use_packages,
    ignore_functions = context$ignore_functions,
    fun_exports = context$fun_exports,
    fun_packages = context$fun_packages,
    data_exports = context$data_exports,
    data_packages = context$data_packages,
    base_pkg = "base"
  )
}

mfce_warn_not_found <- function(not_found) {
  if (length(not_found) == 0L) {
    return(invisible(NULL))
  }
  cli::cli_warn(
    "Couldn't find packages exporting {length(not_found)} function{?s}: {.fun {not_found}}"
  )
  invisible(NULL)
}
