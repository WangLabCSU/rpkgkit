# Tests for use_air_table() and its internal helpers in
# R/54_use_air_table_.R

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Write `lines` to a temporary file that is removed at the end of the test.
air_file <- function(lines, env = parent.frame()) {
  withr::local_tempfile(lines = lines, .local_envir = env)
}

# Pretend that air is installed and that `air format` is a no-op, so the tests
# exercise the rewriting logic alone, never the external binary.
mock_air <- function(env = parent.frame()) {
  testthat::local_mocked_bindings(
    check_air_installed = function() invisible(TRUE),
    .uat_run_air = function(path) invisible(path),
    .package = "rpkgkit",
    .env = env
  )
}

# A vector already laid out by air: one element per line.
air_multiline_vec <- function() {
  c(
    "x <- c(",
    '  "a",',
    '  "b",',
    '  "c",',
    '  "d"',
    ")"
  )
}

# The table that both the single-line and the multi-line input collapse into.
air_table_vec <- function() {
  c(
    "# fmt: table",
    "x <- c(",
    '  "a", "b",',
    '  "c", "d"',
    ")"
  )
}

# ---------------------------------------------------------------------------
# Argument validation
# ---------------------------------------------------------------------------

test_that("use_air_table aborts on unused dots", {
  mock_air()
  tf <- air_file("x <- 1")

  expect_error(use_air_table(tf, foo = 1), "must be empty")
})

test_that("use_air_table validates ncol", {
  mock_air()
  tf <- air_file("x <- 1")

  expect_error(use_air_table(tf, ncol = 0), "ncol")
  expect_error(use_air_table(tf, ncol = 1.5), "ncol")
  expect_error(use_air_table(tf, ncol = "2"), "ncol")
})

test_that("use_air_table validates min_length", {
  mock_air()
  tf <- air_file("x <- 1")

  expect_error(use_air_table(tf, min_length = -1), "min_length")
  expect_error(use_air_table(tf, min_length = 2.5), "min_length")
})

test_that("use_air_table validates marker", {
  mock_air()
  tf <- air_file("x <- 1")

  expect_error(use_air_table(tf, marker = 1), "single string")
  expect_error(use_air_table(tf, marker = c("# fmt: table", "# x")), "single")
})

test_that("use_air_table aborts when air is not installed", {
  tf <- air_file("x <- 1")
  local_mocked_bindings(
    Sys.which = function(x) "",
    .package = "base"
  )
  local_mocked_bindings(interactive = function() FALSE, .package = "base")

  expect_error(use_air_table(tf), "is not installed")
})

# ---------------------------------------------------------------------------
# Path handling
# ---------------------------------------------------------------------------

test_that("use_air_table aborts when path is NULL and RStudio is unavailable", {
  mock_air()
  local_mocked_bindings(
    isAvailable = function() FALSE,
    .package = "rstudioapi"
  )

  expect_error(use_air_table(), "path.*required")
})

test_that("use_air_table uses the active document when path is NULL", {
  mock_air()
  tf <- air_file("x <- c(1, 2, 3, 4)")
  local_mocked_bindings(
    isAvailable = function() TRUE,
    getActiveDocumentContext = function() list(path = tf),
    .package = "rstudioapi"
  )

  expect_message(use_air_table(ncol = 2L, min_length = 3L), "Converted")
  expect_identical(readLines(tf)[[1L]], "# fmt: table")
})

test_that("use_air_table aborts when the file does not exist", {
  mock_air()
  tf <- withr::local_tempfile()

  expect_error(use_air_table(tf), "does not exist")
})

test_that("use_air_table aborts when the file is not valid R code", {
  mock_air()
  tf <- air_file("x <- c(1, 2")

  expect_error(use_air_table(tf), "not valid R code")
})

test_that("use_air_table returns the normalized path invisibly", {
  mock_air()
  tf <- air_file(air_table_vec())

  expect_message(
    res <- use_air_table(tf),
    "No vector or list"
  )
  expect_invisible(use_air_table(tf))
  expect_identical(res, normalizePath(tf, mustWork = TRUE))
})

# ---------------------------------------------------------------------------
# Rewriting behaviour
# ---------------------------------------------------------------------------

test_that("use_air_table splits a single-line vector into rows", {
  mock_air()
  tf <- air_file('x <- c("a", "b", "c", "d")')

  expect_message(use_air_table(tf, ncol = 2L, min_length = 2L), "Converted")
  expect_identical(readLines(tf), air_table_vec())
})

test_that("use_air_table collapses an already multi-line vector into rows", {
  mock_air()
  tf <- air_file(air_multiline_vec())

  expect_message(use_air_table(tf, ncol = 2L, min_length = 2L), "Converted")
  expect_identical(readLines(tf), air_table_vec())
})

test_that("use_air_table handles several targets in one file", {
  mock_air()
  tf <- air_file(c("a <- c(1, 2, 3, 4)", "b <- c(5, 6, 7, 8)"))

  expect_message(use_air_table(tf, ncol = 2L, min_length = 2L), "Converted")
  expect_identical(
    readLines(tf),
    c(
      "# fmt: table",
      "a <- c(",
      "  1, 2,",
      "  3, 4",
      ")",
      "# fmt: table",
      "b <- c(",
      "  5, 6,",
      "  7, 8",
      ")"
    )
  )
})

test_that("use_air_table keeps indentation of an indented call", {
  mock_air()
  tf <- air_file(c("f <- function() {", "  x <- c(1, 2, 3, 4)", "}"))

  expect_message(use_air_table(tf, ncol = 2L, min_length = 2L), "Converted")
  expect_identical(
    readLines(tf),
    c(
      "f <- function() {",
      "  # fmt: table",
      "  x <- c(",
      "    1, 2,",
      "    3, 4",
      "  )",
      "}"
    )
  )
})

test_that("use_air_table honours a custom marker", {
  mock_air()
  tf <- air_file("x <- c(1, 2, 3, 4)")

  expect_message(
    use_air_table(tf, ncol = 2L, min_length = 2L, marker = "# fmt: table2"),
    "Converted"
  )
  expect_identical(readLines(tf)[[1L]], "# fmt: table2")
})

test_that("use_air_table is idempotent", {
  mock_air()
  tf <- air_file(air_table_vec())

  expect_message(
    use_air_table(tf, ncol = 2L, min_length = 2L),
    "No vector or list"
  )
  expect_identical(readLines(tf), air_table_vec())
})

test_that("use_air_table reports when no target qualifies", {
  mock_air()
  tf <- air_file(c("x <- 1", "y <- c(1, 2)"))

  expect_message(
    use_air_table(tf, min_length = 5L),
    "No vector or list with more than 5 elements"
  )
  expect_identical(readLines(tf), c("x <- 1", "y <- c(1, 2)"))
})

test_that("use_air_table only converts vectors longer than min_length", {
  mock_air()
  tf <- air_file("x <- c(1, 2, 3, 4)")

  expect_message(use_air_table(tf, min_length = 4L), "No vector or list")
  expect_identical(readLines(tf), "x <- c(1, 2, 3, 4)")

  expect_message(use_air_table(tf, min_length = 3L), "Converted")
  expect_identical(readLines(tf)[[1L]], "# fmt: table")
})

test_that("use_air_table skips calls with named elements", {
  mock_air()
  lines <- "x <- list(a = 1, b = 2, c = 3, d = 4)"
  tf <- air_file(lines)

  expect_message(use_air_table(tf, min_length = 2L), "No vector or list")
  expect_identical(readLines(tf), lines)
})

test_that("use_air_table skips calls nested inside another call", {
  mock_air()
  lines <- 'print(c("a", "b", "c", "d"))'
  tf <- air_file(lines)

  expect_message(use_air_table(tf, min_length = 2L), "No vector or list")
  expect_identical(readLines(tf), lines)
})

test_that("use_air_table never joins a line that ends in a comment", {
  mock_air()
  tf <- air_file(c(
    "x <- c(",
    '  "a", # first',
    '  "b",',
    '  "c",',
    '  "d"',
    ")"
  ))

  expect_message(use_air_table(tf, ncol = 2L, min_length = 2L), "Converted")
  expect_identical(
    readLines(tf),
    c(
      "# fmt: table",
      "x <- c(",
      '  "a", # first',
      '  "b",',
      '  "c", "d"',
      ")"
    )
  )
})

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

test_that(".uat_rows() splits element indices into rows", {
  expect_identical(unname(.uat_rows(4L, 2L)), list(c(1L, 2L), c(3L, 4L)))
  expect_identical(unname(.uat_rows(5L, 3L)), list(c(1L, 2L, 3L), c(4L, 5L)))
  expect_identical(unname(.uat_rows(3L, 1L)), list(1L, 2L, 3L))
})

test_that(".uat_parse() returns expressions and aborts on invalid code", {
  expect_length(.uat_parse("x <- 1", path = "test.R"), 1L)
  expect_length(.uat_parse(character(0), path = "test.R"), 0L)
  expect_error(
    .uat_parse("x <- (", path = "test.R"),
    "not valid R code"
  )
})

test_that(".uat_targets() returns an empty data frame when nothing qualifies", {
  targets <- .uat_targets(
    lines = c("x <- 1", "y <- c(1, 2)"),
    path = "test.R",
    min_length = 5L,
    marker = "# fmt: table"
  )

  expect_s3_class(targets, "data.frame")
  expect_identical(nrow(targets), 0L)
  expect_named(
    targets,
    c("line1", "line2", "col1", "n", "multiline", "elements")
  )
})

test_that(".uat_targets() describes qualifying calls", {
  targets <- .uat_targets(
    lines = air_multiline_vec(),
    path = "test.R",
    min_length = 2L,
    marker = "# fmt: table"
  )

  expect_identical(nrow(targets), 1L)
  expect_identical(targets$line1, 1L)
  expect_identical(targets$line2, 6L)
  expect_identical(targets$n, 4L)
  expect_true(targets$multiline)
  expect_identical(nrow(targets$elements[[1L]]), 4L)
})

test_that(".uat_targets() ignores calls that already carry the marker", {
  targets <- .uat_targets(
    lines = air_table_vec(),
    path = "test.R",
    min_length = 2L,
    marker = "# fmt: table"
  )

  expect_identical(nrow(targets), 0L)
})

test_that(".uat_split_lines() rewrites a single-line call", {
  line <- "x <- c(1, 2, 3, 4)"
  elements <- data.frame(
    line1 = 1L,
    col1 = c(8L, 11L, 14L, 17L),
    line2 = 1L,
    col2 = c(8L, 11L, 14L, 17L)
  )

  expect_identical(
    .uat_split_lines(
      line = line,
      call_col1 = 6L,
      elements = elements,
      ncol = 2L
    ),
    c("x <- c(", "  1, 2,", "  3, 4", ")")
  )
})

test_that(".uat_join_flags() sets a flag only when a row continues", {
  elements <- data.frame(
    line1 = c(1L, 2L),
    col1 = c(3L, 3L),
    line2 = c(1L, 2L),
    col2 = c(5L, 5L)
  )

  expect_identical(
    .uat_join_flags(
      join = c(FALSE, FALSE),
      elements = elements,
      ncol = 2L,
      lines = c('  "a",', '  "b"')
    ),
    c(FALSE, TRUE)
  )

  # A trailing comment must keep the line break.
  expect_identical(
    .uat_join_flags(
      join = c(FALSE, FALSE),
      elements = elements,
      ncol = 2L,
      lines = c('  "a", # keep', '  "b"')
    ),
    c(FALSE, FALSE)
  )

  # One element per row never joins anything.
  expect_identical(
    .uat_join_flags(
      join = c(FALSE, FALSE),
      elements = elements,
      ncol = 1L,
      lines = c('  "a",', '  "b"')
    ),
    c(FALSE, FALSE)
  )
})

test_that(".uat_join_flags() ignores lines that are not adjacent", {
  elements <- data.frame(
    line1 = c(1L, 3L),
    col1 = c(3L, 3L),
    line2 = c(1L, 3L),
    col2 = c(5L, 5L)
  )

  expect_identical(
    .uat_join_flags(
      join = c(FALSE, FALSE, FALSE),
      elements = elements,
      ncol = 2L,
      lines = c('  "a",', "", '  "b"')
    ),
    c(FALSE, FALSE, FALSE)
  )
})

test_that(".uat_run_air() aborts when air fails", {
  local_mocked_bindings(
    system2 = function(...) structure("error: bad syntax", status = 1L),
    .package = "base"
  )

  expect_error(.uat_run_air("test.R"), "failed to format")
})

test_that(".uat_run_air() returns the path invisibly on success", {
  local_mocked_bindings(
    system2 = function(...) character(),
    .package = "base"
  )

  expect_invisible(.uat_run_air("test.R"))
  expect_identical(.uat_run_air("test.R"), "test.R")
})
