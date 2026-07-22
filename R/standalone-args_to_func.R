# ---
# repo: WangLabCSU/rpkgkit
# file: standalone-args_to_func.R
# last-updated: 2026-07-21
# license: https://unlicense.org
# imports: [rlang]
# ---
#
# Match arguments to function calls and filter argument lists.
#
# ## Changelog:
#
# 2026-07-21:
# * Removed redundant dependency standalone-purrr
#
# 2026-07-14:
# * Removed redundant dependency cli
#
# 2026-06-27:
# * Fixed lints
#
# nocov start

#' @title Keep Wanted Arguments According to A Function from Dots
#' @description
#' filter_args_for_func filters a list of arguments to include only those that
#' match the formal arguments of a specified function, with optional support
#' for preserving additional arguments via the \code{keep} parameter.
#' This is useful for preparing argument lists for function calls, especially
#' when dealing with functions that have many optional parameters or when
#' passing arguments through multiple function layers.
#'
#' @param args_list A named list of arguments to filter
#' @param fun The target function whose formal arguments will be used for filtering
#' @param keep Character vector of argument names to preserve regardless of
#'   whether they appear in \code{fun}'s formal parameters. Default is \code{NULL}.
#'   Useful for retaining arguments needed by downstream functions or wrappers
#'   that consume \code{...}.
#'
#' @return A filtered list containing:
#'   \itemize{
#'     \item Arguments from \code{args_list} that match formal parameters of \code{fun}
#'       (excluding the "..." parameter)
#'     \item Additional arguments specified in \code{keep} (if not \code{NULL})
#'   }
#'
#' @details
#' This function is particularly useful in scenarios where you have a large
#' list of parameters and want to pass only the relevant ones to a specific
#' function while preserving certain arguments for downstream processing
#' (e.g., arguments consumed by nested \code{...} parameters).
#'
#' The \code{keep} parameter enables flexible argument forwarding patterns
#' common in wrapper functions and pipeline designs.
#'
#' @examples
#' \donttest{
#' # Example function with specific parameters
#' example_function <- function(a, b, c = 10, d = 20) {
#'   return(a + b + c + d)
#' }
#'
#' # Create a list with both relevant and irrelevant arguments
#' all_args <- list(
#'   a = 1,
#'   b = 2,
#'   c = 3,
#'   e = 4,  # Not in function formals
#'   f = 5   # Not in function formals
#' )
#'
#' # Basic usage: filter to only include arguments matching function parameters
#' filtered_args <- filter_args_for_func(all_args, example_function)
#' print(filtered_args)
#' #> $a
#' #> [1] 1
#' #>
#' #> $b
#' #> [1] 2
#' #>
#' #> $c
#' #> [1] 3
#'
#' # Advanced usage: preserve additional arguments for downstream processing
#' filtered_with_keep <- filter_args_for_func(all_args, example_function, keep = c("e", "f"))
#' print(filtered_with_keep)
#' #> $a
#' #> [1] 1
#' #>
#' #> $b
#' #> [1] 2
#' #>
#' #> $c
#' #> [1] 3
#' #>
#' #> $e
#' #> [1] 4
#' #>
#' #> $f
#' #> [1] 5
#'
#' # Execute with filtered arguments
#' result <- do.call(example_function, filtered_args)
#' print(result)
#' #> [1] 16
#' }
#'
#' @seealso
#' [formals()] for accessing function formal arguments,
#' [do.call()] for executing functions with argument lists,
#' [names()] for working with list names
#' @noRd
filter_args_for_func <- function(args_list, fun, keep = NULL) {
  # Extract formal parameter names (excluding "...")
  fun_formals <- names(formals(fun))
  fun_formals <- fun_formals[fun_formals != "..."]

  # Combine function formals with explicitly preserved arguments
  keep_names <- if (is.null(keep)) character(0) else keep
  valid_names <- unique(c(fun_formals, keep_names))

  # Filter args_list to retain only valid names
  args_list[names(args_list) %in% valid_names]
}

#' @title Match Functions to Argument List
#' @description
#' Identifies functions compatible with a given set of named arguments. A function
#' is considered compatible if:
#' \itemize{
#'   \item It has a \code{...} parameter (\strong{loose matching}), OR
#'   \item All argument names in \code{args_list} exist in its formal parameters
#'         (\strong{strict matching}, default behavior).
#' }
#'
#' @param args_list Named list of arguments to match. Must have non-empty names
#'   when non-empty.
#' @param ... Functions to test for compatibility.
#' @param name_only Logical. If \code{TRUE}, return character vector of function
#'   names/identifiers instead of function objects. Default: \code{FALSE}.
#' @param top_one_only Logical. If \code{TRUE}, return only the single best-matching
#'   function (ranked by number of matched parameters and parameter position).
#'   Default: \code{FALSE}.
#' @param dots_enabled Logical. If \code{TRUE}, enable loose matching: any function
#'   with a \code{...} parameter is considered compatible regardless of other
#'   parameter names. Default: \code{FALSE} (strict matching).
#'
#' @return
#'   \itemize{
#'     \item \code{name_only = FALSE, top_one_only = FALSE}: List of compatible function objects
#'     \item \code{name_only = TRUE, top_one_only = FALSE}: Character vector of function identifiers
#'           (named functions retain their symbol name; anonymous functions become \code{"anonymous_<index>"})
#'     \item \code{top_one_only = TRUE}: Single function object or name (depending on \code{name_only})
#'   }
#'
#' @examples
#' \donttest{
#' f1 <- function(a, b) a + b
#' f2 <- function(x, y, ...) x * y
#' f3 <- function(p, q) p - q
#'
#' args <- list(a = 1, b = 2)
#'
#' # Strict matching (default): returns f1 only
#' match_func_to_args(args, f1, f2, f3)
#'
#' # Loose matching: returns f1 and f2 (both accept 'a' and 'b' via strict match or ...)
#' match_func_to_args(args, f1, f2, f3, dots_enabled = TRUE)
#'
#' # Return only function names
#' match_func_to_args(args, f1, f2, name_only = TRUE, dots_enabled=TRUE)
#' # Returns: c("f1", "f2") when dots_enabled=TRUE
#' }
#' @noRd
match_func_to_args <- function(
  args_list,
  ...,
  name_only = FALSE,
  top_one_only = FALSE,
  dots_enabled = FALSE
) {
  # Validate args_list has proper names when non-empty
  if (
    length(args_list) > 0 &&
      is.null(names(args_list)) ||
      !all(nzchar(names(args_list)))
  ) {
    rlang::abort(c(
      "x" = "`args_list` must be a named list with non-empty names for all elements when non-empty."
    ))
  }

  # Capture actual function objects
  dots_funcs <- rlang::list2(...)

  # Handle empty ... case
  if (length(dots_funcs) == 0L) {
    return(if (name_only) character(0L) else list())
  }

  func_names <- names(rlang::enquos(..., .named = TRUE))
  names(dots_funcs) <- func_names
  func_formals <- lapply(dots_funcs, formals)
  names(func_formals) <- func_names

  guess <- vector(mode = "list", length = length(func_formals))
  for (i in seq_along(func_formals)) {
    lst <- func_formals[[i]]
    func_name <- func_names[[i]]

    has_dots <- "..." %in% names(lst)
    has_these_args <- names(lst) %in% names(args_list)
    positions <- which(has_these_args)
    count <- sum(has_these_args)

    guess[[i]] <- data.frame(
      func_name = func_name,
      position_sum = if (length(positions) == 0L) 0L else sum(positions),
      arg_count = count,
      has_dots = has_dots,
      stringsAsFactors = FALSE
    )
  }

  guess_df <- do.call(rbind, guess)
  guess_df <- guess_df[
    order(-guess_df$arg_count, guess_df$position_sum, guess_df$has_dots),
    ,
    drop = FALSE
  ]

  if (dots_enabled) {
    first_hold <- guess_df[1L, "arg_count"] == length(args_list)
    logi_return <- guess_df$has_dots
    logi_return[1L] <- first_hold

    if (name_only) {
      return(guess_df$func_name[logi_return])
    } else {
      return(dots_funcs[guess_df$func_name[logi_return]])
    }
  }

  guess_df <- guess_df[guess_df$arg_count > 0L, , drop = FALSE]

  # handle strict matching: funcs that can exactly match all args
  logical_vec <- vapply(
    X = func_formals,
    FUN = function(lst) {
      modified <- utils::modifyList(lst, args_list, keep.null = TRUE)
      if (length(modified) != length(lst)) FALSE else TRUE
    },
    FUN.VALUE = logical(1L)
  )

  names(logical_vec) <- func_names
  guess_df$exactly_matched <- logical_vec[guess_df$func_name]
  guess_df <- guess_df[guess_df$exactly_matched, , drop = FALSE]

  if (top_one_only) {
    if (
      nrow(guess_df) >= 2L &&
        guess_df$position_sum[1] == guess_df$position_sum[2] &&
        guess_df$arg_count[1] == guess_df$arg_count[2]
    ) {
      rlang::warn(
        "Arguments provided is not enough to select a function, still return the first function but result may differ from expected"
      )
    }
    if (name_only) {
      return(guess_df$func_name[1])
    } else {
      return(dots_funcs[[guess_df$func_name[1L]]])
    }
  }

  if (name_only) {
    return(guess_df$func_name)
  }

  dots_funcs[guess_df$func_name]
}

#' @title Get Function Arguments from Calling Context
#'
#' @description Retrieves the arguments passed to the calling function, optionally filtering by name or returning only argument names.
#'
#' @param exclude A character or interger vector of argument names to exclude from the result. Default is `NULL`.
#' @param name_only Logical. If `TRUE`, returns only argument names. If `FALSE`, returns the full argument list. Default is `FALSE`.
#' @param call The call expression to extract arguments from. Default is `rlang::caller_call()`.
#' @param dots_expand Logical. Whether to expand `...` arguments. Default is `TRUE`.
#' @param envir The environment in which to evaluate the call. Default is `rlang::caller_env()`.
#'
#' @return If `name_only` is `TRUE`, a character vector of argument names. Otherwise, a named list of arguments.
#'
#' @examples
#' \donttest{
#' inner_func <- function(a, b, ...) {
#'   get_func_args(exclude = "b", name_only = TRUE)
#' }
#' inner_func(1, 2, 3, 4)  # Returns c("a", "...")
#' }
#'
#' @noRd
get_func_args <- function(
  exclude = NULL,
  name_only = FALSE,
  func = rlang::caller_fn(),
  call = rlang::caller_call(),
  dots_expand = TRUE,
  envir = rlang::caller_env()
) {
  cl <- rlang::call_match(
    call = call,
    fn = func,
    defaults = TRUE,
    dots_env = envir,
    dots_expand = dots_expand
  )
  args_list <- as.list(cl)[-1L]
  if (length(exclude) != 0L) {
    if (is.character(exclude)) {
      args_list <- args_list[!names(args_list) %in% exclude]
    } else if (is.numeric(exclude)) {
      args_list <- args_list[-exclude]
    } else {
      rlang::abort(c(
        "x" = sprintf("GetFuncArgs: `exclude` cannot be <%s>", class(exclude)),
        ">" = "Expect <character/integer/numeric>"
      ))
    }
  }
  if (name_only) {
    arg_names <- names(args_list)
    arg_names <- arg_names[nzchar(arg_names)]

    if (dots_expand && "..." %in% names(formals(func))) {
      arg_names <- c(arg_names, "...")
    }

    return(arg_names)
  }

  lapply(args_list, eval, envir = envir)
}

# nocov end
