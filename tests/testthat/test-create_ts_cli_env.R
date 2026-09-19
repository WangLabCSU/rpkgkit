test_that("create_ts_cli_env returns an environment", {
  env <- rpkgkit:::create_ts_cli_env("cli_alert_info")
  expect_type(env, "environment")
})

test_that("create_ts_cli_env with default list contains all 4 functions", {
  env <- rpkgkit:::create_ts_cli_env()
  expected <- c(
    "cli_alert_info",
    "cli_alert_success",
    "cli_alert_warning",
    "cli_alert_danger"
  )
  expect_true(all(expected %in% ls(env)))
})

test_that("create_ts_cli_env with custom list only contains requested functions", {
  env <- rpkgkit:::create_ts_cli_env(c("cli_alert_info", "cli_alert_danger"))
  expect_true("cli_alert_info" %in% ls(env))
  expect_true("cli_alert_danger" %in% ls(env))
  expect_false("cli_alert_success" %in% ls(env))
})

test_that("create_ts_cli_env with empty character vector returns empty env", {
  env <- rpkgkit:::create_ts_cli_env(character(0L))
  expect_length(ls(env), 0L)
})
