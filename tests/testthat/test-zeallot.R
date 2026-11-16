# ---------------------------------------------------------------------------
# %<-% -- destructuring assignment (R/75_zeallot.R)
# ---------------------------------------------------------------------------

test_that("%<-% unpacks a list into the calling environment", {
  c(latitude, longitude) %<-% list(38.061944, -122.643889)

  expect_equal(latitude, 38.061944)
  expect_equal(longitude, -122.643889)
})

test_that("%<-% unpacks an atomic vector into scalar elements", {
  c(first, second) %<-% c(10, 20)

  expect_identical(first, 10)
  expect_identical(second, 20)
})

test_that("%<-% returns rhs invisibly", {
  rhs <- list(1, "two")
  result <- withVisible(c(a, b) %<-% rhs)

  expect_false(result$visible)
  expect_identical(result$value, rhs)
})

test_that("%<-% overwrites an existing binding in the calling frame", {
  value <- "old"
  c(value) %<-% list("new")

  expect_equal(value, "new")
})

test_that("%<-% assigns in the frame of its caller, not globally", {
  unpack <- function(values) {
    c(inner_a, inner_b) %<-% values
    c(inner_a, inner_b)
  }

  expect_equal(unpack(list(8, 9)), c(8, 9))
  expect_false(exists("inner_a", inherits = FALSE))
})

test_that("%<-% preserves the type of each atomic element", {
  c(lgl_a, lgl_b) %<-% c(TRUE, FALSE)
  c(int_a, int_b) %<-% 1:2
  c(chr_a, chr_b) %<-% c("x", "y")
  c(cplx_a, cplx_b) %<-% c(1 + 2i, 3 + 4i)
  c(raw_a, raw_b) %<-% as.raw(c(1, 2))

  expect_identical(lgl_a, TRUE)
  expect_identical(lgl_b, FALSE)
  expect_identical(int_a, 1L)
  expect_identical(int_b, 2L)
  expect_identical(chr_a, "x")
  expect_identical(chr_b, "y")
  expect_identical(cplx_a, 1 + 2i)
  expect_identical(cplx_b, 3 + 4i)
  expect_identical(raw_a, as.raw(1))
  expect_identical(raw_b, as.raw(2))
})

test_that("%<-% extracts data frame columns by position", {
  c(first_col, ..other_cols) %<-% mtcars

  expect_equal(first_col, mtcars[[1]])
  expect_length(other_cols, ncol(mtcars) - 1L)
  expect_equal(other_cols[[1]], mtcars[[2]])
})

test_that("%<-% requires matching lengths without a collector", {
  expect_error(
    c(a) %<-% list(1, 2),
    "must be the same length",
    fixed = TRUE
  )
  expect_error(
    c(a, b) %<-% list(1),
    "Cannot unpack element 2 from an object of length 1",
    fixed = TRUE
  )
  expect_error(
    c(a) %<-% list(),
    "Cannot unpack element 1 from an object of length 0",
    fixed = TRUE
  )
})

test_that("%<-% requires the lhs to be a c() call", {
  expect_error(
    foo %<-% list(1),
    "must be a call to `c()`",
    fixed = TRUE
  )
  expect_error(
    list(foo) %<-% list(1),
    "must be a call to `c()`",
    fixed = TRUE
  )
})

test_that("%<-% rejects invalid destructuring targets", {
  expect_error(
    c(a + b) %<-% list(1, 2),
    "Invalid destructuring target",
    fixed = TRUE
  )
  expect_error(
    c(42) %<-% list(1),
    "Invalid destructuring target",
    fixed = TRUE
  )
  expect_error(
    c(a, ) %<-% list(1, 2),
    "Empty slot in the left-hand side",
    fixed = TRUE
  )
  expect_error(
    c(...) %<-% 1:3,
    "cannot be used as a destructuring target",
    fixed = TRUE
  )
})

test_that("%<-% rejects unsupported rhs types", {
  expect_error(
    c(a) %<-% function(x) x,
    "Unsupported rhs type",
    fixed = TRUE
  )
  expect_error(
    c(a) %<-% NULL,
    "Unsupported rhs type",
    fixed = TRUE
  )
  expect_error(
    c(a) %<-% new.env(),
    "Unsupported rhs type",
    fixed = TRUE
  )
})

test_that("%<-% unpacks nested c() calls", {
  c(name, c(x, y), tail) %<-% list("station", list(1, 2), "unused")

  expect_equal(name, "station")
  expect_equal(x, 1)
  expect_equal(y, 2)
  expect_equal(tail, "unused")
})

test_that("a nested c() call can have its own collector", {
  c(head, c(body, ..tail)) %<-% list(0, as.list(1:4))

  expect_equal(head, 0)
  expect_equal(body, 1L)
  expect_equal(tail, as.list(2:4))
})

test_that(". and _ placeholders skip exactly one element", {
  c(a, ., b) %<-% 1:3
  expect_equal(c(a, b), c(1L, 3L))

  # R reserves `_` as a pipe placeholder, so build the lhs call instead of
  # writing it literally.
  lhs <- as.call(list(quote(c), quote(c_), as.name("_"), quote(d)))
  eval(as.call(list(quote(`%<-%`), lhs, 1:3)))
  expect_equal(c(c_, d), c(1L, 3L))
})

test_that("named missing arguments select elements by name", {
  c(cyl = , wt = ) %<-% mtcars

  expect_equal(cyl, mtcars$cyl)
  expect_equal(wt, mtcars$wt)
})

test_that("named targets do not depend on the order of elements", {
  c(x = , y = ) %<-% list(y = 2, x = 1)

  expect_equal(x, 1)
  expect_equal(y, 2)
})

test_that("named targets must omit their right-hand side", {
  expect_error(
    c(cyl = 1) %<-% mtcars,
    "Named unpacking targets must omit their right-hand side",
    fixed = TRUE
  )
})

test_that("named targets fail clearly when names are absent or unknown", {
  expect_error(
    c(a = ) %<-% 1:2,
    "from an unnamed object",
    fixed = TRUE
  )
  expect_error(
    c(nope = ) %<-% mtcars,
    "was not found",
    fixed = TRUE
  )
})

test_that("a trailing ..name collector receives the remaining elements", {
  c(first, ..rest) %<-% 1:5

  expect_equal(first, 1L)
  expect_equal(rest, 2:5)
})

test_that("a leading ..name collector consumes the prefix", {
  c(..head, last) %<-% 1:5

  expect_equal(head, 1:4)
  expect_equal(last, 5L)
})

test_that("a middle ..name collector consumes the gap", {
  c(begin, ..middle, end) %<-% 1:5

  expect_equal(begin, 1L)
  expect_equal(middle, 2:4)
  expect_equal(end, 5L)
})

test_that("a lone collector captures all elements", {
  c(..everything) %<-% 1:3

  expect_equal(everything, 1:3)
})

test_that("a collector can match zero elements", {
  c(a, ..rest, b) %<-% 1:2

  expect_equal(a, 1L)
  expect_equal(rest, integer())
  expect_equal(b, 2L)
})

test_that("collectors preserve input names", {
  c(a, ..rest) %<-% c(alpha = 1, beta = 2, gamma = 3)

  expect_equal(a, 1)
  expect_equal(rest, c(beta = 2, gamma = 3))
})

test_that("collectors work on lists", {
  c(a, ..rest) %<-% list("x", 2, 3)

  expect_equal(a, "x")
  expect_equal(rest, list(2, 3))
})

test_that("the anonymous .. collector discards matched elements", {
  c(a, ..) %<-% 1:5

  expect_equal(a, 1L)
  expect_false(exists("..", inherits = FALSE))
})

test_that("only one collector is allowed in each c() target", {
  expect_error(
    c(..a, ..b) %<-% 1:5,
    "Only one collector is allowed in each c() target",
    fixed = TRUE
  )
})

test_that("a collector errors when trailing targets do not fit", {
  expect_error(
    c(a, ..rest, b, d) %<-% 1:2,
    "Cannot unpack 2 trailing elements from an object of length 2",
    fixed = TRUE
  )
})

test_that("unpack_assign_rs validates the env argument", {
  expect_error(
    unpack_assign_rs(quote(c(a, b)), list(1, 2), 1),
    "`env` must be an environment",
    fixed = TRUE
  )
})
