# ---- Public API -----------------------------------------------------------
# The expression walk lives in Rust: `src/rust/src/get_var_value/gvv.rs`
# (`gvv_trace_rs()`), which replaces the former standalone file
# `import-standalone-get_var_value.R` (WangLabCSU/SigBridgeR, unlicense).
# The definition environment, the traversal of the function body and the
# substitution of known variables are all done in Rust; only the final
# `eval()` stays in R, so that a failing evaluation keeps its original
# condition.

#' Trace and compute the value of a variable defined inside a function
#'
#' @description
#' Recursively traces variable assignments (both from function parameters and
#' function body) to reconstruct and evaluate the expression that produces
#' the variable's value. The trace follows the assignment chain until it
#' reaches literal values or unresolvable symbols.
#'
#' @param var_name Character string, the name of the target variable.
#' @param func An R function inside which the variable is defined.
#' @param .env Evaluation environment used for resolving function calls
#'   (e.g. `runif` from the **stats** package). Defaults to the caller's
#'   environment (`rlang::current_env()`), which is typically `.GlobalEnv`
#'   and has access to all attached packages.
#'
#' @return The computed value of the variable.
#'
#' @examples
#' f <- function(save_path = "analysis") {
#'   save_path_new <- file.path(save_path, "res")
#'   return(save_path_new)
#' }
#' get_var_value("save_path_new", f)   # returns "./analysis/res"
#'
#' g <- function(a = 1, b = 2){
#'   c <- a * 2 + b * 3
#'   d = c^2
#'   e <<- d - 1
#'   e
#' }
#' get_var_value("e", g)   # returns 63
#'
#' h <- function(a = "A", ...){
#'   a <- 1
#'   return(a)
#'   a <- 2
#'   a
#' }
#' get_var_value("a",h)    # returns 1 (dead code after return is ignored)
#'
#' i <- function(x = 2) {
#'   for (k in 1:3) x <- x * 2
#'   x
#' }
#' get_var_value("x", i)   # returns 16
#'
#' j <- function(x = 2) {
#'   while (x < 10) x <- x * 2
#'   x
#' }
#' get_var_value("x", j)   # returns 16
#'
#' @export
get_var_value <- function(var_name, func, .env = rlang::current_env()) {
  if (!is.function(func)) {
    rlang::abort("`func` must be a function.")
  }
  if (!is.character(var_name) || length(var_name) != 1L || is.na(var_name)) {
    rlang::abort("`var_name` must be a single string.")
  }

  # 1-2. Build the definition environment from the formals, walk the body and
  #      4. resolve the target expression.
  traced <- gvv_trace_rs(
    var_name = var_name,
    fmls = formals(func),
    body = body(func),
    env = .env
  )

  # 3. Verify the target variable exists.
  if (!isTRUE(traced$found)) {
    rlang::abort(c(
      sprintf("Variable '%s' not found in function definition.", var_name),
      ">" = "It is neither a parameter with default nor assigned in the function body."
    ))
  }

  # 5. Evaluate and return.
  eval(traced$expr, envir = .env)
}
