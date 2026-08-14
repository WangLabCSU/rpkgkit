test_that("add_double_colons leaves comments and roxygen2 untouched", {
  code <- paste0(
    "x <- filter(mpg > 20)\n",
    "# filter(mpg > 20)\n",
    "y <- acf(ts) # filter(x)\n",
    "#' @examples\n",
    "#' ar(1)\n",
    "w <- \"a#b\"\n"
  )
  out <- add_double_colons(code, use_packages = "stats")

  expect_match(out, "x <- stats::filter(mpg > 20)", fixed = TRUE)
  # Comment lines are not modified
  expect_match(out, "# filter(mpg > 20)", fixed = TRUE)
  # Trailing comments are not modified
  expect_match(out, "y <- stats::acf(ts) # filter(x)", fixed = TRUE)
  # roxygen2 lines are not modified
  expect_match(out, "#' @examples", fixed = TRUE)
  expect_match(out, "#' ar(1)", fixed = TRUE)
  # `#` inside a string literal is not treated as a comment
  expect_match(out, "w <- \"a#b\"", fixed = TRUE)
})

test_that("add_double_colons leaves no placeholders in output", {
  code <- "# filter(x)\n# mutate(y)\nz <- filter(a)"
  out <- add_double_colons(code, use_packages = "stats")

  expect_false(grepl("RCOMMENT_", out, fixed = TRUE))
  expect_match(out, "z <- stats::filter(a)", fixed = TRUE)
})

test_that("add_double_colons protects comment inside backticks", {
  # A `#` inside a backtick identifier is not a comment
  code <- paste0("`a#b` <- filter(x)  # comment with filter(z)\n")
  out <- add_double_colons(code, use_packages = "stats")

  expect_match(out, "`a#b` <- stats::filter(x)", fixed = TRUE)
  expect_match(out, "# comment with filter(z)", fixed = TRUE)
})

test_that("add_double_colons handles code with only comments", {
  code <- "# filter(x)\n#' summarise(mtcars)\n"
  out <- add_double_colons(code, use_packages = "stats")

  expect_equal(out, code)
})
