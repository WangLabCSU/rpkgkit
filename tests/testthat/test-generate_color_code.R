test_that("generate_color_code returns a braced expression", {
  code <- rpkgkit:::generate_color_code()
  expect_equal(class(code), "{")
})

test_that("generate_color_code contains cli::cli_div call", {
  code <- rpkgkit:::generate_color_code()
  cli_div_call <- code[[2L]]
  expect_equal(deparse(cli_div_call[[1L]]), "cli::cli_div")
})

test_that("generate_color_code has correct span colors", {
  code <- rpkgkit:::generate_color_code()
  cli_div_call <- code[[2L]]

  expected <- list(
    "span.red" = "red",
    "span.blue" = "blue",
    "span.orange" = "orange",
    "span.purple" = "purple",
    "span.green" = "green",
    "span.magenta" = "magenta",
    "span.cyan" = "cyan"
  )

  args <- as.list(cli_div_call)[-1L]
  for (nm in names(expected)) {
    expect_true(nm %in% names(args), info = paste("Missing:", nm))
    expect_equal(
      args[[nm]]$color,
      expected[[nm]],
      info = paste("Wrong color:", nm)
    )
  }
})
