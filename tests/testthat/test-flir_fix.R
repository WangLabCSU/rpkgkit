test_that("flir_fix aborts when flir is not installed", {
  local_mocked_bindings(
    check_installed = function(...) cli::cli_abort("not installed"),
    .package = "rlang"
  )
  expect_error(flir_fix("some_file.R"), "not installed")
})

test_that("flir_fix uses rstudioapi to get path when path is NULL", {
  tmp <- tempfile("flir_test", fileext = ".R")
  writeLines("x <- 1", tmp)
  on.exit(unlink(tmp))

  local_mocked_bindings(
    check_installed = function(...) invisible(),
    .package = "rlang"
  )
  local_mocked_bindings(
    getActiveDocumentContext = function() list(path = tmp),
    .package = "rstudioapi"
  )

  captured <- NULL
  local_mocked_bindings(
    fix = function(path, ...) {
      captured <<- path
      invisible(path)
    },
    .package = "flir"
  )

  flir_fix(path = NULL)
  expect_equal(captured, tmp)
})

test_that("flir_fix calls flir::fix when path is a file", {
  tmp <- tempfile("flir_test", fileext = ".R")
  writeLines("x <- 1", tmp)
  on.exit(unlink(tmp))

  local_mocked_bindings(
    check_installed = function(...) invisible(),
    .package = "rlang"
  )

  captured <- NULL
  local_mocked_bindings(
    fix = function(path, ...) {
      captured <<- path
      invisible(path)
    },
    .package = "flir"
  )

  result <- flir_fix(path = tmp)
  expect_equal(captured, tmp)
})

test_that("flir_fix calls flir::fix_package when path is a package directory", {
  path <- tempfile("flir_pkg")

  local_mocked_bindings(
    check_installed = function(...) invisible(),
    .package = "rlang"
  )
  local_mocked_bindings(
    file.exists = function(x) FALSE,
    .package = "base"
  )
  local_mocked_bindings(
    dir.exists = function(x) TRUE,
    .package = "base"
  )
  local_mocked_bindings(
    is_pkg = function(path) TRUE,
    .package = "rpkgkit"
  )

  captured <- NULL
  local_mocked_bindings(
    fix_package = function(path, ...) {
      captured <<- path
      invisible(path)
    },
    .package = "flir"
  )

  flir_fix(path = path)
  expect_equal(captured, path)
})

test_that("flir_fix calls flir::fix_dir when path is a directory but not a package", {
  path <- tempfile("flir_dir")

  local_mocked_bindings(
    check_installed = function(...) invisible(),
    .package = "rlang"
  )
  local_mocked_bindings(
    file.exists = function(x) FALSE,
    .package = "base"
  )
  local_mocked_bindings(
    dir.exists = function(x) TRUE,
    .package = "base"
  )
  local_mocked_bindings(
    is_pkg = function(path) FALSE,
    .package = "rpkgkit"
  )

  captured <- NULL
  local_mocked_bindings(
    fix_dir = function(path, ...) {
      captured <<- path
      invisible(path)
    },
    .package = "flir"
  )

  flir_fix(path = path)
  expect_equal(captured, path)
})

test_that("flir_fix returns invisible NULL when path does not match any condition", {
  local_mocked_bindings(
    check_installed = function(...) invisible(),
    .package = "rlang"
  )
  local_mocked_bindings(
    is_pkg = function(path) FALSE,
    .package = "rpkgkit"
  )

  result <- flir_fix(path = "/nonexistent/path/for/testing/file.R")
  expect_null(result)
})

test_that("flir_fix forwards extra arguments via ... to flir functions", {
  tmp <- tempfile("flir_test", fileext = ".R")
  writeLines("x <- 1", tmp)
  on.exit(unlink(tmp))

  local_mocked_bindings(
    check_installed = function(...) invisible(),
    .package = "rlang"
  )

  captured_args <- NULL
  local_mocked_bindings(
    fix = function(path, ...) {
      captured_args <<- list(...)
      invisible(path)
    },
    .package = "flir"
  )

  flir_fix(path = tmp, linter = "my_linter", auto_correct = TRUE)
  expect_equal(captured_args$linter, "my_linter")
  expect_true(captured_args$auto_correct)
})
