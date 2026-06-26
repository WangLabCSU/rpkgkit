# ---
# repo: Exceret/rpkgkit
# file: standalone-match_arg.R
# last-updated: 2026-04-16
# license: https://unlicense.org
# imports: [rlang, cli]
# ---

#' @title Argument Matching with Default Fallback
#'
#' @description
#' A robust argument matching function that supports exact matching, partial matching,
#' and provides sensible defaults when no match is found. This is an internal utility
#' function not intended for direct use by package users.
#'
#' @param arg The argument to match against choices. Can be `NULL` or a character vector.
#' @param choices A character vector of valid choices to match against.
#' @param default The default value to return if no match is found and `arg` is `NULL`.
#'                Defaults to the first element of `choices`.
#' @param call caller env
#' @param ... No usage
#'
#' @return Returns the matched choice from the `choices` vector. If no match is found
#'         and `arg` is `NULL`, returns the `default` value. If no match is found and
#'         `arg` is not `NULL`, throws an informative error.
#'
#' @details
#' This function provides a more flexible alternative to `base::match.arg()` with
#' the following matching strategy:
#' \enumerate{
#'   \item If `arg` is `NULL`, returns the `default` value
#'   \item Attempts exact matching using `base::match()`
#'   \item Falls back to partial matching using `base::pmatch()`
#'   \item If no match found and `default` is not `NULL`, returns `default`
#'   \item Otherwise, throws an informative error with valid choices
#' }
#'
#' The function uses `rlang::caller_env()` for accurate error reporting in the
#' context where the function was called.
#'
#' @examples
#' \donttest{
#' # Internal usage examples
#' match_arg("app", c("apple", "banana", "application"))  # Returns "apple"
#' match_arg(NULL, c("red", "green", "blue"))             # Returns "red" (default)
#' match_arg("gr", c("red", "green", "blue"))             # Returns "green"
#'
#' # Would error: match_arg("invalid", c("valid1", "valid2"))
#' }
#'
#' @seealso
#' \code{\link[base]{match}} for exact matching \\
#' \code{\link[base]{pmatch}} for partial matching \\
#' \code{\link[rlang]{caller_env}} for calling environment context
#'
#' @noRd
#'
match_arg <- function(
  arg,
  choices,
  default = choices[1L],
  call = rlang::caller_env(),
  .envir = environment(),
  .frame = .envir,
  ...
) {
  if (length(choices) == 0L) {
    cli::cli_abort(
      c(
        "x" = "No choices provided.",
        "i" = "Choices must be a non-empty character vector."
      ),
      class = "MatchArgError",
      call = call,
      .envir = .envir,
      .frame = .frame
    )
  }
  if (is.null(arg)) {
    return(default)
  }
  if (length(arg) == 1L) {
    # Exact match
    idx <- match(arg, choices, nomatch = 0L)
    if (idx > 0L) {
      return(choices[idx])
    }
    # Patial match
    idx <- pmatch(arg, choices, nomatch = 0L, duplicates.ok = FALSE)
    if (idx > 0L) {
      return(choices[idx])
    }
  }

  if (!is.null(default)) {
    return(default)
  }
  cli::cli_abort(
    c(
      "x" = "{.val {arg}} is not a valid choice for {.arg {deparse(substitute(arg))}}.",
      "i" = "Must be one of: {.val {choices}}."
    ),
    class = "MatchArgError",
    call = call,
    .envir = .envir,
    .frame = .frame
  )
}
