#' Unpack values into multiple variables
#'
#' Assign elements of a list, vector, or data frame to variables in the calling
#' environment. The left-hand side must be a call to [base::c()] containing
#' variable names. Nested `c()` calls unpack nested lists. Named, missing
#' arguments select elements by name (for example, `c(cyl =, wt =)`). A
#' `..name` collector receives the positional elements not consumed by the other
#' targets in the same `c()` call; it may occur at the beginning, middle, or end.
#' The anonymous `..` collector discards those elements. Use `.` and `_` to skip
#' exactly one element.
#'
#' @param lhs A destructuring target composed of variable names, nested
#'   [base::c()] calls, named missing arguments for name-based extraction, and
#'   optional `.` or `_` placeholders. A single `..name` collector may appear
#'   anywhere among positional targets; `..` is an anonymous collector that
#'   discards its matched elements.
#' @param rhs A list, atomic vector, or data frame whose elements are assigned.
#'
#' @return The value of `rhs`, returned invisibly.
#' @examples
#' c(latitude, longitude) %<-% list(38.061944, -122.643889)
#'
#' c(cyl =, wt =) %<-% mtcars
#'
#' c(first, ..rest) %<-% letters
#'
#' c(..skip, penultimate, last) %<-% 1:5
#'
#' c(begin, ..middle, end) %<-% 1:5
#'
#' c(name, c(x, y), .) %<-% list("station", list(1, 2), "unused")
#'
#' @export
`%<-%` <- function(lhs, rhs) {
  unpack_assign_rs(substitute(lhs), rhs, parent.frame())
  invisible(rhs)
}
