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

test_that("add_double_colons keeps digits inside function names", {
  # Regression: `syntactic_fns` used to exclude digits, so an identifier was
  # silently truncated to its longest digit-free suffix (`r2dtable` -> `dtable`).
  out <- add_double_colons("r2d <- r2dtable(1)", use_packages = "stats")

  expect_match(out, "stats::r2dtable(1)", fixed = TRUE)
  # `stats::dtable(` must never appear (truncation would produce `stats::dtable`)
  expect_false(grepl("stats::dtable(", out, fixed = TRUE))
})

test_that("add_double_colons keeps digits in function names from other packages", {
  skip_if_not_installed("ggplot2")

  out <- add_double_colons(
    "p <- ggplot(mtcars, aes(x = wt)) + geom_point() + scale_x_log10()",
    use_packages = "ggplot2"
  )

  expect_match(out, "ggplot2::scale_x_log10()", fixed = TRUE)
  expect_match(out, "ggplot2::ggplot(mtcars", fixed = TRUE)
})

test_that("add_double_colons resolves names with digits to the right package", {
  # `r2dtable()` lives in stats; before the fix the truncated `dtable()` could
  # not be resolved and triggered a "Couldn't find packages exporting" warning.
  expect_warning(
    out <- add_double_colons("r2d <- r2dtable(1)", use_packages = "stats"),
    NA
  )
  expect_match(out, "stats::r2dtable(1)", fixed = TRUE)
})

test_that("add_double_colons does not truncate names with trailing digits", {
  # `abc2()` / `foo1bar()` still resolve when they are the whole identifier;
  # they are unknown to stats, so they must be reported verbatim (and warned
  # about), never truncated to `2()` / `bar()`.
  expect_warning(
    out <- add_double_colons("abc2(1)\nfoo1bar(1)", use_packages = "stats"),
    "Couldn't find packages exporting 2 function"
  )
  expect_match(out, "abc2(1)", fixed = TRUE)
  expect_match(out, "foo1bar(1)", fixed = TRUE)
  expect_false(grepl("stats::2(1)", out, fixed = TRUE))
  expect_false(grepl("stats::bar(1)", out, fixed = TRUE))
})
