test_that("colorful_cli works", {
  clr_cli <- create_colorful_cli_env()

  clr_cli$cli_alert_info("{.red This is a red alert.}")

  cli_cyan_h1 <- add_colors_to_cli(cli::cli_h1)

  cli_cyan_h1("{.cyan This is a cyan header}")

  code <- generate_color_code()
  expect_equal(class(code), "{")
})
