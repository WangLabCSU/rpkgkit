test_that("generate_color_code returns a braced expression", {
  code <- rpkgkit:::generate_color_code()
  expect_equal(class(code), "{")
})
