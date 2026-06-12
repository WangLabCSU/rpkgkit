test_that("create_colorful_cli_env returns an environment", {
  env <- rpkgkit:::create_colorful_cli_env("cli_alert_info")
  expect_type(env, "environment")
})

test_that("create_colorful_cli_env with default list contains all 4 functions", {
  env <- rpkgkit:::create_colorful_cli_env()
  expected <- c(
    "cli_alert_info",
    "cli_alert_success",
    "cli_alert_warning",
    "cli_alert_danger"
  )
  expect_true(all(expected %in% ls(env)))
})

test_that("create_colorful_cli_env with custom list only contains requested functions", {
  env <- rpkgkit:::create_colorful_cli_env(c(
    "cli_alert_info",
    "cli_alert_danger"
  ))
  expect_true("cli_alert_info" %in% ls(env))
  expect_true("cli_alert_danger" %in% ls(env))
  expect_false("cli_alert_success" %in% ls(env))
})

test_that("create_colorful_cli_env with empty character vector returns empty env", {
  env <- rpkgkit:::create_colorful_cli_env(character(0))
  expect_length(ls(env), 0L)
})

test_that("create_colorful_cli_env returned functions are callable", {
  env <- rpkgkit:::create_colorful_cli_env(c(
    "cli_alert_info",
    "cli_alert_success"
  ))

  expect_type(env$cli_alert_info, "closure")
  expect_type(env$cli_alert_success, "closure")

  expect_no_error(
    suppressMessages(env$cli_alert_info("{.blue Hello from the env}"))
  )
  expect_no_error(
    suppressMessages(env$cli_alert_success("{.green Success from the env}"))
  )
})
