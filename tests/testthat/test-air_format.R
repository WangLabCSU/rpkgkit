# Tests for air_format() and check_air_installed() from 10_air_format.R
# Existing tests for check_air_installed are in test-check_air_installed.R

test_that("air_format calls system2 with air format and the given path", {
  local_mocked_bindings(
    check_air_installed = function() invisible(TRUE)
  )

  captured_cmd <- NULL
  captured_args <- NULL
  local_mocked_bindings(
    system2 = function(command, args, ...) {
      captured_cmd <<- command
      captured_args <<- args
      invisible(0)
    },
    .package = "base"
  )

  air_format(path = "test.R")

  expect_equal(captured_cmd, "air")
  expect_equal(captured_args, c("format", "test.R"))
})

test_that("air_format passes additional arguments to system2 via ...", {
  local_mocked_bindings(
    check_air_installed = function() invisible(TRUE)
  )

  captured_dots <- NULL
  local_mocked_bindings(
    system2 = function(command, args, ...) {
      captured_dots <<- list(...)
      invisible(0)
    },
    .package = "base"
  )

  air_format(path = "test.R", stdout = FALSE, stderr = FALSE)

  expect_false(captured_dots$stdout)
  expect_false(captured_dots$stderr)
})

test_that("air_format returns exit status invisibly", {
  local_mocked_bindings(
    check_air_installed = function() invisible(TRUE)
  )
  local_mocked_bindings(
    system2 = function(command, args, ...) invisible(0),
    .package = "base"
  )

  result <- air_format(path = "test.R")
  expect_equal(result, 0)
})

test_that("air_format aborts when path is NULL and rstudioapi is not installed", {
  local_mocked_bindings(
    check_air_installed = function() invisible(TRUE)
  )
  local_mocked_bindings(
    is_installed = function(pkg) FALSE,
    .package = "rlang"
  )

  expect_error(
    air_format(),
    "path.*is required"
  )
})

test_that("air_format uses rstudioapi when path is NULL and rstudioapi is available", {
  local_mocked_bindings(
    check_air_installed = function() invisible(TRUE)
  )
  local_mocked_bindings(
    is_installed = function(pkg) pkg == "rstudioapi",
    .package = "rlang"
  )
  local_mocked_bindings(
    getActiveDocumentContext = function() list(path = "/home/user/active.R"),
    .package = "rstudioapi"
  )

  captured_args <- NULL
  local_mocked_bindings(
    system2 = function(command, args, ...) {
      captured_args <<- args
      invisible(0)
    },
    .package = "base"
  )

  air_format()

  expect_equal(captured_args, c("format", "/home/user/active.R"))
})

test_that("air_format calls check_air_installed before proceeding", {
  called <- FALSE
  local_mocked_bindings(
    check_air_installed = function() {
      called <<- TRUE
      invisible(TRUE)
    }
  )
  local_mocked_bindings(
    system2 = function(command, args, ...) invisible(0),
    .package = "base"
  )

  air_format(path = "test.R")
  expect_true(called)
})

test_that("air_format propagates check_air_installed error", {
  local_mocked_bindings(
    check_air_installed = function() cli::cli_abort("air not found")
  )

  expect_error(
    air_format(path = "test.R"),
    "air not found"
  )
})
