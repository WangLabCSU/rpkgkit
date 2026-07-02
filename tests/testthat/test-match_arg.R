test_that("match_arg aborts when choices is empty", {
  expect_error(
    rpkgkit:::match_arg("x", character(0)),
    "No choices provided"
  )
})

test_that("match_arg returns default when arg is NULL", {
  result <- rpkgkit:::match_arg(NULL, c("a", "b", "c"))
  expect_equal(result, "a")
})

test_that("match_arg returns custom default when arg is NULL and default provided", {
  result <- rpkgkit:::match_arg(NULL, c("a", "b", "c"), default = "b")
  expect_equal(result, "b")
})

test_that("match_arg returns exact match", {
  result <- rpkgkit:::match_arg("apple", c("apple", "banana", "cherry"))
  expect_equal(result, "apple")
})

test_that("match_arg returns partial match when unique", {
  result <- rpkgkit:::match_arg("app", c("apple", "banana", "cherry"))
  expect_equal(result, "apple")
})

test_that("match_arg falls through to default when no match and default is not NULL", {
  result <- rpkgkit:::match_arg("x", c("a", "b", "c"), default = "b")
  expect_equal(result, "b")
})

test_that("match_arg aborts when no match and default is NULL", {
  expect_error(
    rpkgkit:::match_arg("x", c("a", "b", "c"), default = NULL)
  )
})

test_that("match_arg aborts when arg length > 1 and no match", {
  expect_error(
    rpkgkit:::match_arg(c("x", "y"), c("a", "b"), default = NULL)
  )
})

test_that("match_arg with ambiguous partial match falls through to default", {
  result <- rpkgkit:::match_arg(
    "a",
    c("apple", "application", "banana"),
    default = "banana"
  )
  # "a" is ambiguous between "apple" and "application", pmatch returns 0
  expect_equal(result, "banana")
})
