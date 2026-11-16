#' Rename Function Definitions in an R File
#'
#' @description
#' Renames function definitions in an R file to follow a consistent naming
#' convention. Supports `"snake_case"`, `"camelCase"`, `"PascalCase"`, and
#' `"google"` (dot-separated) naming styles. All references to the renamed
#' functions within the file are also updated.
#'
#' @param path A character string specifying the path to the R file to modify.
#'   If `NULL` and RStudio is available, the currently active document path is used.
#' @param style Naming convention to apply. One of:
#'   - `"snake_case"`: all lowercase with underscores (e.g., `my_function`)
#'   - `"camelCase"`: lower camel case (e.g., `myFunction`)
#'   - `"PascalCase"`: upper camel case (e.g., `MyFunction`)
#'   - `"google"`: dot-separated lowercase (e.g., `my.function`)
#' @param num_to_word An optional named vector used to expand digit
#'   abbreviations inside function names into words. Names give the replacement
#'   word and values give the digit abbreviation, defaulting to
#'   `c("for" = 4, "to" = 2)`. Any input other than a named vector, `NULL`, or
#'   `FALSE` is an error. Supply `NULL` or `FALSE` to disable the expansion.
#' @param ... Additional arguments. Currently unused and must be empty.
#'
#' @return
#' Invisibly returns the path to the modified file.
#'
#' @details
#' Function definitions are identified using the pattern
#' `name <- function(`, `name = function(`, or the R 4.1+ shorthand
#' `name <- \\(` / `name = \\(`. Both the definition site and all
#' call sites / references within the file are updated. The conversion handles
#' mixed existing styles (snake_case, camelCase, PascalCase, dot.separated)
#' and normalizes function names to the target style.
#'
#' Digit abbreviations are expanded into words before the target style is
#' applied, so `list2env()` becomes `list_to_env()` and `wait4result()` becomes
#' `wait_for_result()` under `style = "snake_case"`. The expanded words are
#' formatted following `style`, e.g. `list2env()` becomes `listToEnv()` under
#' `style = "camelCase"` and `ListToEnv()` under `style = "PascalCase"`. Only
#' digit runs that appear in `num_to_word` are expanded: an identifier that
#' contains an unmapped digit run (for example `scale_x_log10()`) is left
#' untouched.
#'
#' @examples
#' \donttest{
#' temp <- tempfile(fileext = ".R")
#' writeLines("foo_bar <- function(){message('foo_bar')}", temp)
#' rename_func(temp, style = "camelCase")
#' readLines(temp)
#' rename_func(temp, style = "snake_case")
#' readLines(temp)
#'
#' writeLines("list2env <- function(x) x", temp)
#' rename_func(temp, style = "snake_case")
#' readLines(temp)
#' # "list_to_env <- function(x) x"
#' }
#'
#' @export
rename_func <- function(
  path = NULL,
  style = c("snake_case", "camelCase", "PascalCase", "google"),
  num_to_word = c("for" = 4L, "to" = 2L),
  ...
) {
  rlang::check_dots_empty()

  path <- path %||%
    if (rstudioapi::isAvailable()) rstudioapi::getActiveDocumentContext()$path
  if (is.null(path) || !nzchar(path)) {
    cli::cli_abort(message = c("x" = "{.arg path} is required"))
  }

  style <- match_arg(
    arg = style,
    choices = c("snake_case", "camelCase", "PascalCase", "google")
  )

  num_lookup <- num_to_word_lookup(num_to_word = num_to_word)

  lines <- readLines(con = path, warn = FALSE)

  # Detect function definitions: `?name`? <- function(  or  `?name`? = function(
  old_names <- detect_func_defs(lines = lines)

  if (length(old_names) == 0L) {
    cli::cli_alert_info(
      text = "No function definitions found in {.file {path}}"
    )
    return(invisible(path))
  }

  # Convert each function name to the target style
  new_names <- vapply(
    X = old_names,
    FUN = to_style,
    FUN.VALUE = character(length = 1L),
    style = style,
    num_lookup = num_lookup,
    USE.NAMES = FALSE
  )

  # Drop names that are already in the target style
  changed <- old_names != new_names
  old_names <- old_names[changed]
  new_names <- new_names[changed]

  if (length(old_names) == 0L) {
    cli::cli_alert_info(
      text = "All function names already in {.val {style}} style."
    )
    return(invisible(path))
  }

  # Sort by descending name length so shorter names don't clobber longer ones
  ord <- order(nchar(x = old_names), decreasing = TRUE)
  old_names <- old_names[ord]
  new_names <- new_names[ord]

  text <- paste(lines, collapse = "\n")
  renamed <- rf_rename_text_rs(
    text = text,
    old_names = old_names,
    new_names = new_names
  )
  text <- renamed$text
  n_renamed <- renamed$n_renamed

  writeLines(text = text, con = path)
  cli::cli_alert_success(
    text = "Renamed {n_renamed} function{?s} to {.val {style}} style in {.file {path}}"
  )

  invisible(path)
}

# ---------------------------------------------------------------------------
# Helper: detect function definitions line by line
# ---------------------------------------------------------------------------

detect_func_defs <- function(lines) {
  rf_detect_func_defs_rs(lines = lines)
}

# ---------------------------------------------------------------------------
# Helper: convert an R identifier to a target naming style
# ---------------------------------------------------------------------------

to_style <- function(name, style, num_lookup = NULL) {
  rf_to_style_rs(
    name = name,
    style = style,
    num_lookup = if (is.null(num_lookup)) NULL else as.list(x = num_lookup)
  )
}

# ---------------------------------------------------------------------------
# Helper: validate and normalize the `num_to_word` mapping
# ---------------------------------------------------------------------------
# Returns `NULL` when the expansion is disabled, otherwise a named character
# vector whose names are digit abbreviations and whose values are the words
# they stand for, e.g. `c("2" = "to", "4" = "for")`.
num_to_word_lookup <- function(num_to_word, call = rlang::caller_env()) {
  if (is.null(num_to_word) || isFALSE(x = num_to_word)) {
    return(NULL)
  }

  nms <- names(num_to_word)
  digits <- trimws(x = as.character(num_to_word))

  if (
    !is.atomic(num_to_word) ||
      !is.vector(x = num_to_word) ||
      length(num_to_word) == 0L ||
      is.null(nms) ||
      anyNA(nms) ||
      !all(grepl(pattern = "^[a-zA-Z]+$", x = nms)) ||
      anyNA(digits) ||
      !all(grepl(pattern = "^[0-9]+$", x = digits)) ||
      anyDuplicated(x = digits) > 0L
  ) {
    cli::cli_abort(
      message = c(
        "x" = "{.arg num_to_word} must be a named vector, {.val NULL}, or {.val FALSE}.",
        "i" = "Names give the replacement word and values the digit abbreviation, e.g. {.code c(\"for\" = 4, \"to\" = 2)}."
      )
    )
  }

  lookup <- nms
  names(lookup) <- digits
  lookup
}

# ---------------------------------------------------------------------------
# Helper: expand digit abbreviations inside a single word
# ---------------------------------------------------------------------------
# `word` is a single lower-case token such as "list2env". Each digit run found
# in `num_lookup` is returned as its own element. A word containing at least
# one unmapped digit run is returned unchanged as a single element, so that
# identifiers such as "scale_x_log10" or "x10y" stay intact.
split_word_numbers <- function(word, num_lookup) {
  rf_split_word_numbers_rs(
    word = word,
    num_lookup = if (is.null(num_lookup)) NULL else as.list(x = num_lookup)
  )
}
