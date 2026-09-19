# ---------------------------------------------------------------------------
# convert_int_literals -- integration tests
# ---------------------------------------------------------------------------

test_that("convert_int_literals adds an L suffix to a bare integer literal", {
  path <- withr::local_tempfile(fileext = ".R")
  writeLines("tmp <- seq_len(10)", path)

  result <- convert_int_literals(path, verbose = FALSE)

  expect_equal(result, path)
  expect_equal(readLines(path, warn = FALSE), "tmp <- seq_len(10L)")
})

test_that("convert_int_literals returns the path invisibly", {
  path <- withr::local_tempfile(fileext = ".R")
  writeLines("x <- 1", path)

  expect_invisible(convert_int_literals(path, verbose = FALSE))
})

test_that("convert_int_literals converts every integer in an expression", {
  path <- withr::local_tempfile(fileext = ".R")
  writeLines("x <- c(1, 2, 3)", path)

  convert_int_literals(path, verbose = FALSE)

  expect_equal(readLines(path, warn = FALSE), "x <- c(1L, 2L, 3L)")
})

test_that("convert_int_literals leaves already-suffixed literals unchanged", {
  path <- withr::local_tempfile(fileext = ".R")
  writeLines("x <- 10L", path)

  convert_int_literals(path, verbose = FALSE)

  expect_equal(readLines(path, warn = FALSE), "x <- 10L")
})

test_that("convert_int_literals leaves floats, scientific, complex and dot-numbers", {
  path <- withr::local_tempfile(fileext = ".R")
  writeLines(
    c(
      "a <- 1.5",
      "b <- .5",
      "c <- 10.",
      "d <- 10i",
      "e <- 1_000"
    ),
    path
  )

  convert_int_literals(path, verbose = FALSE)

  expect_equal(
    readLines(path, warn = FALSE),
    c("a <- 1.5", "b <- .5", "c <- 10.", "d <- 10i", "e <- 1_000")
  )
})

test_that("convert_int_literals does not touch digits glued to identifiers", {
  path <- withr::local_tempfile(fileext = ".R")
  writeLines("x10 <- a10b", path)

  convert_int_literals(path, verbose = FALSE)

  expect_equal(readLines(path, warn = FALSE), "x10 <- a10b")
})

test_that("convert_int_literals leaves numbers inside strings unchanged", {
  path <- withr::local_tempfile(fileext = ".R")
  writeLines(c('x <- "10"', 'y <- "1.5 and 42"'), path)

  convert_int_literals(path, verbose = FALSE)

  expect_equal(
    readLines(path, warn = FALSE),
    c('x <- "10"', 'y <- "1.5 and 42"')
  )
})

test_that("convert_int_literals leaves numbers inside comments unchanged", {
  path <- withr::local_tempfile(fileext = ".R")
  writeLines(c("# 10", "x <- 5 # 42"), path)

  convert_int_literals(path, verbose = FALSE)

  expect_equal(readLines(path, warn = FALSE), c("# 10", "x <- 5L # 42"))
})

test_that("convert_int_literals converts hexadecimal literals", {
  path <- withr::local_tempfile(fileext = ".R")
  writeLines(c("a <- 0xFF", "b <- 0X10"), path)

  convert_int_literals(path, verbose = FALSE)

  expect_equal(readLines(path, warn = FALSE), c("a <- 0xFFL", "b <- 0X10L"))
})

test_that("convert_int_literals keeps existing L suffix on hex literals", {
  path <- withr::local_tempfile(fileext = ".R")
  writeLines("a <- 0xffL", path)

  convert_int_literals(path, verbose = FALSE)

  expect_equal(readLines(path, warn = FALSE), "a <- 0xffL")
})

test_that("convert_int_literals leaves non-numeric 0x sequences alone", {
  path <- withr::local_tempfile(fileext = ".R")
  writeLines("a <- 0xzz", path)

  convert_int_literals(path, verbose = FALSE)

  expect_equal(readLines(path, warn = FALSE), "a <- 0xzz")
})

test_that("convert_int_literals leaves raw strings unchanged", {
  path <- withr::local_tempfile(fileext = ".R")
  writeLines('x <- r"(10)"', path)

  convert_int_literals(path, verbose = FALSE)

  expect_equal(readLines(path, warn = FALSE), 'x <- r"(10)"')
})

test_that("convert_int_literals handlers escaped quotes in strings", {
  path <- withr::local_tempfile(fileext = ".R")
  # The literal `5` after the string should be converted, the escaped quoted
  # `10` inside the string should not.
  writeLines('x <- "say \\"10\\"" ; f(5)', path)

  convert_int_literals(path, verbose = FALSE)

  expect_equal(readLines(path, warn = FALSE), 'x <- "say \\"10\\"" ; f(5L)')
})

test_that("convert_int_literals processes multi-line input", {
  path <- withr::local_tempfile(fileext = ".R")
  writeLines(c("x <- 1", "y <- 2"), path)

  convert_int_literals(path, verbose = FALSE)

  expect_equal(readLines(path, warn = FALSE), c("x <- 1L", "y <- 2L"))
})

test_that("convert_int_literals reports no change via cli message", {
  path <- withr::local_tempfile(fileext = ".R")
  writeLines("x <- 10L", path)

  expect_message(
    convert_int_literals(path, verbose = TRUE),
    "No integer literals to convert"
  )
})

test_that("convert_int_literals reports success via cli message", {
  path <- withr::local_tempfile(fileext = ".R")
  writeLines("x <- 10", path)

  expect_message(
    convert_int_literals(path, verbose = TRUE),
    "Added explicit integer suffixes"
  )
})

test_that("convert_int_literals with verbose = FALSE is silent", {
  changed <- withr::local_tempfile(fileext = ".R")
  writeLines("x <- 10", changed)
  unchanged <- withr::local_tempfile(fileext = ".R")
  writeLines("x <- 10L", unchanged)

  expect_silent(convert_int_literals(changed, verbose = FALSE))
  expect_silent(convert_int_literals(unchanged, verbose = FALSE))
})

test_that("convert_int_literals aborts when ... is not empty", {
  path <- withr::local_tempfile(fileext = ".R")
  writeLines("x <- 1", path)

  expect_error(
    convert_int_literals(path, extra = "foo"),
    "must be empty"
  )
  # the file must be left untouched when the check fails
  expect_equal(readLines(path, warn = FALSE), "x <- 1")
})

test_that("convert_int_literals resolves the path from rstudioapi when NULL", {
  local_mocked_bindings(
    getActiveDocumentContext = function() list(path = "/mock/file.R"),
    .package = "rstudioapi"
  )
  local_mocked_bindings(
    readLines = function(con, ...) character(0L),
    .package = "base"
  )

  expect_invisible(convert_int_literals(verbose = FALSE))
})

# ---------------------------------------------------------------------------
# .cil_process_text -- internal unit tests
# ---------------------------------------------------------------------------

test_that(".cil_process_text converts a simple bare integer", {
  expect_equal(
    rpkgkit:::.cil_process_text("seq_len(10)"),
    "seq_len(10L)"
  )
})

test_that(".cil_process_text preserves surrounding text", {
  expect_equal(
    rpkgkit:::.cil_process_text("x <- c(1, 2, 3)"),
    "x <- c(1L, 2L, 3L)"
  )
})

test_that(".cil_process_text keeps an existing L suffix", {
  expect_equal(rpkgkit:::.cil_process_text("x <- 10L"), "x <- 10L")
})

test_that(".cil_process_text keeps a lowercase l suffix", {
  expect_equal(rpkgkit:::.cil_process_text("x <- 10l"), "x <- 10l")
})

test_that(".cil_process_text leaves floating point numbers", {
  expect_equal(rpkgkit:::.cil_process_text("x <- 1.5"), "x <- 1.5")
  expect_equal(rpkgkit:::.cil_process_text("x <- .5"), "x <- .5")
  expect_equal(rpkgkit:::.cil_process_text("x <- 10."), "x <- 10.")
})

test_that(".cil_process_text leaves scientific notation", {
  expect_equal(rpkgkit:::.cil_process_text("x <- 1e5"), "x <- 1e5")
  expect_equal(rpkgkit:::.cil_process_text("x <- 1E5"), "x <- 1E5")
})

test_that(".cil_process_text leaves complex literals", {
  expect_equal(rpkgkit:::.cil_process_text("x <- 10i"), "x <- 10i")
  expect_equal(rpkgkit:::.cil_process_text("x <- 0x1i"), "x <- 0x1i")
})

test_that(".cil_process_text ignores digits inside identifiers", {
  expect_equal(rpkgkit:::.cil_process_text("x10 <- 5"), "x10 <- 5L")
  expect_equal(rpkgkit:::.cil_process_text("x <- a10b"), "x <- a10b")
  expect_equal(rpkgkit:::.cil_process_text("x <- 0xFFz"), "x <- 0xFFz")
})

test_that(".cil_process_text ignores digits inside strings", {
  expect_equal(rpkgkit:::.cil_process_text('x <- "10"'), 'x <- "10"')
  expect_equal(rpkgkit:::.cil_process_text("x <- '42'"), "x <- '42'")
})

test_that(".cil_process_text ignores digits inside comments", {
  expect_equal(rpkgkit:::.cil_process_text("# 10"), "# 10")
  expect_equal(rpkgkit:::.cil_process_text("x <- 1 # 2"), "x <- 1L # 2")
})

test_that(".cil_process_text handles escaped quotes inside strings", {
  expect_equal(
    rpkgkit:::.cil_process_text('x <- "a\\"10\\""'),
    'x <- "a\\"10\\""'
  )
})

test_that(".cil_process_text converts hexadecimal literals", {
  expect_equal(rpkgkit:::.cil_process_text("0xFF"), "0xFFL")
  expect_equal(rpkgkit:::.cil_process_text("0X10"), "0X10L")
  expect_equal(rpkgkit:::.cil_process_text("0xAL"), "0xAL")
})

test_that(".cil_process_text leaves malformed 0x sequences", {
  expect_equal(rpkgkit:::.cil_process_text("0x"), "0x")
  expect_equal(rpkgkit:::.cil_process_text("0xg"), "0xg")
  expect_equal(rpkgkit:::.cil_process_text("0xzz"), "0xzz")
})

test_that(".cil_process_text leaves raw strings untouched", {
  expect_equal(rpkgkit:::.cil_process_text('r"(10)"'), 'r"(10)"')
  expect_equal(
    rpkgkit:::.cil_process_text('r"---(10)---"'),
    'r"---(10)---"'
  )
})

test_that(".cil_process_text handles numbers adjacent to punctuation", {
  expect_equal(rpkgkit:::.cil_process_text("x[[10]]"), "x[[10L]]")
  expect_equal(rpkgkit:::.cil_process_text("f(10, 20)"), "f(10L, 20L)")
  expect_equal(rpkgkit:::.cil_process_text("x <- -3"), "x <- -3L")
})

test_that(".cil_process_text converts across newlines but not in comments", {
  expect_equal(
    rpkgkit:::.cil_process_text("x <- 1 # 2\ny <- 3"),
    "x <- 1L # 2\ny <- 3L"
  )
})

test_that(".cil_process_text is idempotent", {
  once <- rpkgkit:::.cil_process_text("x <- c(1, 2L, 0xFF)")
  twice <- rpkgkit:::.cil_process_text(once)

  expect_equal(once, twice)
})

test_that(".cil_process_text round-trips text with no integer literals", {
  text <- 'x <- "hello" # a comment\ny <- 1.5'

  expect_equal(rpkgkit:::.cil_process_text(text), text)
})
