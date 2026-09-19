# ---------------------------------------------------------------------------
# package_convert_int_literals -- integration tests
# ---------------------------------------------------------------------------

# Build a minimal R package tree in a temporary directory.
make_test_pkg <- function(env = parent.frame()) {
  root <- withr::local_tempdir(.local_envir = env)
  writeLines(
    c(
      "Package: demopkg",
      "Version: 0.0.1",
      "Title: Demo",
      "Description: A demo package.",
      "License: MIT"
    ),
    file.path(root, "DESCRIPTION")
  )
  dir.create(file.path(root, "R"))
  dir.create(file.path(root, "tests"))
  dir.create(file.path(root, "tests", "testthat"))
  root
}

# `package_convert_int_literals()` returns paths normalized via
# `normalizePath()`, which on Windows uses a different separator/drive form and
# on macOS resolves symlinks (e.g. `/var` -> `/private/var`, temp dirs ->
# 8.3 short paths). Normalize both sides before comparing so the tests are
# portable.
norm <- function(path) {
  normalizePath(path, winslash = "/", mustWork = FALSE)
}

test_that("package_convert_int_literals aborts when path is not a package", {
  root <- withr::local_tempdir()

  expect_error(
    package_convert_int_literals(root),
    "does not look like an R package root"
  )
})

test_that("package_convert_int_literals aborts when ... is not empty", {
  root <- make_test_pkg()
  writeLines("f <- function() 1", file.path(root, "R", "a.R"))

  expect_error(
    package_convert_int_literals(root, extra = "foo"),
    "must be empty"
  )
  # the file must be left untouched when the check fails
  expect_equal(readLines(file.path(root, "R", "a.R"), warn = FALSE),
               "f <- function() 1")
})

test_that("package_convert_int_literals validates `recursive`", {
  root <- make_test_pkg()

  expect_error(
    package_convert_int_literals(root, recursive = "yes"),
    "must be `TRUE` or `FALSE`"
  )
})

test_that("package_convert_int_literals converts integers in R/ files", {
  root <- make_test_pkg()
  writeLines("f <- function() seq_len(10)", file.path(root, "R", "a.R"))

  changed <- package_convert_int_literals(root)

  expect_equal(readLines(file.path(root, "R", "a.R"), warn = FALSE),
               "f <- function() seq_len(10L)")
  expect_equal(changed, norm(file.path(root, "R", "a.R")))
})

test_that("package_convert_int_literals returns changed paths invisibly", {
  root <- make_test_pkg()
  writeLines("f <- function() 1", file.path(root, "R", "a.R"))

  expect_invisible(package_convert_int_literals(root))
})

test_that("package_convert_int_literals also processes tests/ files", {
  root <- make_test_pkg()
  writeLines("f <- function() 1", file.path(root, "R", "a.R"))
  test_file <- file.path(root, "tests", "testthat", "test-a.R")
  writeLines('test_that("x", expect_equal(1, 1))', test_file)

  changed <- package_convert_int_literals(root)

  expect_equal(
    readLines(test_file, warn = FALSE),
    'test_that("x", expect_equal(1L, 1L))'
  )
  expect_true(norm(test_file) %in% changed)
  expect_length(changed, 2L)
})

test_that("package_convert_int_literals picks up .R and .r files", {
  root <- make_test_pkg()
  writeLines("f <- function() 1", file.path(root, "R", "a.R"))
  writeLines("g <- function() 2", file.path(root, "R", "b.r"))

  changed <- package_convert_int_literals(root)

  expect_true(norm(file.path(root, "R", "a.R")) %in% changed)
  expect_true(norm(file.path(root, "R", "b.r")) %in% changed)
})

test_that("package_convert_int_literals only reports files that changed", {
  root <- make_test_pkg()
  writeLines("f <- function() 10L", file.path(root, "R", "unchanged.R"))
  writeLines("g <- function() 10", file.path(root, "R", "changed.R"))

  changed <- package_convert_int_literals(root)

  expect_equal(changed, norm(file.path(root, "R", "changed.R")))
})

test_that("package_convert_int_literals is idempotent", {
  root <- make_test_pkg()
  writeLines("f <- function() c(1, 2, 3)", file.path(root, "R", "a.R"))

  first <- package_convert_int_literals(root)
  second <- package_convert_int_literals(root)

  expect_length(first, 1L)
  expect_length(second, 0L)
})

test_that("package_convert_int_literals skips missing directories", {
  root <- make_test_pkg()
  unlink(file.path(root, "tests"), recursive = TRUE)
  writeLines("f <- function() 1", file.path(root, "R", "a.R"))

  changed <- package_convert_int_literals(root, dirs = c("R", "tests"))

  expect_equal(changed, norm(file.path(root, "R", "a.R")))
})

test_that("package_convert_int_literals respects a custom `dirs` argument", {
  root <- make_test_pkg()
  writeLines("f <- function() 1", file.path(root, "R", "a.R"))
  extra <- file.path(root, "extra")
  dir.create(extra)
  writeLines("g <- function() 2", file.path(extra, "b.R"))

  changed <- package_convert_int_literals(root, dirs = "extra")

  expect_equal(changed, norm(file.path(extra, "b.R")))
  # R/ was not touched
  expect_equal(readLines(file.path(root, "R", "a.R"), warn = FALSE),
               "f <- function() 1")
})

test_that("package_convert_int_literals respects recursive = FALSE", {
  root <- make_test_pkg()
  dir.create(file.path(root, "R", "sub"))
  writeLines("f <- function() 1", file.path(root, "R", "top.R"))
  writeLines("g <- function() 2", file.path(root, "R", "sub", "nested.R"))

  changed <- package_convert_int_literals(root, recursive = FALSE)

  expect_true(norm(file.path(root, "R", "top.R")) %in% changed)
  expect_false(norm(file.path(root, "R", "sub", "nested.R")) %in% changed)
  expect_equal(
    readLines(file.path(root, "R", "sub", "nested.R"), warn = FALSE),
    "g <- function() 2"
  )
})

test_that("package_convert_int_literals recurses by default", {
  root <- make_test_pkg()
  dir.create(file.path(root, "R", "sub"))
  writeLines("g <- function() 2", file.path(root, "R", "sub", "nested.R"))

  changed <- package_convert_int_literals(root)

  expect_true(norm(file.path(root, "R", "sub", "nested.R")) %in% changed)
})

test_that("package_convert_int_literals returns empty with a message when no R files", {
  root <- make_test_pkg()

  expect_message(
    result <- package_convert_int_literals(root),
    "No R files found"
  )
  expect_identical(result, character())
})

test_that("package_convert_int_literals normalizes a relative path", {
  root <- make_test_pkg()
  writeLines("f <- function() 1", file.path(root, "R", "a.R"))

  withr::local_dir(root)
  changed <- package_convert_int_literals(".")

  expect_equal(changed, norm(file.path(root, "R", "a.R")))
})

test_that("package_convert_int_literals defaults path to '.'", {
  root <- make_test_pkg()
  writeLines("f <- function() 1", file.path(root, "R", "a.R"))

  withr::local_dir(root)
  changed <- package_convert_int_literals()

  expect_length(changed, 1L)
})
