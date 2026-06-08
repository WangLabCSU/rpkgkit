# Tests for generate_color_theme() from standalone-colorful_cli.R

test_that("generate_color_theme returns a list", {
  theme <- rpkgkit:::generate_color_theme()
  expect_type(theme, "list")
})

test_that("generate_color_theme returns a large list (all R color names)", {
  theme <- rpkgkit:::generate_color_theme()
  # R has 657 built-in color names
  expect_gt(length(theme), 600)
})

test_that("generate_color_theme names follow span.<color> pattern", {
  theme <- rpkgkit:::generate_color_theme()
  nms <- names(theme)

  # All names should start with "span."
  expect_true(all(grepl("^span\\.", nms)))
})

test_that("generate_color_theme each element is list(color = <color>)", {
  theme <- rpkgkit:::generate_color_theme()

  # Spot check first few elements
  for (name in names(theme)[1:5]) {
    el <- theme[[name]]
    expect_type(el, "list")
    expect_named(el, "color")
    expect_type(el$color, "character")
    expect_equal(el$color, sub("^span\\.", "", name))
  }
})

test_that("generate_color_theme includes well-known colors", {
  theme <- rpkgkit:::generate_color_theme()

  expect_true("span.red" %in% names(theme))
  expect_true("span.blue" %in% names(theme))
  expect_true("span.green" %in% names(theme))
  expect_true("span.yellow" %in% names(theme))
  expect_true("span.black" %in% names(theme))
  expect_true("span.white" %in% names(theme))
})

test_that("generate_color_theme maps span.<name> to color = <name>", {
  theme <- rpkgkit:::generate_color_theme()

  expect_equal(theme$span.red$color, "red")
  expect_equal(theme$span.tomato$color, "tomato")
  expect_equal(theme$span.steelblue$color, "steelblue")
})

test_that("generate_color_theme is usable with add_colors_to_cli", {
  theme <- rpkgkit:::generate_color_theme()

  decorated <- rpkgkit:::add_colors_to_cli(
    cli::cli_alert_info,
    cli_theme = theme
  )

  # Should work with a color from the full theme
  expect_no_error(
    suppressMessages(decorated("{.tomato Tomato colored text}"))
  )
})

test_that("generate_color_theme returns consistent names for each call", {
  theme1 <- rpkgkit:::generate_color_theme()
  theme2 <- rpkgkit:::generate_color_theme()

  expect_equal(names(theme1), names(theme2))
})
