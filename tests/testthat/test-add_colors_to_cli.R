# Tests for add_colors_to_cli() from standalone-colorful_cli.R

test_that("add_colors_to_cli returns a function", {
  decorated <- rpkgkit:::add_colors_to_cli(cli::cli_alert_info)
  expect_type(decorated, "closure")
  expect_true(is.function(decorated))
})

test_that("add_colors_to_cli returned function does not error with simple input", {
  decorated <- rpkgkit:::add_colors_to_cli(cli::cli_alert_success)

  expect_no_error(
    suppressMessages(decorated("Test message"))
  )
})

test_that("add_colors_to_cli returned function accepts inline span tags", {
  decorated <- rpkgkit:::add_colors_to_cli(cli::cli_alert_warning)

  expect_no_error(
    suppressMessages(decorated("{.red Warning} {.blue detail}"))
  )
})

test_that("add_colors_to_cli returned function forwards multiple arguments", {
  decorated <- rpkgkit:::add_colors_to_cli(cli::cli_alert_info)

  expect_no_error(
    suppressMessages(decorated("First", "Second", "Third"))
  )
})

test_that("add_colors_to_cli works with custom cli_theme", {
  custom_theme <- list(
    span.custom = list(color = "darkgreen"),
    span.highlight = list(color = "gold")
  )

  decorated <- rpkgkit:::add_colors_to_cli(
    cli::cli_alert_info,
    cli_theme = custom_theme
  )

  expect_no_error(
    suppressMessages(decorated("{.custom Test} message"))
  )
})

test_that("add_colors_to_cli works with cli_h1", {
  decorated <- rpkgkit:::add_colors_to_cli(cli::cli_h1)

  expect_no_error(
    suppressMessages(decorated("A colorful header"))
  )
})

test_that("add_colors_to_cli works with cli_text", {
  decorated <- rpkgkit:::add_colors_to_cli(cli::cli_text)

  expect_no_error(
    suppressMessages(decorated("{.red Colored} text output"))
  )
})

test_that("add_colors_to_cli applies default theme when no theme provided", {
  decorated <- rpkgkit:::add_colors_to_cli(cli::cli_alert_info)

  # Should work with a color from the default theme
  expect_no_error(
    suppressMessages(decorated("{.blue Blue message}"))
  )
})
