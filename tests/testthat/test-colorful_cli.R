test_that("colorful_cli works", {
  clr_cli <- create_colorful_cli_env()

  clr_cli$cli_alert_info("{.red This is a red alert.}")

  cli_cyan_h1 <- add_colors_to_cli(cli::cli_h1)

  cli_cyan_h1("{.cyan This is a cyan header}")

  code <- generate_color_code()
  expect_equal(class(code), "{")
})

test_that("combined cli env works", {
  powered_cli_alert_success <- add_colors_to_cli(add_timestamp_to_cli(
    cli::cli_alert_success
  ))

  # The timestamp must still be resolvable when the color wrapper forwards
  # `.envir` down to the timestamp wrapper
  msg <- NULL
  withCallingHandlers(
    powered_cli_alert_success("{.red This is a red alert.}"),
    message = function(m) {
      msg <<- conditionMessage(m)
      invokeRestart("muffleMessage")
    }
  )

  expect_match(msg, "\\[\\d{4}/\\d{2}/\\d{2} \\d{2}:\\d{2}:\\d{2}\\]")
  expect_match(msg, "This is a red alert")

  cli_cyan_h1 <- add_colors_to_cli(add_timestamp_to_cli(cli::cli_h1))

  expect_message(cli_cyan_h1("{.cyan This is a cyan header}"), "cyan header")
})
