# ==============================================================================
# The following code is adapted from the 'pedant' package.
# Source: https://github.com/wurli/pedant
# Authors: Jacob Scott, Christopher T. Kenny, Sebastian Lammers
# License: MIT + file LICENSE (See inst/vendor/pedant/LICENSE)
# Last-updated: 2026-06-30
# Vendor version: 0.1.0
# Imports: rstudioapi, pkgload
# ==============================================================================
#
# ## Changelog
#
# 2026-06-25:
# * Added `@return property to meet CRAN policies
#
# nocov start

#' Make function calls explicit
#'
#' This function takes a block of code and seeks to make all function calls
#' 'explicit' through the use of the double-colon operator `::`. This function
#' is bound to the RStudio addin `"Make function calls explicit"`. See examples
#' for usage.
#'
#' This function behaves differently depending on the context.
#' - **Not package development**: If the current
#' context is not package development, then it will make function calls explicit
#' using the currently attached packages (i.e. the ones attached by calls to
#' `library()`).
#' - **Package development**: If it detects that the current context is package
#' development it will make function calls explicit using packages in the
#' 'Imports' field of the package `DESCRIPTION`. If the package being developed
#' imports any packages in their entirety (i.e if `Import pkg` appears in the
#' `NAMESPACE` file), calls to functions from these packages will be left
#' unchanged.
#' See `current_packages()` for more information.
#'
#' @param code Code to transform. Either a character vector or `NULL`, in which
#'   case any highlighted code (in RStudio) will be used.
#' @param use_packages A character vector of package names. The order is
#'   important here - see examples for details.
#' @param ignore_functions Functions to ignore when applying the transformation
#'
#' @return The transformed `code` as a character string
#' @export
#'
#' @examples
#' code <- "
#'   cars <- as_tibble(mtcars)
#'   cars %>%
#'     filter(mpg > 20) %>%
#'     summarise(across(everything(), n_distinct))
#' "
#'
#' # Code will be transformed to use the double-colon operator, but notice
#' # that `n_distinct` is not transformed as it is not followed by `()`
#' cat(add_double_colons(code, "dplyr"))
#'
#' # You can specify functions that shouldn't be transformed:
#' cat(add_double_colons(code, "dplyr", ignore_functions = "across"))
#'
#' # Beware namespace conflicts! The following are not the same, mimicking
#' # the effects of reordering calls to `library()`:
#' cat(add_double_colons(code, c("dplyr", "stats")))
#'
#' cat(add_double_colons(code, c("stats", "dplyr")))
add_double_colons <- function(
  code = NULL,
  use_packages = current_packages(),
  ignore_functions = imported_functions()
) {
  # Error trapping + check if we're replacing highlighted code
  if (is.null(code)) {
    if (!requireNamespace("rstudioapi", quietly = TRUE)) {
      stop("{rstudioapi} must be installed")
    }
    if (!rstudioapi::isAvailable()) {
      stop("RStudio is not available")
    }
    replace_selection <- TRUE
    code <- rstudioapi::selectionGet()$value
  } else {
    replace_selection <- FALSE
  }

  # Need to make this small adjustment to (very badly styled) code since
  # variable-length lookbehinds aren't possible
  code <- gsub(":: +", "::", code)

  # Regular expression to extract function calls
  backticks_fns <- "`[^`]+`(?= *[(])"
  syntactic_fns <- "(?<=[^a-zA-Z._]|^)[a-zA-Z._]+(?= *[(])"
  exclude_dcs <- "(?<!::)"
  funs_regex <- sprintf("%s(%s|%s)", exclude_dcs, backticks_fns, syntactic_fns)

  all_calls <- str_extract_all(code, funs_regex)
  called_funs <- unique(all_calls)

  # Get a lookup list of names = packages, values = namespace exports
  pkg_lookup <- lapply(use_packages, getNamespaceExports)
  names(pkg_lookup) <- use_packages

  # Helper to retrieve the `pkg::fun` text for a function `fun`
  get_pkg <- function(fun) {
    fun1 <- gsub("(^`)|(`$)", "", fun)

    for (pkg in use_packages) {
      if (fun1 %in% pkg_lookup[[pkg]]) {
        if (pkg == "base" || fun1 %in% ignore_functions) {
          return(fun)
        } else {
          return(paste0(pkg, "::", fun))
        }
      }
    }
    NA_character_
  }

  # Get the replacement text for each function call
  called_funs_pkgs <- vapply(called_funs, get_pkg, character(1))
  no_pkg <- is.na(called_funs_pkgs)

  # Warn about any unfound functions
  if (any(no_pkg) > 0) {
    warning(
      sprintf(
        "Couldn't find packages exporting %d function(s): `%s()`",
        sum(no_pkg),
        paste(called_funs[no_pkg], collapse = "()`, `")
      ),
      call. = FALSE
    )

    called_funs_pkgs[no_pkg] <- names(called_funs_pkgs)[no_pkg]
  }

  # Get the full vector of replacements for the regex matches
  replacements <- called_funs_pkgs[
    vapply(
      all_calls,
      function(x) which(names(called_funs_pkgs) == x),
      integer(1)
    )
  ]
  out <- str_replace_all(code, funs_regex, replacements)

  if (replace_selection) {
    rstudioapi::insertText(out)
    return(invisible(out))
  }

  out
}

get_imports <- function(dir = ".") {
  if (!requireNamespace("pkgload", quietly = TRUE)) {
    return(NULL)
  }

  imports <- tryCatch(
    pkgload::parse_ns_file(dir)$imports,
    error = function(e) NULL
  )

  if (is.null(imports)) {
    return(NULL)
  }

  out <- list(
    packages = lapply(imports, function(x) if (length(x) == 1) x else NULL),
    functions = lapply(imports, function(x) x[-1])
  )

  lapply(out, unlist, use.names = FALSE)
}

get_dependencies <- function(
  dir = ".",
  types = c("Imports", "Depends", "Suggests", "Enhances", "LinkingTo")
) {
  if (!requireNamespace("pkgload", quietly = TRUE)) {
    return(NULL)
  }

  types <- match.arg(types, several.ok = TRUE)

  deps <- tryCatch(
    pkgload::pkg_desc(dir)$get_deps(),
    error = function(e) NULL
  )

  if (is.null(deps)) {
    return(NULL)
  }

  deps$package[deps$type %in% types]
}

#' @rdname current_packages
#' @return `TRUE` if the current context is package development, `FALSE` otherwise.
#' @export
is_dev_context <- function(dir = ".") {
  if (!requireNamespace("pkgload", quietly = TRUE)) {
    return(FALSE)
  }
  tryCatch(
    {
      pkgload::pkg_name(dir)
      TRUE
    },
    error = function(e) FALSE
  )
}

imported_packages <- function(dir = ".") {
  get_imports(dir)$packages
}

dev_context_pkgs <- function(dir = ".", types = "Imports") {
  setdiff(get_dependencies(dir, types), imported_packages(dir))
}

loaded_packages <- function() {
  search_path <- search()
  out <- search_path[grepl("^package:", search_path)]
  sub("^package:", "", out)
}

#' @rdname current_packages
#' @return A character vector of imported function names, or `NULL` if no
#'   NAMESPACE file is found or `{pkgload}` is not installed.
#' @export
imported_functions <- function(dir = ".") {
  get_imports(dir)$functions
}

#' Get packages from the current context
#'
#' These functions find the packages/functions to use when running
#' `add_double_colons()`.
#'
#' - `current_packages()` first checks if the current context is package
#' development. If it is, then it returns the packages which are listed in the
#' package `DESCRIPTION` as dependencies, but will not return any packages also
#' listed as imports in the package `NAMESPACE`. If the current context is not
#' package development, the currently attached packages (as given by `search()`)
#' are used. Note that if `{pkgload}` is not installed then the latter option is
#' always used.
#' - `imported_functions()` looks for a package `NAMESPACE` file and returns the
#' names of all imported functions. If a `NAMESPACE` file is not found, or if
#' `{pkgload}` is not loaded, `NULL` is returned.
#'
#' @param dir The current working directory
#' @param base_packages Default packages to include
#' @param include_types The types of package imports to return if the current
#'   context is package development. Should be a subset of
#'   `c("Imports", "Depends", "Suggests", "Enhances", "LinkingTo")`
#'
#' @return A character vector of package names.
#'
#' @export
current_packages <- function(
  dir = ".",
  base_packages = getOption("defaultPackages"),
  include_types = "Imports"
) {
  out <- if (is_dev_context()) {
    dev_context_pkgs(dir, include_types)
  } else {
    loaded_packages()
  }

  unique(c(out, base_packages, "base"))
}

str_extract_all <- function(x, pattern, invert = FALSE) {
  regmatches(x, gregexpr(pattern, x, perl = TRUE), invert)[[1]]
}

str_replace_all <- function(x, pattern, replacement) {
  regex <- gregexpr(pattern, x, perl = TRUE)
  regmatches(x, regex)[[1]] <- replacement
  x
}

# nocov end
