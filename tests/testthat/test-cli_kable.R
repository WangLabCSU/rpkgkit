# Tests for standalone-cli_kable.R
# cli_kable() and its internal helpers: .ck_cell_text(), .ck_align(),
# .ck_fmt_axis(), .ck_fmt_cells(), .ck_col_cls(), .ck_map_named(),
# .ck_norm_class(), .ck_style(), .ck_style1(), .ck_pad(), .ck_rule()
#
# cli::cli_verbatim() signals a "cliMessage" condition, so it is captured with
# capture.output(type = "message"). ANSI styling is turned off with
# cli.num_colors = 1 so the expected strings can be compared literally. The
# `{.val}` class still adds its quotes, which is what the partial-styling tests
# rely on to make a styled cell visible without colours.

capture_cli <- function(expr) {
  capture.output(expr, type = "message")
}

# ── .ck_cell_text ────────────────────────────────────────────────────────────

test_that(".ck_cell_text formats a numeric column as a vector", {
  # `format()` on the whole column keeps the decimals aligned
  expect_identical(rpkgkit:::.ck_cell_text(c(1, 2.5), NULL), c("1.0", "2.5"))
  expect_identical(
    rpkgkit:::.ck_cell_text(c(21, 22.8, 18), NULL),
    c("21.0", "22.8", "18.0")
  )
})

test_that(".ck_cell_text leaves integers alone", {
  expect_identical(rpkgkit:::.ck_cell_text(c(1L, 2L), NULL), c("1", "2"))
})

test_that(".ck_cell_text rounds to `digits` decimals, as kable() does", {
  expect_identical(
    rpkgkit:::.ck_cell_text(c(1.23456, 2), 2),
    c("1.23", "2.00")
  )
  expect_identical(rpkgkit:::.ck_cell_text(c(1.5, 2.5), 0), c("2", "2"))
})

test_that(".ck_cell_text coerces characters, factors and logicals", {
  expect_identical(rpkgkit:::.ck_cell_text(c("a", "b"), NULL), c("a", "b"))
  expect_identical(
    rpkgkit:::.ck_cell_text(factor(c("x", "y")), NULL),
    c("x", "y")
  )
  expect_identical(
    rpkgkit:::.ck_cell_text(c(TRUE, FALSE), NULL),
    c("TRUE", "FALSE")
  )
})

test_that(".ck_cell_text prints missing values as NA", {
  expect_identical(rpkgkit:::.ck_cell_text(c("a", NA), NULL), c("a", "NA"))
  expect_identical(rpkgkit:::.ck_cell_text(c(1, NA), NULL), c("1", "NA"))
  expect_identical(
    rpkgkit:::.ck_cell_text(factor(c("x", NA)), NULL),
    c("x", "NA")
  )
  expect_identical(
    rpkgkit:::.ck_cell_text(c(TRUE, NA), NULL),
    c("TRUE", "NA")
  )
})

test_that(".ck_cell_text trims surrounding whitespace", {
  expect_identical(rpkgkit:::.ck_cell_text(c(" a ", "b"), NULL), c("a", "b"))
})

# ── .ck_align ────────────────────────────────────────────────────────────────

test_that(".ck_align right-aligns numbers and left-aligns the rest", {
  expect_identical(
    rpkgkit:::.ck_align(NULL, data.frame(n = 1, d = 1.5, ch = "a", l = TRUE)),
    c("right", "right", "left", "left")
  )
})

test_that(".ck_align recycles and normalises the alignment", {
  df <- data.frame(a = 1, b = 2)

  expect_identical(rpkgkit:::.ck_align("l", df), c("left", "left"))
  expect_identical(rpkgkit:::.ck_align(c("r", "left"), df), c("right", "left"))
  expect_identical(rpkgkit:::.ck_align("CENTER", df), c("center", "center"))
})

test_that(".ck_align rejects an unknown alignment", {
  expect_error(
    rpkgkit:::.ck_align("middle", data.frame(a = 1)),
    "must be one of"
  )
})

test_that(".ck_align rejects a non-character alignment", {
  expect_error(rpkgkit:::.ck_align(1, data.frame(a = 1)), "must be")
})

# ── .ck_fmt_axis ─────────────────────────────────────────────────────────────

test_that(".ck_fmt_axis returns no styling for NULL", {
  expect_identical(
    rpkgkit:::.ck_fmt_axis(NULL, c("a", "b"), "f", "column"),
    c("", "")
  )
})

test_that(".ck_fmt_axis recycles a single class and drops its dot", {
  expect_identical(
    rpkgkit:::.ck_fmt_axis(".val", c("a", "b"), "f", "column"),
    c("val", "val")
  )
  expect_identical(
    rpkgkit:::.ck_fmt_axis("val", c("a", "b"), "f", "column"),
    c("val", "val")
  )
})

test_that(".ck_fmt_axis maps an unnamed vector positionally", {
  expect_identical(
    rpkgkit:::.ck_fmt_axis(c(".val", ".field"), c("a", "b"), "f", "column"),
    c("val", "field")
  )
})

test_that(".ck_fmt_axis styles only the named keys", {
  expect_identical(
    rpkgkit:::.ck_fmt_axis(c(b = ".val"), c("a", "b"), "f", "column"),
    c("", "val")
  )
})

test_that(".ck_fmt_axis uses an unnamed value as the fallback", {
  expect_identical(
    rpkgkit:::.ck_fmt_axis(c(".emph", b = ".val"), c("a", "b"), "f", "column"),
    c("emph", "val")
  )
  expect_identical(
    rpkgkit:::.ck_fmt_axis(c("", b = ".val"), c("a", "b"), "f", "column"),
    c("", "val")
  )
})

test_that(".ck_fmt_axis accepts a named list of single classes", {
  expect_identical(
    rpkgkit:::.ck_fmt_axis(list(b = "field"), c("a", "b"), "f", "column"),
    c("", "field")
  )
})

test_that(".ck_fmt_axis rejects nested styles", {
  expect_error(
    rpkgkit:::.ck_fmt_axis(list(a = c(x = ".val")), c("a", "b"), "f", "column"),
    "single strings"
  )
})

test_that(".ck_fmt_axis reports a length mismatch", {
  expect_error(
    rpkgkit:::.ck_fmt_axis(
      c(".val", ".field"),
      c("a", "b", "c"),
      "f",
      "column"
    ),
    "must be length 3"
  )
  expect_error(
    rpkgkit:::.ck_fmt_axis(c(".val", ".field"), "a", "f", "column"),
    "or 1"
  )
})

test_that(".ck_fmt_axis rejects a non-character format", {
  expect_error(rpkgkit:::.ck_fmt_axis(1, "a", "f", "column"), "must be")
})

test_that(".ck_fmt_axis reports unknown names together with the known ones", {
  expect_error(
    rpkgkit:::.ck_fmt_axis(c(nope = ".val"), c("a", "b"), "f", "column"),
    "unknown column name"
  )
  expect_error(
    rpkgkit:::.ck_fmt_axis(c(nope = ".val"), c("a", "b"), "f", "column"),
    "Known column names: a, b"
  )
})

# ── .ck_fmt_cells ────────────────────────────────────────────────────────────

test_that(".ck_fmt_cells returns an unstyled matrix for NULL", {
  out <- rpkgkit:::.ck_fmt_cells(NULL, c("a", "b"), c("r1", "r2"), "f")

  expect_identical(dim(out), c(2L, 2L))
  expect_identical(out, matrix("", nrow = 2L, ncol = 2L))
})

test_that(".ck_fmt_cells styles every cell with a single class", {
  expect_identical(
    rpkgkit:::.ck_fmt_cells(".val", c("a", "b"), c("r1", "r2"), "f"),
    matrix("val", nrow = 2L, ncol = 2L)
  )
})

test_that(".ck_fmt_cells maps an unnamed vector over the columns", {
  expect_identical(
    rpkgkit:::.ck_fmt_cells(
      c(".val", ".field"),
      c("a", "b"),
      c("r1", "r2"),
      "f"
    ),
    matrix(rep(c("val", "field"), each = 2L), nrow = 2L)
  )
})

test_that(".ck_fmt_cells styles named columns only", {
  expect_identical(
    rpkgkit:::.ck_fmt_cells(c(b = ".val"), c("a", "b"), c("r1", "r2"), "f"),
    matrix(c("", "", "val", "val"), nrow = 2L)
  )
  expect_identical(
    rpkgkit:::.ck_fmt_cells(
      list(a = ".field"),
      c("a", "b"),
      c("r1", "r2"),
      "f"
    ),
    matrix(c("field", "field", "", ""), nrow = 2L)
  )
})

test_that(".ck_fmt_cells styles named rows inside a column", {
  expect_identical(
    rpkgkit:::.ck_fmt_cells(
      list(a = c(r2 = ".val")),
      c("a", "b"),
      c("r1", "r2"),
      "f"
    ),
    matrix(c("", "val", "", ""), nrow = 2L)
  )
})

test_that(".ck_fmt_cells maps an unnamed per-row vector positionally", {
  expect_identical(
    rpkgkit:::.ck_fmt_cells(
      list(a = c(".emph", ".val")),
      c("a", "b"),
      c("r1", "r2"),
      "f"
    ),
    matrix(c("emph", "val", "", ""), nrow = 2L)
  )
})

test_that(".ck_fmt_cells uses an unnamed element as the fallback", {
  expect_identical(
    rpkgkit:::.ck_fmt_cells(
      list(".emph", a = c(r2 = ".val")),
      c("a", "b"),
      c("r1", "r2"),
      "f"
    ),
    matrix(c("", "val", "emph", "emph"), nrow = 2L)
  )
})

test_that(".ck_fmt_cells reports unknown column and row names", {
  expect_error(
    rpkgkit:::.ck_fmt_cells(
      list(nope = ".val"),
      c("a", "b"),
      c("r1", "r2"),
      "f"
    ),
    "unknown column name"
  )
  expect_error(
    rpkgkit:::.ck_fmt_cells(
      list(a = c(nope = ".val")),
      c("a", "b"),
      c("r1", "r2"),
      "f"
    ),
    "unknown row name"
  )
})

test_that(".ck_fmt_cells rejects more than one unnamed element", {
  expect_error(
    rpkgkit:::.ck_fmt_cells(
      list(".val", ".field", c = ".val"),
      c("a", "b", "c"),
      "r1",
      "f"
    ),
    "unnamed elements"
  )
})

test_that(".ck_fmt_cells rejects an element of the wrong length or type", {
  expect_error(
    rpkgkit:::.ck_fmt_cells(
      list(a = c(".val", ".val", ".val")),
      "a",
      c("r1", "r2"),
      "f"
    ),
    "must be length 2"
  )
  expect_error(
    rpkgkit:::.ck_fmt_cells(list(a = 1), "a", c("r1", "r2"), "f"),
    "must be"
  )
})

# ── .ck_norm_class ───────────────────────────────────────────────────────────

test_that(".ck_norm_class drops the dot and keeps empty and NA as no style", {
  expect_identical(
    rpkgkit:::.ck_norm_class(c(".val", "", NA, "strong"), "f"),
    c("val", "", "", "strong")
  )
})

test_that(".ck_norm_class rejects an invalid class", {
  expect_error(
    rpkgkit:::.ck_norm_class(".not a class", "f"),
    "invalid cli class"
  )
})

# ── .ck_style ────────────────────────────────────────────────────────────────

test_that(".ck_style leaves cells without a class untouched", {
  expect_identical(rpkgkit:::.ck_style(c("a", "b"), c("", "")), c("a", "b"))
})

test_that(".ck_style applies one class per cell", {
  withr::local_options(cli.num_colors = 1L)

  expect_identical(
    rpkgkit:::.ck_style(c("a", "b"), c(".val", "")),
    c("\"a\"", "b")
  )
})

test_that(".ck_style recycles a single class over every cell", {
  withr::local_options(cli.num_colors = 1L)

  expect_identical(
    rpkgkit:::.ck_style(c("a", "b"), ".val"),
    c("\"a\"", "\"b\"")
  )
})

test_that(".ck_style accepts a class with the leading dot", {
  # `{..val} ` is an invalid cli literal (cli >= 3.4.0), so the dot is dropped
  withr::local_options(cli.num_colors = 1L)

  expect_no_error(rpkgkit:::.ck_style("a", ".val"))
  expect_identical(
    rpkgkit:::.ck_style("a", ".val"),
    rpkgkit:::.ck_style("a", "val")
  )
})

test_that(".ck_style adds ANSI styling without changing the visible width", {
  withr::local_options(cli.num_colors = 8L)

  styled <- rpkgkit:::.ck_style(c("a", "bb"), c(".field", ""))

  expect_true(cli::ansi_has_any(styled[1L]))
  expect_false(cli::ansi_has_any(styled[2L]))
  expect_identical(cli::ansi_nchar(styled, type = "width"), c(1L, 2L))
  expect_identical(cli::ansi_strip(styled), c("a", "bb"))
})

# ── .ck_pad ──────────────────────────────────────────────────────────────────

test_that(".ck_pad pads on the right with 'left'", {
  expect_identical(
    rpkgkit:::.ck_pad(c("a", "bb"), c(3L, 3L), "left"),
    c("a  ", "bb ")
  )
})

test_that(".ck_pad pads on the left with 'right'", {
  expect_identical(
    rpkgkit:::.ck_pad(c("a", "bb"), c(3L, 3L), "right"),
    c("  a", " bb")
  )
})

test_that(".ck_pad centres with 'center'", {
  expect_identical(
    rpkgkit:::.ck_pad(c("a", "bbb"), c(3L, 3L), "center"),
    c(" a ", "bbb")
  )
})

test_that(".ck_pad leaves text that already fills the width untouched", {
  expect_identical(rpkgkit:::.ck_pad("abc", 3L, "right"), "abc")
})

test_that(".ck_pad never asks for a negative number of spaces", {
  expect_identical(rpkgkit:::.ck_pad("abcd", 3L, "left"), "abcd")
})

test_that(".ck_pad recycles a single alignment over every element", {
  # ifelse() returns as many values as `test`, so `how` is recycled first
  expect_identical(
    rpkgkit:::.ck_pad(c("a", "bb", "ccc"), rep(3L, 3L), "right"),
    c("  a", " bb", "ccc")
  )
})

test_that(".ck_pad measures the visible width of styled text", {
  withr::local_options(cli.num_colors = 8L)

  styled <- rpkgkit:::.ck_style("a", ".field")

  expect_identical(rpkgkit:::.ck_pad(styled, 3L, "right"), paste0("  ", styled))
})

# ── .ck_rule ─────────────────────────────────────────────────────────────────

test_that(".ck_rule builds the alignment row for each alignment", {
  expect_identical(
    rpkgkit:::.ck_rule(c(3L, 4L, 5L), c("left", "right", "center")),
    c(":--", "---:", ":---:")
  )
})

test_that(".ck_rule recycles a single alignment", {
  expect_identical(rpkgkit:::.ck_rule(c(3L, 4L), "right"), c("--:", "---:"))
})

# ── cli_kable ────────────────────────────────────────────────────────────────

test_that("cli_kable() prints the layout of knitr::kable()", {
  withr::local_options(cli.num_colors = 1L)

  d <- data.frame(ch = c("a", "bbb"), num = c(1, 2.5))

  expect_identical(
    capture_cli(
      rpkgkit:::cli_kable(d, header_format = NULL, rownames_format = NULL)
    ),
    c("|ch  | num|", "|:---|---:|", "|a   | 1.0|", "|bbb | 2.5|")
  )
})

test_that("cli_kable() matches knitr::kable() across input shapes", {
  skip_if_not_installed("knitr")
  withr::local_options(cli.num_colors = 1L)

  frames <- list(
    data.frame(ch = c("a", "bbb"), num = c(1, 2.5), lgl = c(TRUE, NA)),
    data.frame(a = 1:3),
    data.frame(a = 1:3, row.names = c("r1", "r2", "r3")),
    data.frame(b = c("x", "y"), row.names = c("p", "q")),
    data.frame(a = numeric(0), b = character(0)),
    matrix(1:4, 2, dimnames = list(c("r1", "r2"), c("a", "b"))),
    mtcars[1:3, 1:4]
  )

  for (x in frames) {
    expect_identical(
      capture_cli(
        rpkgkit:::cli_kable(x, header_format = NULL, rownames_format = NULL)
      ),
      as.character(knitr::kable(x))
    )
  }
})

test_that("cli_kable() returns the printed lines invisibly", {
  withr::local_options(cli.num_colors = 1L)

  out <- capture_cli(
    res <- withVisible(
      rpkgkit:::cli_kable(
        data.frame(a = 1:2),
        header_format = NULL,
        rownames_format = NULL
      )
    )
  )

  expect_false(res$visible)
  expect_identical(res$value, c("|  a|", "|--:|", "|  1|", "|  2|"))
  expect_identical(out, res$value)
})

test_that("cli_kable() drops the row names column when they are 1:n", {
  withr::local_options(cli.num_colors = 1L)

  # the printed table has one column, so no row names column is added
  expect_identical(
    capture_cli(
      rpkgkit:::cli_kable(
        data.frame(a = 1:2),
        header_format = NULL,
        rownames_format = NULL
      )
    ),
    c("|  a|", "|--:|", "|  1|", "|  2|")
  )
})

test_that("cli_kable() keeps custom row names, left aligned", {
  withr::local_options(cli.num_colors = 1L)

  d <- data.frame(x = c(1, 2), row.names = c("r1", "r2"))

  expect_identical(
    capture_cli(
      rpkgkit:::cli_kable(d, header_format = NULL, rownames_format = NULL)
    ),
    c("|   |  x|", "|:--|--:|", "|r1 |  1|", "|r2 |  2|")
  )
})

test_that("cli_kable() accepts a matrix", {
  withr::local_options(cli.num_colors = 1L)

  m <- matrix(1:4, 2, dimnames = list(c("r1", "r2"), c("a", "b")))

  expect_identical(
    capture_cli(
      rpkgkit:::cli_kable(m, header_format = NULL, rownames_format = NULL)
    ),
    c("|   |  a|  b|", "|:--|--:|--:|", "|r1 |  1|  3|", "|r2 |  2|  4|")
  )
})

test_that("cli_kable() prints only the headers when there are no rows", {
  withr::local_options(cli.num_colors = 1L)

  d <- data.frame(a = numeric(0), b = character(0))

  expect_identical(
    capture_cli(
      rpkgkit:::cli_kable(d, header_format = NULL, rownames_format = NULL)
    ),
    c("|  a|b  |", "|--:|:--|")
  )
})

test_that("cli_kable() honours align", {
  withr::local_options(cli.num_colors = 1L)

  d <- data.frame(ch = c("a", "bbb"), num = c(1, 2.5))

  expect_identical(
    capture_cli(
      rpkgkit:::cli_kable(
        d,
        header_format = NULL,
        rownames_format = NULL,
        align = "c"
      )
    ),
    c("| ch  | num |", "|:---:|:---:|", "|  a  | 1.0 |", "| bbb | 2.5 |")
  )
})

test_that("cli_kable() honours padding and keeps columns 3 wide", {
  withr::local_options(cli.num_colors = 1L)

  d <- data.frame(ch = c("a", "bbb"), num = c(1, 2.5))

  expect_identical(
    capture_cli(
      rpkgkit:::cli_kable(
        d,
        header_format = NULL,
        rownames_format = NULL,
        padding = 0
      )
    ),
    c("|ch |num|", "|:--|--:|", "|a  |1.0|", "|bbb|2.5|")
  )
})

test_that("cli_kable() honours rule and sep", {
  withr::local_options(cli.num_colors = 1L)

  d <- data.frame(ch = c("a", "bbb"), num = c(1, 2.5))

  expect_identical(
    capture_cli(
      rpkgkit:::cli_kable(
        d,
        header_format = NULL,
        rownames_format = NULL,
        rule = FALSE,
        sep = " | "
      )
    ),
    c(" | ch   |  num | ", " | a    |  1.0 | ", " | bbb  |  2.5 | ")
  )
})

test_that("cli_kable() rounds numeric columns with digits", {
  withr::local_options(cli.num_colors = 1L)

  expect_identical(
    capture_cli(
      rpkgkit:::cli_kable(
        data.frame(n = c(1.23456, 2)),
        header_format = NULL,
        rownames_format = NULL,
        digits = 2
      )
    ),
    c("|    n|", "|----:|", "| 1.23|", "| 2.00|")
  )
})

test_that("cli_kable() styles headers and row names with .val by default", {
  withr::local_options(cli.num_colors = 1L)

  d <- data.frame(ch = c("a", "bbb"), num = c(1, 2.5))

  expect_identical(
    capture_cli(rpkgkit:::cli_kable(d)),
    c(
      "|\"ch\" | \"num\"|",
      "|:----|-----:|",
      "|a    |   1.0|",
      "|bbb  |   2.5|"
    )
  )
})

test_that("cli_kable() styles only the columns named in header_format", {
  withr::local_options(cli.num_colors = 1L)

  d <- data.frame(ch = c("a", "bbb"), num = c(1, 2.5))

  expect_identical(
    capture_cli(rpkgkit:::cli_kable(d, header_format = c(num = ".val"))),
    c("|ch  | \"num\"|", "|:---|-----:|", "|a   |   1.0|", "|bbb |   2.5|")
  )
})

test_that("cli_kable() styles only the rows named in rownames_format", {
  withr::local_options(cli.num_colors = 1L)

  d <- data.frame(x = c(1, 2), row.names = c("r1", "r2"))

  expect_identical(
    capture_cli(rpkgkit:::cli_kable(d, rownames_format = c(r2 = ".val"))),
    c("|     | \"x\"|", "|:----|---:|", "|r1   |   1|", "|\"r2\" |   2|")
  )
})

test_that("cli_kable() styles the values of the named columns", {
  withr::local_options(cli.num_colors = 1L)

  d <- data.frame(ch = c("a", "bbb"), num = c(1, 2.5))

  expect_identical(
    capture_cli(rpkgkit:::cli_kable(d, value_format = c(num = ".val"))),
    c(
      "|\"ch\" | \"num\"|",
      "|:----|-----:|",
      "|a    | \"1.0\"|",
      "|bbb  | \"2.5\"|"
    )
  )
})

test_that("cli_kable() styles single cells by column and row name", {
  withr::local_options(cli.num_colors = 1L)

  d <- data.frame(x = c(1, 2), row.names = c("r1", "r2"))

  expect_identical(
    capture_cli(rpkgkit:::cli_kable(
      d,
      value_format = list(x = c(r2 = ".val"))
    )),
    c("|     | \"x\"|", "|:----|---:|", "|\"r1\" |   1|", "|\"r2\" | \"2\"|")
  )
})

test_that("cli_kable() uses an unnamed value_format as the fallback", {
  withr::local_options(cli.num_colors = 1L)

  d <- data.frame(a = 1:2, b = c("x", "y"))
  expected <- c("|   a|b  |", "|---:|:--|", "| \"1\"|x  |", "| \"2\"|y  |")

  expect_identical(
    capture_cli(
      rpkgkit:::cli_kable(
        d,
        header_format = NULL,
        rownames_format = NULL,
        value_format = c(".val", b = ".field")
      )
    ),
    expected
  )
  # the same fallback works when the format is a list
  expect_identical(
    capture_cli(
      rpkgkit:::cli_kable(
        d,
        header_format = NULL,
        rownames_format = NULL,
        value_format = list(".val", b = ".field")
      )
    ),
    expected
  )
})

test_that("cli_kable() can highlight the last columns and the last rows", {
  withr::local_options(cli.num_colors = 1L)

  d <- data.frame(
    a = 1:3,
    b = c("x", "y", "z"),
    row.names = c("r1", "r2", "r3")
  )

  expect_identical(
    capture_cli(
      rpkgkit:::cli_kable(
        d,
        header_format = c(b = ".val"),
        rownames_format = c(r3 = ".val"),
        value_format = list(b = c(r3 = ".val"))
      )
    ),
    c(
      "|     |  a|\"b\" |",
      "|:----|--:|:---|",
      "|r1   |  1|x   |",
      "|r2   |  2|y   |",
      "|\"r3\" |  3|\"z\" |"
    )
  )
})

test_that("cli_kable() prints braces in the values verbatim", {
  withr::local_options(cli.num_colors = 1L)

  d <- data.frame(v = c("{a}", "b}"), stringsAsFactors = FALSE)

  expect_identical(
    capture_cli(
      rpkgkit:::cli_kable(d, header_format = NULL, rownames_format = NULL)
    ),
    c("|v   |", "|:---|", "|{a} |", "|b}  |")
  )
  expect_identical(
    capture_cli(
      rpkgkit:::cli_kable(
        d,
        header_format = NULL,
        rownames_format = NULL,
        value_format = ".val"
      )
    ),
    c("|v     |", "|:-----|", "|\"{a}\" |", "|\"b}\"  |")
  )
})

test_that("cli_kable() keeps the columns aligned when colours are on", {
  withr::local_options(cli.num_colors = 8L)

  d <- data.frame(ch = c("a", "bbb"), num = c(1, 2.5))
  out <- capture_cli(rpkgkit:::cli_kable(d, header_format = c(num = ".val")))

  expect_true(cli::ansi_has_any(out[1L]))
  expect_identical(cli::ansi_nchar(out, type = "width"), rep(13L, 4L))
})

test_that("cli_kable() prints the same text with and without colours", {
  d <- data.frame(ch = c("a", "bbb"), num = c(1, 2.5))

  withr::local_options(cli.num_colors = 1L)
  plain <- capture_cli(rpkgkit:::cli_kable(d, header_format = c(num = ".val")))

  withr::local_options(cli.num_colors = 8L)
  colored <- capture_cli(rpkgkit:::cli_kable(
    d,
    header_format = c(num = ".val")
  ))

  expect_identical(cli::ansi_strip(colored), plain)
})

test_that("cli_kable() reports unknown names in the formats", {
  expect_error(
    rpkgkit:::cli_kable(data.frame(a = 1), header_format = c(nope = ".val")),
    "unknown column name"
  )
  expect_error(
    rpkgkit:::cli_kable(data.frame(a = 1), value_format = list(nope = ".val")),
    "unknown column name"
  )
  expect_error(
    rpkgkit:::cli_kable(
      data.frame(a = 1, row.names = "r1"),
      value_format = list(a = c(nope = ".val"))
    ),
    "unknown row name"
  )
})

test_that("cli_kable() validates its arguments", {
  d <- data.frame(a = 1)

  expect_error(
    rpkgkit:::cli_kable(d, header_format = ".not a class"),
    "invalid cli class"
  )
  expect_error(rpkgkit:::cli_kable(d, align = "middle"), "must be one of")
  expect_error(rpkgkit:::cli_kable(d, padding = -1), "non-negative")
  expect_error(rpkgkit:::cli_kable(d, digits = "2"), "single number")
  expect_error(rpkgkit:::cli_kable(d, sep = 1), "single string")
})
