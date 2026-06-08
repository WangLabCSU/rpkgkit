test_that("generate_color_code returns a braced expression", {
  code <- rpkgkit:::generate_color_code()
  expect_true(inherits(code, "{"))
})

test_that("generate_color_code expression contains cli_div call", {
  code <- rpkgkit:::generate_color_code()

  code_text <- deparse(code)
  expect_true(any(grepl("cli::cli_div", code_text)))
})

test_that("generate_color_code expression contains on.exit for cleanup", {
  code <- rpkgkit:::generate_color_code()

  code_text <- deparse(code)
  expect_true(any(grepl("on.exit", code_text)))
  expect_true(any(grepl("cli::cli_end", code_text)))
})

test_that("generate_color_code expression includes span color definitions", {
  code <- rpkgkit:::generate_color_code()

  code_text <- deparse(code)
  expect_true(any(grepl("span.red", code_text)))
  expect_true(any(grepl('"red"', code_text)))
  expect_true(any(grepl("span.blue", code_text)))
  expect_true(any(grepl("span.green", code_text)))
})
