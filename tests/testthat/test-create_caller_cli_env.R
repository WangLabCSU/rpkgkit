test_that("create_caller_cli_env returns an environment", {
  env <- rpkgkit:::create_caller_cli_env("cli_alert_info")
  expect_type(env, "environment")
})

test_that("create_caller_cli_env with default list contains all 5 functions", {
  env <- rpkgkit:::create_caller_cli_env()
  expected <- c(
    "cli_alert_info",
    "cli_alert_success",
    "cli_alert_warning",
    "cli_alert_danger",
    "cli_inform"
  )
  expect_true(all(expected %in% ls(env)))
})

test_that("create_caller_cli_env with custom list only contains requested functions", {
  env <- rpkgkit:::create_caller_cli_env(c("cli_alert_info", "cli_inform"))
  expect_true("cli_alert_info" %in% ls(env))
  expect_true("cli_inform" %in% ls(env))
  expect_false("cli_alert_success" %in% ls(env))
})

test_that("create_caller_cli_env wraps functions to prepend caller prefix", {
  captured_func <- NULL
  local_mocked_bindings(
    exists = function(x, envir) TRUE,
    .package = "base"
  )
  local_mocked_bindings(
    get0 = function(x, envir) function(...) cat("[original cli]: ", ..., "\n"),
    .package = "base"
  )
  local_mocked_bindings(
    add_caller_to_cli = function(cli_func, offset) {
      captured_func <<- cli_func
      function(...) cli_func(paste0("[wrapped]: ", ..1))
    },
    .package = "rpkgkit"
  )

  env <- rpkgkit:::create_caller_cli_env("cli_alert_info")
  expect_true("cli_alert_info" %in% ls(env))
})

test_that("create_caller_cli_env with empty character vector returns empty env", {
  env <- rpkgkit:::create_caller_cli_env(character(0L))
  expect_length(ls(env), 0L)
})

test_that("create_caller_cli_env passes offset = 2L to add_caller_to_cli", {
  captured_offset <- NULL
  local_mocked_bindings(
    add_caller_to_cli = function(cli_func, offset) {
      captured_offset <<- offset
      function(...) cli_func(...)
    },
    .package = "rpkgkit"
  )

  rpkgkit:::create_caller_cli_env("cli_alert_info")
  expect_equal(captured_offset, 2L)
})
