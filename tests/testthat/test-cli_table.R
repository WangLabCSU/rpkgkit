# Tests for standalone-cli_table.R
# Internal helpers: cli_table(), cli_table_oneline(), .cli_pad(), .cli_render()
#
# cli::cli_verbatim() signals a "cliMessage" condition, so it is captured with
# capture.output(type = "message"). ANSI styling is turned off with
# cli.num_colors = 1 so the expected strings can be compared literally.

capture_cli <- function(expr) {
  capture.output(expr, type = "message")
}

# ── .cli_render ──────────────────────────────────────────────────────────────

test_that(".cli_render returns the value unstyled when fmt is NULL", {
  withr::local_options(cli.num_colors = 1L)

  expect_identical(rpkgkit:::.cli_render("a", NULL), "a")
  expect_identical(rpkgkit:::.cli_render(1, NULL), "1")
  expect_identical(rpkgkit:::.cli_render(12.5, NULL), "12.5")
})

test_that(".cli_render treats an empty fmt like NULL", {
  withr::local_options(cli.num_colors = 1L)

  expect_identical(rpkgkit:::.cli_render("a", ""), "a")
})

test_that(".cli_render accepts fmt with and without the leading dot", {
  withr::local_options(cli.num_colors = 1L)

  expect_identical(
    rpkgkit:::.cli_render("a", ".field"),
    rpkgkit:::.cli_render("a", "field")
  )
  expect_identical(
    rpkgkit:::.cli_render("a", ".val"),
    rpkgkit:::.cli_render("a", "val")
  )
})

test_that(".cli_render supports each documented inline class", {
  withr::local_options(cli.num_colors = 1L)

  for (fmt in c(".val", ".field", ".emph", ".strong", ".code", ".cls")) {
    expect_no_error(rpkgkit:::.cli_render("a", fmt))
    expect_true(nzchar(rpkgkit:::.cli_render("a", fmt)))
  }
})

test_that(".cli_render passes brace-containing values through untouched", {
  withr::local_options(cli.num_colors = 1L)

  expect_identical(rpkgkit:::.cli_render("{a}", NULL), "{a}")
  expect_identical(rpkgkit:::.cli_render("{a}", ".field"), "{a}")
})

test_that(".cli_render applies ANSI styling when colours are enabled", {
  withr::local_options(cli.num_colors = 8L)

  styled <- rpkgkit:::.cli_render("a", ".strong")

  expect_true(cli::ansi_has_any(styled))
  expect_equal(cli::ansi_nchar(styled, type = "width"), 1L)
})

# ── .cli_pad ─────────────────────────────────────────────────────────────────

test_that(".cli_pad pads on the right by default", {
  expect_identical(rpkgkit:::.cli_pad(c("a", "bb"), c(3L, 3L)), c("a  ", "bb "))
})

test_that(".cli_pad pads on the left with how = 'right'", {
  expect_identical(
    rpkgkit:::.cli_pad(c("a", "bb"), c(3L, 3L), "right"),
    c("  a", " bb")
  )
})

test_that(".cli_pad centres the text with how = 'center'", {
  expect_identical(
    rpkgkit:::.cli_pad(c("a", "bbb"), c(3L, 3L), "center"),
    c(" a ", "bbb")
  )
})

test_that(".cli_pad leaves text that already fills the column untouched", {
  expect_identical(rpkgkit:::.cli_pad("abc", 3L), "abc")
  expect_identical(rpkgkit:::.cli_pad("abc", 3L, "right"), "abc")
  expect_identical(rpkgkit:::.cli_pad("abc", 3L, "center"), "abc")
})

test_that(".cli_pad pads every element to its own width", {
  pad <- rpkgkit:::.cli_pad(c("a", "bb", "ccc"), c(1L, 3L, 5L), "right")

  expect_identical(nchar(pad), c(1L, 3L, 5L))
  expect_identical(pad, c("a", " bb", "  ccc"))
})

test_that(".cli_pad ignores an unknown alignment and returns the text as is", {
  # switch() has no default, so `how` falls through to NULL and nothing is padded
  expect_identical(rpkgkit:::.cli_pad("a", 5L, "bogus"), "a")
})

# ── cli_table ────────────────────────────────────────────────────────────────

test_that("cli_table returns the underlying table invisibly", {
  withr::local_options(cli.num_colors = 1L)

  out <- capture_cli(res <- withVisible(rpkgkit:::cli_table(c("a", "a", "b"))))

  expect_false(res$visible)
  expect_s3_class(res$value, "table")
  # dnn = "x" because the table is built from the argument named `x`
  expect_identical(res$value, table(c("a", "a", "b"), dnn = "x"))
  expect_length(out, 2L)
})

test_that("cli_table prints headers then counts, right-aligned by default", {
  withr::local_options(cli.num_colors = 1L)

  expect_identical(
    capture_cli(rpkgkit:::cli_table(c("a", "a", "b"))),
    c("a  b", "2  1")
  )
})

test_that("cli_table aligns counts within the wider of header and count", {
  withr::local_options(cli.num_colors = 1L)

  expect_identical(
    capture_cli(rpkgkit:::cli_table(c("a", "bbbb"))),
    c("a  bbbb", "1     1")
  )
})

test_that("cli_table honours align = 'left'", {
  withr::local_options(cli.num_colors = 1L)

  expect_identical(
    capture_cli(rpkgkit:::cli_table(c("a", "bbbb"), align = "left")),
    c("a  bbbb", "1  1   ")
  )
})

test_that("cli_table honours align = 'center'", {
  withr::local_options(cli.num_colors = 1L)

  expect_identical(
    capture_cli(rpkgkit:::cli_table(c("a", "bbbb"), align = "center")),
    c("a  bbbb", "1   1  ")
  )
})

test_that("cli_table matches align partially", {
  withr::local_options(cli.num_colors = 1L)

  expect_identical(
    capture_cli(rpkgkit:::cli_table(c("a", "bbbb"), align = "cen")),
    c("a  bbbb", "1   1  ")
  )
})

test_that("cli_table rejects an unknown align value", {
  withr::local_options(cli.num_colors = 1L)

  expect_error(
    rpkgkit:::cli_table(c("a"), align = "middle"),
    "should be one of"
  )
})

test_that("cli_table puts sep spaces between the columns", {
  withr::local_options(cli.num_colors = 1L)

  expect_identical(
    capture_cli(rpkgkit:::cli_table(c("a", "a", "b"), sep = 4L)),
    c("a    b", "2    1")
  )
  # sep = 0L glues the columns together
  expect_identical(
    capture_cli(rpkgkit:::cli_table(c("a", "b"), sep = 0L)),
    c("ab", "11")
  )
})

test_that("cli_table counts missing values by default and labels them NA", {
  withr::local_options(cli.num_colors = 1L)

  expect_identical(
    capture_cli(rpkgkit:::cli_table(c("a", NA))),
    c("a  NA", "1   1")
  )
})

test_that("cli_table drops missing values with useNA = 'no'", {
  withr::local_options(cli.num_colors = 1L)

  expect_identical(
    capture_cli(rpkgkit:::cli_table(c("a", NA), useNA = "no")),
    c("a", "1")
  )
})

test_that("cli_table always shows the NA column with useNA = 'always'", {
  withr::local_options(cli.num_colors = 1L)

  expect_identical(
    capture_cli(rpkgkit:::cli_table(c("a", "b"), useNA = "always")),
    c("a  b  NA", "1  1   0")
  )
})

test_that("cli_table renders headers and counts without styling when asked", {
  withr::local_options(cli.num_colors = 1L)

  expect_identical(
    capture_cli(rpkgkit:::cli_table(
      c("a", "a", "b"),
      head_format = NULL,
      count_format = NULL
    )),
    c("a  b", "2  1")
  )
})

test_that("cli_table applies inline classes to both lines", {
  withr::local_options(cli.num_colors = 8L)

  out <- capture_cli(rpkgkit:::cli_table(
    c("a", "a", "b"),
    head_format = ".strong",
    count_format = ".emph"
  ))

  expect_length(out, 2L)
  expect_true(all(vapply(out, cli::ansi_has_any, logical(1L))))
})

test_that("cli_table accepts inline classes without the leading dot", {
  withr::local_options(cli.num_colors = 8L)

  dotted <- capture_cli(rpkgkit:::cli_table(
    c("a", "a", "b"),
    head_format = ".strong",
    count_format = ".emph"
  ))
  undotted <- capture_cli(rpkgkit:::cli_table(
    c("a", "a", "b"),
    head_format = "strong",
    count_format = "emph"
  ))

  expect_identical(undotted, dotted)
})

test_that("cli_table works with factors and numeric input", {
  withr::local_options(cli.num_colors = 1L)

  expect_identical(
    capture_cli(rpkgkit:::cli_table(factor(c("x", "y", "x")))),
    c("x  y", "2  1")
  )
  expect_identical(
    capture_cli(rpkgkit:::cli_table(c(1, 1, 2.5))),
    c("1  2.5", "2    1")
  )
})

test_that("cli_table emits two empty lines for empty input", {
  withr::local_options(cli.num_colors = 1L)

  out <- capture_cli(res <- withVisible(rpkgkit:::cli_table(character(0))))

  expect_false(res$visible)
  expect_identical(out, c("", ""))
})

# ── cli_table_oneline ────────────────────────────────────────────────────────

test_that("cli_table_oneline returns the underlying table invisibly", {
  withr::local_options(cli.num_colors = 1L)

  out <- capture_cli(
    res <- withVisible(rpkgkit:::cli_table_oneline(c("a", "b")))
  )

  expect_false(res$visible)
  expect_s3_class(res$value, "table")
  # dnn = "x" because the table is built from the argument named `x`
  expect_identical(res$value, table(c("a", "b"), dnn = "x"))
  expect_length(out, 1L)
})

test_that("cli_table_oneline prints 'value: count' pairs separated by ', '", {
  withr::local_options(cli.num_colors = 1L)

  expect_identical(
    capture_cli(rpkgkit:::cli_table_oneline(c("a", "b", "b"))),
    "a: 1, b: 2"
  )
})

test_that("cli_table_oneline honours sep and colon", {
  withr::local_options(cli.num_colors = 1L)

  expect_identical(
    capture_cli(rpkgkit:::cli_table_oneline(
      c("a", "b"),
      sep = " | ",
      colon = " -> "
    )),
    "a -> 1 | b -> 1"
  )
})

test_that("cli_table_oneline counts missing values by default and labels them NA", {
  withr::local_options(cli.num_colors = 1L)

  expect_identical(
    capture_cli(rpkgkit:::cli_table_oneline(c("a", NA))),
    "a: 1, NA: 1"
  )
})

test_that("cli_table_oneline drops missing values with useNA = 'no'", {
  withr::local_options(cli.num_colors = 1L)

  expect_identical(
    capture_cli(rpkgkit:::cli_table_oneline(c("a", NA), useNA = "no")),
    "a: 1"
  )
})

test_that("cli_table_oneline prints braces verbatim", {
  withr::local_options(cli.num_colors = 1L)

  expect_identical(
    capture_cli(rpkgkit:::cli_table_oneline(c("{a}", "{a}"))),
    "{a}: 2"
  )
})

test_that("cli_table_oneline renders without styling when asked", {
  withr::local_options(cli.num_colors = 1L)

  expect_identical(
    capture_cli(rpkgkit:::cli_table_oneline(
      c("a", "b", "b"),
      head_format = NULL,
      count_format = NULL
    )),
    "a: 1, b: 2"
  )
})

test_that("cli_table_oneline applies inline classes to the line", {
  withr::local_options(cli.num_colors = 8L)

  out <- capture_cli(rpkgkit:::cli_table_oneline(
    c("a", "b", "b"),
    head_format = ".strong",
    count_format = ".emph"
  ))

  expect_length(out, 1L)
  expect_true(cli::ansi_has_any(out))
  expect_equal(cli::ansi_nchar(out, type = "width"), 10L)
})

test_that("cli_table_oneline accepts inline classes without the leading dot", {
  withr::local_options(cli.num_colors = 8L)

  dotted <- capture_cli(rpkgkit:::cli_table_oneline(
    c("a", "b", "b"),
    head_format = ".strong",
    count_format = ".emph"
  ))
  undotted <- capture_cli(rpkgkit:::cli_table_oneline(
    c("a", "b", "b"),
    head_format = "strong",
    count_format = "emph"
  ))

  expect_identical(undotted, dotted)
})

test_that("cli_table_oneline works with factors and numeric input", {
  withr::local_options(cli.num_colors = 1L)

  expect_identical(
    capture_cli(rpkgkit:::cli_table_oneline(factor(c("x", "y", "x")))),
    "x: 2, y: 1"
  )
  expect_identical(
    capture_cli(rpkgkit:::cli_table_oneline(c(1, 1, 2.5))),
    "1: 2, 2.5: 1"
  )
})

test_that("cli_table_oneline prints a bare colon pair for empty input", {
  withr::local_options(cli.num_colors = 1L)

  expect_identical(
    capture_cli(rpkgkit:::cli_table_oneline(character(0))),
    ": "
  )
})
