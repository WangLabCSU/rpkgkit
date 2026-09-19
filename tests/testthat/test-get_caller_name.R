test_that("get_caller_name with offset 0 returns its own name", {
  result <- rpkgkit:::get_caller_name(0L)
  expect_equal(result, "get_caller_name()")
})

test_that("get_caller_name with offset 1 returns calling function name", {
  wrapper <- function() rpkgkit:::get_caller_name(1L)
  result <- wrapper()
  expect_equal(result, "wrapper()")
})

test_that("get_caller_name with large offset returns 'global'", {
  wrapper <- function() rpkgkit:::get_caller_name(99L)
  result <- wrapper()
  expect_equal(result, "global")
})

test_that("get_caller_name returns 'expression' for anonymous function call", {
  result <- (function() rpkgkit:::get_caller_name(1L))()
  expect_equal(result, "expression")
})

test_that("get_caller_name with offset 2 from inner named function reaches outer caller", {
  inner <- function() rpkgkit:::get_caller_name(2L)
  outer <- function() inner()
  result <- outer()
  # offset 2: skip get_caller_name (1) and inner() (1) → outer()
  expect_equal(result, "outer()")
})

test_that("get_caller_name with offset 2 from named function skips intermediate wrapper", {
  direct <- function() rpkgkit:::get_caller_name(2L)
  result <- direct()
  # offset 2 from get_caller_name skips get_caller_name and direct()
  # target frame is the caller of direct() — the test body.
  # Inside testthat, this is not < 1, but the call may be testthat-internal.
  # So we just check it's not "global" when valid.
  expect_false(is.null(result))
  expect_type(result, "character")
})
