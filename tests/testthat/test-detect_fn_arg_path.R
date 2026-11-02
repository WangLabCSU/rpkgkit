# ---------------------------------------------------------------------------
# detect_fn_arg_path() / scan_fn_arg_path() / report_fn_arg_hits()
# ---------------------------------------------------------------------------

test_that("detect_fn_arg_path returns TRUE when no default path is found", {
  file <- withr::local_tempfile(
    lines = c(
      "read_it <- function(path = NULL, n = 1) NULL",
      "write_it <- function(x, file) NULL"
    ),
    fileext = ".R"
  )

  expect_true(detect_fn_arg_path(file, verbose = FALSE))
})

test_that("detect_fn_arg_path flags a default path and returns FALSE", {
  file <- withr::local_tempfile(
    lines = 'read_it <- function(path = "~/data.csv", n = 1) NULL',
    fileext = ".R"
  )

  expect_false(detect_fn_arg_path(file, verbose = FALSE))
})

test_that("scan_fn_arg_path records fn, arg, default and position", {
  file <- withr::local_tempfile(
    lines = 'read_it <- function(n = 1, path = "~/data.csv") NULL',
    fileext = ".R"
  )

  hits <- scan_fn_arg_path(file, arg_pattern = "path|file|filename")$hits

  expect_length(hits, 1L)
  expect_equal(hits[[1L]]$fn, "read_it")
  expect_equal(hits[[1L]]$arg, "path")
  expect_equal(hits[[1L]]$default, '"~/data.csv"')
  expect_equal(hits[[1L]]$line1, 1L)
  expect_equal(hits[[1L]]$col1, 28L)
})

test_that("scan_fn_arg_path keeps an argument without default clean", {
  file <- withr::local_tempfile(
    lines = "read_it <- function(path, n = 1) NULL",
    fileext = ".R"
  )

  expect_length(scan_fn_arg_path(file, arg_pattern = "path")$hits, 0L)
})

test_that("scan_fn_arg_path honours the allow list", {
  file <- withr::local_tempfile(
    lines = c(
      'a <- function(path = NULL) NULL',
      'b <- function(path = ".") NULL'
    ),
    fileext = ".R"
  )

  hits <- scan_fn_arg_path(
    file,
    arg_pattern = "path",
    allow = c("NULL", '"."')
  )$hits
  expect_length(hits, 0L)

  hits <- scan_fn_arg_path(file, arg_pattern = "path", allow = "NULL")$hits
  expect_length(hits, 1L)
  expect_equal(hits[[1L]]$fn, "b")
})

test_that("scan_fn_arg_path only checks the requested exports", {
  file <- withr::local_tempfile(
    lines = c(
      'exported <- function(path = "a") NULL',
      'internal <- function(path = "b") NULL'
    ),
    fileext = ".R"
  )

  hits <- scan_fn_arg_path(
    file,
    arg_pattern = "path",
    exports = "external"
  )$hits
  expect_length(hits, 0L)

  hits <- scan_fn_arg_path(
    file,
    arg_pattern = "path",
    exports = c("internal")
  )$hits
  expect_length(hits, 1L)
  expect_equal(hits[[1L]]$fn, "internal")
})

test_that("scan_fn_arg_path supports export_patterns", {
  file <- withr::local_tempfile(
    lines = c(
      'read_data <- function(path = "a") NULL',
      'write_data <- function(path = "b") NULL'
    ),
    fileext = ".R"
  )

  hits <- scan_fn_arg_path(
    file,
    arg_pattern = "path",
    export_patterns = "^read_"
  )$hits
  expect_length(hits, 1L)
  expect_equal(hits[[1L]]$fn, "read_data")
})

test_that("scan_fn_arg_path skips functions that are not top-level", {
  file <- withr::local_tempfile(
    lines = c(
      "wrapper <- function() {",
      '  inner <- function(path = "~/x") NULL',
      "  inner()",
      "}"
    ),
    fileext = ".R"
  )

  expect_length(scan_fn_arg_path(file, arg_pattern = "path")$hits, 0L)
})

test_that("scan_fn_arg_path reports the whole multi-line default", {
  file <- withr::local_tempfile(
    lines = c(
      "read_it <- function(",
      "  path = c(",
      '    "a",',
      '    "b"',
      "  )",
      ") NULL"
    ),
    fileext = ".R"
  )

  hits <- scan_fn_arg_path(file, arg_pattern = "path")$hits
  expect_length(hits, 1L)
  expect_match(hits[[1L]]$default, "^c\\(")
  expect_equal(hits[[1L]]$line1, 2L)
  expect_gt(hits[[1L]]$line2, hits[[1L]]$line1)
})

test_that("scan_fn_arg_path aborts for a missing file", {
  missing_file <- file.path(withr::local_tempdir(), "nope.R")

  expect_error(
    scan_fn_arg_path(missing_file, arg_pattern = "path"),
    "does not exist"
  )
})

test_that("detect_fn_arg_path matches arg_pattern unanchored by default", {
  # `profile` contains `file`, so it is matched by the default pattern
  file <- withr::local_tempfile(
    lines = 'load_it <- function(profile = "~/p") NULL',
    fileext = ".R"
  )

  expect_false(detect_fn_arg_path(file, verbose = FALSE))
  expect_length(
    scan_fn_arg_path(file, arg_pattern = "path|file|filename")$hits,
    1L
  )
  expect_length(
    scan_fn_arg_path(file, arg_pattern = "^(path|file|filename)$")$hits,
    0L
  )
})

test_that("detect_fn_arg_path aborts when path cannot be resolved", {
  local_mocked_bindings(
    isAvailable = function(...) FALSE,
    .package = "rstudioapi"
  )

  expect_error(detect_fn_arg_path(), "required")
})

test_that("detect_fn_arg_path aborts when the active document has no path", {
  local_mocked_bindings(
    isAvailable = function(...) TRUE,
    getActiveDocumentContext = function(...) list(path = ""),
    .package = "rstudioapi"
  )

  expect_error(detect_fn_arg_path(), "required")
})

test_that("detect_fn_arg_path uses the active document when path is NULL", {
  file <- withr::local_tempfile(
    lines = 'read_it <- function(path = "~/data.csv") NULL',
    fileext = ".R"
  )
  local_mocked_bindings(
    isAvailable = function(...) TRUE,
    getActiveDocumentContext = function(...) list(path = file),
    .package = "rstudioapi"
  )

  expect_false(detect_fn_arg_path(verbose = FALSE))
})

test_that("detect_fn_arg_path errors on non-empty dots", {
  file <- withr::local_tempfile(
    lines = "read_it <- function(path) NULL",
    fileext = ".R"
  )

  expect_error(detect_fn_arg_path(file, unused = 1), class = "rlang_error")
})

test_that("detect_fn_arg_path is quiet when verbose is FALSE", {
  file <- withr::local_tempfile(
    lines = c(
      'bad <- function(path = "~/x") NULL',
      'good <- function(path = NULL) NULL'
    ),
    fileext = ".R"
  )

  expect_silent(detect_fn_arg_path(file, verbose = FALSE))
})

test_that("detect_fn_arg_path reports hits on the console", {
  file <- withr::local_tempfile(
    lines = 'read_it <- function(path = "~/x.csv") NULL',
    fileext = ".R"
  )

  expect_message(detect_fn_arg_path(file), "Found 1 argument")
})

test_that("report_fn_arg_hits prints the source line and a caret marker", {
  file <- withr::local_tempfile(
    lines = 'read_it <- function(path = "~/x.csv") NULL',
    fileext = ".R"
  )
  scanned <- scan_fn_arg_path(file, arg_pattern = "path")

  out <- paste(
    capture.output(
      report_fn_arg_hits(file, scanned$lines, scanned$hits),
      type = "message"
    ),
    collapse = "\n"
  )

  expect_match(out, "read_it\\(\\).*path", all = FALSE)
  expect_match(out, "read_it <- function\\(path = ", all = FALSE)
  expect_match(out, "\\^+")
})

test_that("report_fn_arg_hits strips the root from the shown path", {
  dir <- withr::local_tempdir()
  file <- file.path(dir, "read.R")
  writeLines('read_it <- function(path = "~/x.csv") NULL', file)
  scanned <- scan_fn_arg_path(file, arg_pattern = "path")

  out <- paste(
    capture.output(
      report_fn_arg_hits(file, scanned$lines, scanned$hits, root = dir),
      type = "message"
    ),
    collapse = "\n"
  )

  expect_match(out, "'read\\.R':1:21", all = FALSE)
  expect_false(grepl(dir, out, fixed = TRUE))
})

test_that("report_fn_arg_hits returns NULL invisibly", {
  file <- withr::local_tempfile(
    lines = 'read_it <- function(path = "~/x.csv") NULL',
    fileext = ".R"
  )
  scanned <- scan_fn_arg_path(file, arg_pattern = "path")

  expect_invisible(report_fn_arg_hits(file, scanned$lines, scanned$hits))
})
