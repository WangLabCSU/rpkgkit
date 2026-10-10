# ---------------------------------------------------------------------------
# package_convert_pipe -- integration tests
# ---------------------------------------------------------------------------
#
# `package_convert_pipe()` follows the other `package_*()` helpers and returns
# an invisible logical success flag rather than the list of rewritten files, so
# these tests assert on the three things it actually exposes:
#   * the file contents it rewrote,
#   * the `Processed N file(s), updated M` summary it reports,
#   * the invisible logical it returns: `TRUE` when at least one file was
#     rewritten, `FALSE` when no files were found or nothing changed.

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

# Run `package_convert_pipe()` while capturing the cli messages it emits, so a
# test can assert on the summary line as well as on the returned value.
run_pkg_convert <- function(...) {
  messages <- character()
  value <- withCallingHandlers(
    package_convert_pipe(...),
    message = function(m) {
      messages <<- c(messages, conditionMessage(m))
      invokeRestart("muffleMessage")
    }
  )
  list(value = value, messages = paste(messages, collapse = ""))
}

# Assert the `Processed N file(s), updated M` summary without worrying about
# regex metacharacters.
expect_summary <- function(messages, n, updated) {
  expect_match(
    messages,
    paste0("Processed ", n, " ", if (n == 1L) "file" else "files",
           ", updated ", updated),
    fixed = TRUE
  )
}

test_that("package_convert_pipe aborts when path is not a package", {
  root <- withr::local_tempdir()

  expect_error(
    package_convert_pipe(root),
    "does not look like an R package root"
  )
})

test_that("package_convert_pipe aborts when ... is not empty", {
  root <- make_test_pkg()
  writeLines("x %>% identity()", file.path(root, "R", "a.R"))

  expect_error(
    package_convert_pipe(root, extra = "foo"),
    "must be empty"
  )
  expect_equal(
    readLines(file.path(root, "R", "a.R"), warn = FALSE),
    "x %>% identity()"
  )
})

test_that("package_convert_pipe validates `recursive`", {
  root <- make_test_pkg()

  expect_error(
    package_convert_pipe(root, recursive = "yes"),
    "must be `TRUE` or `FALSE`"
  )
})

test_that("package_convert_pipe validates `direction`", {
  root <- make_test_pkg()
  writeLines("x %>% identity()", file.path(root, "R", "a.R"))

  expect_error(
    package_convert_pipe(root, direction = "sideways"),
    "must be one of"
  )
  expect_equal(
    readLines(file.path(root, "R", "a.R"), warn = FALSE),
    "x %>% identity()"
  )
})

test_that("package_convert_pipe converts pipes in R/ files", {
  root <- make_test_pkg()
  writeLines("x %>% identity()", file.path(root, "R", "a.R"))

  res <- run_pkg_convert(root)

  expect_equal(
    readLines(file.path(root, "R", "a.R"), warn = FALSE),
    "x |> identity()"
  )
  expect_true(res$value)
  expect_summary(res$messages, n = 1L, updated = 1L)
})

test_that("package_convert_pipe converts toward the magrittr pipe", {
  root <- make_test_pkg()
  writeLines("x |> identity()", file.path(root, "R", "a.R"))

  package_convert_pipe(root, direction = "to_magrittr")

  expect_equal(
    readLines(file.path(root, "R", "a.R"), warn = FALSE),
    "x %>% identity()"
  )
})

test_that("package_convert_pipe returns its logical flag invisibly", {
  root <- make_test_pkg()
  writeLines("x %>% identity()", file.path(root, "R", "a.R"))

  first <- withVisible(package_convert_pipe(root))
  second <- withVisible(package_convert_pipe(root))

  expect_false(first$visible)
  expect_true(first$value)
  # Nothing left to convert the second time around.
  expect_false(second$visible)
  expect_false(second$value)
})

test_that("package_convert_pipe skips generated RcppExports files", {
  root <- make_test_pkg()
  rcpp_exports <- file.path(root, "R", "RcppExports.R")
  regular_file <- file.path(root, "R", "regular.R")
  writeLines("x %>% identity()", rcpp_exports)
  writeLines("y %>% identity()", regular_file)

  res <- run_pkg_convert(root)

  expect_equal(readLines(rcpp_exports, warn = FALSE), "x %>% identity()")
  expect_equal(readLines(regular_file, warn = FALSE), "y |> identity()")
  # The generated file is dropped from the file list, so only one file is seen.
  expect_summary(res$messages, n = 1L, updated = 1L)
})

test_that("package_convert_pipe skips generated files regardless of extension case", {
  root <- make_test_pkg()
  lowercase <- file.path(root, "R", "rcppexports.r")
  writeLines("x %>% identity()", lowercase)

  res <- run_pkg_convert(root)

  expect_equal(readLines(lowercase, warn = FALSE), "x %>% identity()")
  expect_false(res$value)
  expect_match(res$messages, "No R files found", fixed = TRUE)
})

test_that("package_convert_pipe processes explicitly selected tests/ files", {
  root <- make_test_pkg()
  writeLines("x %>% identity()", file.path(root, "R", "a.R"))
  test_file <- file.path(root, "tests", "testthat", "test-a.R")
  writeLines("y %>% identity()", test_file)

  res <- run_pkg_convert(root, dirs = c("R", "tests"))

  expect_equal(readLines(test_file, warn = FALSE), "y |> identity()")
  expect_equal(
    readLines(file.path(root, "R", "a.R"), warn = FALSE),
    "x |> identity()"
  )
  expect_summary(res$messages, n = 2L, updated = 2L)
})

test_that("package_convert_pipe picks up .R and .r files", {
  root <- make_test_pkg()
  writeLines("x %>% identity()", file.path(root, "R", "a.R"))
  writeLines("y %>% identity()", file.path(root, "R", "b.r"))

  res <- run_pkg_convert(root)

  expect_equal(readLines(file.path(root, "R", "a.R"), warn = FALSE), "x |> identity()")
  expect_equal(readLines(file.path(root, "R", "b.r"), warn = FALSE), "y |> identity()")
  expect_summary(res$messages, n = 2L, updated = 2L)
})

test_that("package_convert_pipe only reports files that changed", {
  root <- make_test_pkg()
  unchanged <- file.path(root, "R", "unchanged.R")
  changed <- file.path(root, "R", "changed.R")
  writeLines("x |> identity()", unchanged)
  writeLines("y %>% identity()", changed)

  res <- run_pkg_convert(root)

  expect_equal(readLines(unchanged, warn = FALSE), "x |> identity()")
  expect_equal(readLines(changed, warn = FALSE), "y |> identity()")
  expect_true(res$value)
  expect_summary(res$messages, n = 2L, updated = 1L)
})

test_that("package_convert_pipe returns FALSE when nothing is rewritten", {
  root <- make_test_pkg()
  writeLines("x |> identity()", file.path(root, "R", "a.R"))

  res <- run_pkg_convert(root)

  expect_false(res$value)
  expect_summary(res$messages, n = 1L, updated = 0L)
})

test_that("package_convert_pipe is idempotent", {
  root <- make_test_pkg()
  writeLines("x %>% identity() %>% identity()", file.path(root, "R", "a.R"))

  first <- run_pkg_convert(root)
  second <- run_pkg_convert(root)

  expect_true(first$value)
  expect_false(second$value)
  expect_summary(first$messages, n = 1L, updated = 1L)
  expect_summary(second$messages, n = 1L, updated = 0L)
  expect_equal(
    readLines(file.path(root, "R", "a.R"), warn = FALSE),
    "x |> identity() |> identity()"
  )
})

test_that("package_convert_pipe skips missing directories", {
  root <- make_test_pkg()
  unlink(file.path(root, "tests"), recursive = TRUE)
  writeLines("x %>% identity()", file.path(root, "R", "a.R"))

  res <- run_pkg_convert(root, dirs = c("R", "tests"))

  expect_equal(readLines(file.path(root, "R", "a.R"), warn = FALSE), "x |> identity()")
  expect_summary(res$messages, n = 1L, updated = 1L)
})

test_that("package_convert_pipe respects a custom `dirs` argument", {
  root <- make_test_pkg()
  writeLines("x %>% identity()", file.path(root, "R", "a.R"))
  extra <- file.path(root, "extra")
  dir.create(extra)
  writeLines("y %>% identity()", file.path(extra, "b.R"))

  res <- run_pkg_convert(root, dirs = "extra")

  expect_equal(readLines(file.path(extra, "b.R"), warn = FALSE), "y |> identity()")
  expect_equal(
    readLines(file.path(root, "R", "a.R"), warn = FALSE),
    "x %>% identity()"
  )
  expect_summary(res$messages, n = 1L, updated = 1L)
})

test_that("package_convert_pipe respects recursive = FALSE", {
  root <- make_test_pkg()
  dir.create(file.path(root, "R", "sub"))
  writeLines("x %>% identity()", file.path(root, "R", "top.R"))
  writeLines("y %>% identity()", file.path(root, "R", "sub", "nested.R"))

  res <- run_pkg_convert(root, recursive = FALSE)

  expect_equal(readLines(file.path(root, "R", "top.R"), warn = FALSE), "x |> identity()")
  expect_equal(
    readLines(file.path(root, "R", "sub", "nested.R"), warn = FALSE),
    "y %>% identity()"
  )
  expect_summary(res$messages, n = 1L, updated = 1L)
})

test_that("package_convert_pipe recurses by default", {
  root <- make_test_pkg()
  dir.create(file.path(root, "R", "sub"))
  writeLines("y %>% identity()", file.path(root, "R", "sub", "nested.R"))

  res <- run_pkg_convert(root)

  expect_equal(
    readLines(file.path(root, "R", "sub", "nested.R"), warn = FALSE),
    "y |> identity()"
  )
  expect_summary(res$messages, n = 1L, updated = 1L)
})

test_that("package_convert_pipe reports the empty case when dirs do not exist", {
  root <- make_test_pkg()
  unlink(file.path(root, "R"), recursive = TRUE)

  res <- run_pkg_convert(root)

  expect_false(res$value)
  expect_match(res$messages, "No R files found", fixed = TRUE)
})

test_that("package_convert_pipe returns FALSE with a message when no R files", {
  root <- make_test_pkg()

  expect_message(
    result <- package_convert_pipe(root),
    "No R files found"
  )
  expect_false(result)
})

test_that("package_convert_pipe accepts a relative path", {
  root <- make_test_pkg()
  writeLines("x %>% identity()", file.path(root, "R", "a.R"))

  withr::local_dir(root)
  res <- run_pkg_convert(".")

  expect_true(res$value)
  expect_summary(res$messages, n = 1L, updated = 1L)
  expect_equal(readLines(file.path(root, "R", "a.R"), warn = FALSE), "x |> identity()")
})

test_that("package_convert_pipe defaults path to '.'", {
  root <- make_test_pkg()
  writeLines("x %>% identity()", file.path(root, "R", "a.R"))

  withr::local_dir(root)
  res <- run_pkg_convert()

  expect_true(res$value)
  expect_summary(res$messages, n = 1L, updated = 1L)
})

test_that("package_convert_pipe rejects a working directory that is not a package", {
  withr::local_dir(withr::local_tempdir())

  expect_error(package_convert_pipe(), "does not look like an R package root")
})
