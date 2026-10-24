# ---------------------------------------------------------------------------
# detect_unmatched_nocov_marker -- integration tests
# ---------------------------------------------------------------------------

# Markers are assembled from pieces so this file never contains a real marker
# comment: `find_nocov_markers()` scans the raw text, comments included.
marker_start <- paste0("# nocov", " start")
marker_end <- paste0("# nocov", " end")

test_that("detect_unmatched_nocov_marker aborts when path is NULL", {
  local_mocked_bindings(
    getActiveDocumentContext = function() list(path = NULL),
    .package = "rstudioapi"
  )
  expect_error(detect_unmatched_nocov_marker(), "path")
})

test_that("detect_unmatched_nocov_marker resolves path from rstudioapi", {
  local_mocked_bindings(
    isAvailable = function() TRUE,
    getActiveDocumentContext = function() list(path = "/mock/file.R"),
    .package = "rstudioapi"
  )
  local_mocked_bindings(
    readLines = function(con, ...) {
      expect_equal(con, "/mock/file.R")
      character(0L)
    },
    .package = "base"
  )
  expect_true(detect_unmatched_nocov_marker())
})

test_that("file without markers returns TRUE", {
  file <- withr::local_tempfile(fileext = ".R")
  writeLines("f <- function() 1", file)
  expect_true(detect_unmatched_nocov_marker(file))
  expect_message(
    detect_unmatched_nocov_marker(file),
    "No `nocov` markers found",
    fixed = TRUE
  )
})

test_that("paired markers return TRUE", {
  file <- withr::local_tempfile(fileext = ".R")
  writeLines(c(marker_start, "a <- 1", marker_end), file)
  expect_true(detect_unmatched_nocov_marker(file))
  expect_message(
    detect_unmatched_nocov_marker(file),
    "All `nocov` markers are consistent",
    fixed = TRUE
  )
})

test_that("a file with only a nocov start marker is accepted", {
  file <- withr::local_tempfile(fileext = ".R")
  writeLines(c("a <- 1", marker_start, "b <- 2"), file)
  expect_true(detect_unmatched_nocov_marker(file))
  expect_message(
    detect_unmatched_nocov_marker(file),
    "unclosed `nocov start` marker at line 2",
    fixed = TRUE
  )
})

test_that("nocov end without nocov start returns FALSE with a position hint", {
  file <- withr::local_tempfile(fileext = ".R")
  writeLines(c("a <- 1", marker_end), file)
  expect_false(detect_unmatched_nocov_marker(file))
  expect_message(
    detect_unmatched_nocov_marker(file),
    "`nocov end` at line 2, column 1 has no matching `nocov start`",
    fixed = TRUE
  )
  # source line plus a caret line underlining the whole marker
  expect_message(
    detect_unmatched_nocov_marker(file),
    paste0(marker_end, "\n", strrep("^", nchar(marker_end))),
    fixed = TRUE
  )
})

test_that("every nocov start after the first is reported", {
  file <- withr::local_tempfile(fileext = ".R")
  writeLines(
    c(
      marker_start,
      "a <- 1",
      marker_start,
      "b <- 2",
      marker_start,
      "c <- 3"
    ),
    file
  )
  expect_false(detect_unmatched_nocov_marker(file))
  expect_message(
    detect_unmatched_nocov_marker(file),
    paste0(
      "`nocov start` at line 3, column 1: only one `nocov start` is allowed ",
      "per file, the first is `nocov start` at line 1, column 1."
    ),
    fixed = TRUE
  )
  expect_message(
    detect_unmatched_nocov_marker(file),
    paste0(
      "`nocov start` at line 5, column 1: only one `nocov start` is allowed ",
      "per file, the first is `nocov start` at line 1, column 1."
    ),
    fixed = TRUE
  )
  expect_message(
    detect_unmatched_nocov_marker(file),
    "Found 2 mismatched `nocov` markers on lines 3 and 5",
    fixed = TRUE
  )
})

test_that("every nocov end after the first is reported", {
  file <- withr::local_tempfile(fileext = ".R")
  writeLines(
    c(marker_start, "a <- 1", marker_end, "b <- 2", marker_end),
    file
  )
  expect_false(detect_unmatched_nocov_marker(file))
  expect_message(
    detect_unmatched_nocov_marker(file),
    paste0(
      "`nocov end` at line 5, column 1: only one `nocov end` is allowed ",
      "per file, the first is `nocov end` at line 3, column 1."
    ),
    fixed = TRUE
  )
})

test_that("nocov end before nocov start returns FALSE", {
  file <- withr::local_tempfile(fileext = ".R")
  writeLines(c(marker_end, "a <- 1", marker_start), file)
  expect_false(detect_unmatched_nocov_marker(file))
  expect_message(
    detect_unmatched_nocov_marker(file),
    paste0(
      "`nocov end` at line 1, column 1 comes before ",
      "`nocov start` at line 3, column 1."
    ),
    fixed = TRUE
  )
})

test_that("a nocov end after the start on the same line is accepted", {
  file <- withr::local_tempfile(fileext = ".R")
  writeLines(sprintf("a <- 1 # %s %s", marker_start, marker_end), file)
  expect_true(detect_unmatched_nocov_marker(file, verbose = FALSE))
})

test_that("several problems are all reported", {
  file <- withr::local_tempfile(fileext = ".R")
  writeLines(c(marker_end, "a <- 1", marker_end), file)
  expect_false(detect_unmatched_nocov_marker(file))
  expect_message(
    detect_unmatched_nocov_marker(file),
    "Found 2 mismatched `nocov` markers on lines 1 and 3",
    fixed = TRUE
  )
})

test_that("markers inside string literals are reported by design", {
  file <- withr::local_tempfile(fileext = ".R")
  writeLines(sprintf('x <- "%s"', marker_end), file)
  expect_false(detect_unmatched_nocov_marker(file))
  expect_message(
    detect_unmatched_nocov_marker(file),
    "`nocov end` at line 1",
    fixed = TRUE
  )
})

test_that("markers inside roxygen comments are reported by design", {
  file <- withr::local_tempfile(fileext = ".R")
  writeLines(c("#' @examples", paste0("#' ", marker_end)), file)
  expect_false(detect_unmatched_nocov_marker(file))
})

test_that("marker variants are recognised", {
  variant <- withr::local_tempfile(fileext = ".R")

  writeLines(c("## nocov start", "a <- 1", "## nocov end"), variant)
  expect_true(detect_unmatched_nocov_marker(variant, verbose = FALSE))

  writeLines(c("# NOCOV START", "a <- 1", "# NOCOV END"), variant)
  expect_true(detect_unmatched_nocov_marker(variant, verbose = FALSE))

  writeLines(c("  # nocov start  # reason", "a <- 1"), variant)
  expect_true(detect_unmatched_nocov_marker(variant, verbose = FALSE))
})

test_that("a bare nocov comment is not a marker", {
  file <- withr::local_tempfile(fileext = ".R")
  writeLines(c("a <- 1 # nocov", "b <- 2 # nocov startx"), file)
  expect_true(detect_unmatched_nocov_marker(file, verbose = FALSE))
})

test_that("verbose = FALSE stays silent", {
  file <- withr::local_tempfile(fileext = ".R")
  writeLines(c(marker_start, "a <- 1", marker_end), file)
  expect_silent(detect_unmatched_nocov_marker(file, verbose = FALSE))

  bad <- withr::local_tempfile(fileext = ".R")
  writeLines(marker_end, bad)
  expect_silent(detect_unmatched_nocov_marker(bad, verbose = FALSE))
})

test_that("detect_unmatched_nocov_marker returns invisibly", {
  file <- withr::local_tempfile(fileext = ".R")
  writeLines(marker_end, file)
  expect_invisible(detect_unmatched_nocov_marker(file))
})

test_that("detect_unmatched_nocov_marker rejects unused dots", {
  file <- withr::local_tempfile(fileext = ".R")
  writeLines("a <- 1", file)
  expect_error(detect_unmatched_nocov_marker(file, unused = TRUE))
})
