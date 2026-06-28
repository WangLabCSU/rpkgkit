# ---------------------------------------------------------------------------
# detect_print_and_cat -- integration tests
# ---------------------------------------------------------------------------

test_that("detect_print_and_cat resolves path from rstudioapi when NULL", {
  local_mocked_bindings(
    getActiveDocumentContext = function() list(path = "/mock/file.R"),
    .package = "rstudioapi"
  )
  local_mocked_bindings(
    readLines = function(con, ...) {
      expect_equal(con, "/mock/file.R")
      character(0)
    },
    .package = "base"
  )
  expect_true(detect_print_and_cat())
})

test_that("detect_print_and_cat handles double colons", {
  local_mocked_bindings(
    readLines = function(con, ...) {
      c('x <- 1', 'base::print(x)', 'base::cat("done\\n")')
    },
    .package = "base"
  )
  expect_message(
    detect_print_and_cat("dummy.R"),
    "print\\(x\\)"
  )
})

test_that("no print or cat calls returns TRUE with success message", {
  local_mocked_bindings(
    readLines = function(con, ...) {
      c('msg <- "Hello World"', 'message(msg)')
    },
    .package = "base"
  )
  expect_true(detect_print_and_cat("dummy.R"))
})

test_that("reports line numbers via caret messages", {
  local_mocked_bindings(
    readLines = function(con, ...) {
      c('x <- 1', 'print(x)', 'cat("done\\n")')
    },
    .package = "base"
  )
  expect_message(
    detect_print_and_cat("dummy.R"),
    "print\\(x\\)"
  )
})

test_that("detects print() call", {
  local_mocked_bindings(
    readLines = function(con, ...) c('print("hello")'),
    .package = "base"
  )
  expect_false(detect_print_and_cat("dummy.R"))
})

test_that("detects cat() call", {
  local_mocked_bindings(
    readLines = function(con, ...) c('cat("world\\n")'),
    .package = "base"
  )
  expect_false(detect_print_and_cat("dummy.R"))
})

test_that("detects both print() and cat() on same line", {
  local_mocked_bindings(
    readLines = function(con, ...) c('print(x); cat("ok\\n")'),
    .package = "base"
  )
  expect_false(detect_print_and_cat("dummy.R"))
})

test_that("detects calls on multiple lines", {
  local_mocked_bindings(
    readLines = function(con, ...) {
      c('x <- 1', 'print(x)', 'cat("done\\n")')
    },
    .package = "base"
  )
  expect_false(detect_print_and_cat("dummy.R"))
})

test_that("reports line numbers in caret messages", {
  local_mocked_bindings(
    readLines = function(con, ...) {
      c('x <- 1', 'print(x)', 'cat("done\\n")')
    },
    .package = "base"
  )
  expect_message(
    detect_print_and_cat("dummy.R"),
    "print\\(x\\)"
  )
  expect_message(
    detect_print_and_cat("dummy.R"),
    'cat\\("done'
  )
})

test_that("not fooled by sprintf or print.myclass", {
  local_mocked_bindings(
    readLines = function(con, ...) {
      c('sprintf("hello %s", name)', 'print.myclass(x)')
    },
    .package = "base"
  )
  expect_true(detect_print_and_cat("dummy.R"))
})

test_that("print passed as function reference is detected", {
  local_mocked_bindings(
    readLines = function(con, ...) 'lapply(1:3, print)',
    .package = "base"
  )
  expect_false(detect_print_and_cat("dummy.R"))
})

test_that("empty file returns TRUE", {
  local_mocked_bindings(
    readLines = function(con, ...) character(0),
    .package = "base"
  )
  expect_true(detect_print_and_cat("empty.R"))
})

test_that("returns invisibly", {
  local_mocked_bindings(
    readLines = function(con, ...) c('print("hi")'),
    .package = "base"
  )
  expect_invisible(detect_print_and_cat("dummy.R"))
})

test_that("file with only comments passes", {
  tmp <- withr::local_tempfile(fileext = ".R")
  writeLines(c("# just a comment", "# another one"), tmp)
  expect_true(detect_print_and_cat(tmp))
})

test_that("file with print/call in comments is ignored", {
  tmp <- withr::local_tempfile(fileext = ".R")
  writeLines(c("# print(\"hello\")", "# cat(\"world\")"), tmp)
  expect_true(detect_print_and_cat(tmp))
})

# ---------------------------------------------------------------------------
# fix = TRUE
# ---------------------------------------------------------------------------

test_that("fix = TRUE replaces print() with message() in file", {
  tmp <- withr::local_tempfile(fileext = ".R")
  writeLines('print("hello")', tmp)

  expect_message(
    detect_print_and_cat(tmp, fix = TRUE),
    "Fixed 1 line"
  )

  expect_equal(readLines(tmp, warn = FALSE), 'message("hello")')
})

test_that("fix = TRUE replaces cat() with message() in file", {
  tmp <- withr::local_tempfile(fileext = ".R")
  writeLines('cat("world\\n")', tmp)

  expect_message(
    detect_print_and_cat(tmp, fix = TRUE),
    "Fixed 1 line"
  )

  expect_equal(readLines(tmp, warn = FALSE), 'message("world\\n")')
})

test_that("fix = TRUE replaces multiple calls on different lines", {
  tmp <- withr::local_tempfile(fileext = ".R")
  writeLines(c('print("a")', 'cat("b\\n")'), tmp)

  expect_message(
    detect_print_and_cat(tmp, fix = TRUE),
    "Fixed 2 lines"
  )

  expect_equal(
    readLines(tmp, warn = FALSE),
    c('message("a")', 'message("b\\n")')
  )
})

test_that("fix = TRUE does not change clean file", {
  tmp <- withr::local_tempfile(fileext = ".R")
  writeLines('message("ok")', tmp)

  expect_true(detect_print_and_cat(tmp, fix = TRUE))
  expect_equal(readLines(tmp, warn = FALSE), 'message("ok")')
})

test_that("fix reports original code, not replaced code", {
  tmp <- withr::local_tempfile(fileext = ".R")
  writeLines('print("hello")', tmp)

  expect_message(
    detect_print_and_cat(tmp, fix = TRUE),
    'print\\("hello"\\)'
  )
})

test_that("fix emits success message with file name", {
  local_mocked_bindings(
    readLines = function(con, ...) c('print("hello")'),
    .package = "base"
  )
  local_mocked_bindings(
    writeLines = function(text, con) {
      expect_equal(text, 'message("hello")')
      expect_equal(con, "dummy.R")
    },
    .package = "base"
  )
  detect_print_and_cat("dummy.R", fix = TRUE)
})

# ---------------------------------------------------------------------------
# find_print_cat_calls -- unit tests
# ---------------------------------------------------------------------------

test_that("find_print_cat_calls returns empty list for empty parse data", {
  expect_length(find_print_cat_calls(data.frame()), 0)
})

test_that("find_print_cat_calls returns empty list when no target calls", {
  text <- "x <- 1\ny <- x + 2\nmessage(y)"
  exprs <- parse(text = text, keep.source = TRUE)
  pd <- utils::getParseData(exprs)
  expect_length(find_print_cat_calls(pd), 0)
})

test_that("find_print_cat_calls finds print() call", {
  text <- 'print("hello")'
  exprs <- parse(text = text, keep.source = TRUE)
  pd <- utils::getParseData(exprs)
  res <- find_print_cat_calls(pd)
  expect_length(res, 1)
  expect_equal(res[[1]]$text, "print")
  expect_equal(res[[1]]$line1, 1)
})

test_that("find_print_cat_calls finds cat() call", {
  text <- 'cat("world\\n")'
  exprs <- parse(text = text, keep.source = TRUE)
  pd <- utils::getParseData(exprs)
  res <- find_print_cat_calls(pd)
  expect_length(res, 1)
  expect_equal(res[[1]]$text, "cat")
})

test_that("find_print_cat_calls finds both print and cat", {
  text <- 'print("a")\ncat("b\\n")'
  exprs <- parse(text = text, keep.source = TRUE)
  pd <- utils::getParseData(exprs)
  res <- find_print_cat_calls(pd)
  expect_length(res, 2)
  expect_setequal(vapply(res, `[[`, character(1), "text"), c("print", "cat"))
})

test_that("find_print_cat_calls ignores sprintf and print.myclass", {
  text <- 'sprintf("hello %s", name)\nprint.myclass(x)'
  exprs <- parse(text = text, keep.source = TRUE)
  pd <- utils::getParseData(exprs)
  expect_length(find_print_cat_calls(pd), 0)
})

test_that("find_print_cat_calls detects print inside nested call", {
  text <- 'try(print(x), silent = TRUE)'
  exprs <- parse(text = text, keep.source = TRUE)
  pd <- utils::getParseData(exprs)
  res <- find_print_cat_calls(pd)
  expect_length(res, 1)
  expect_equal(res[[1]]$text, "print")
})

# ---------------------------------------------------------------------------
# package_print_and_cat -- tests
# ---------------------------------------------------------------------------

test_that("package_print_and_cat aborts when path is not a package", {
  expect_error(
    package_print_and_cat(tempdir()),
    "is not an R package"
  )
})

test_that("package_print_and_cat returns TRUE for empty package", {
  pkg <- withr::local_tempdir()
  dir.create(file.path(pkg, "R"), recursive = TRUE)
  writeLines(
    c("Package: testpkg", "Version: 0.0.1"),
    file.path(pkg, "DESCRIPTION")
  )

  expect_true(package_print_and_cat(pkg))
})

test_that("package_print_and_cat detects print() in R/ files", {
  pkg <- withr::local_tempdir()
  dir.create(file.path(pkg, "R"), recursive = TRUE)
  writeLines('print("debug")', file.path(pkg, "R", "foo.R"))
  writeLines(
    c("Package: testpkg", "Version: 0.0.1"),
    file.path(pkg, "DESCRIPTION")
  )

  expect_false(package_print_and_cat(pkg))
})

test_that("package_print_and_cat detects cat() in test files", {
  pkg <- withr::local_tempdir()
  dir.create(file.path(pkg, "R"), recursive = TRUE)
  dir.create(file.path(pkg, "tests", "testthat"), recursive = TRUE)
  writeLines('cat("debug\\n")', file.path(pkg, "tests", "testthat", "test-a.R"))
  writeLines(
    c("Package: testpkg", "Version: 0.0.1"),
    file.path(pkg, "DESCRIPTION")
  )

  expect_false(package_print_and_cat(pkg))
})

test_that("package_print_and_cat with test_included = FALSE skips tests", {
  pkg <- withr::local_tempdir()
  dir.create(file.path(pkg, "R"), recursive = TRUE)
  dir.create(file.path(pkg, "tests", "testthat"), recursive = TRUE)
  writeLines('cat("debug\\n")', file.path(pkg, "tests", "testthat", "test-a.R"))
  writeLines(
    c("Package: testpkg", "Version: 0.0.1"),
    file.path(pkg, "DESCRIPTION")
  )

  expect_true(package_print_and_cat(pkg, test_included = FALSE))
})

test_that("package_print_and_cat returns invisibly", {
  pkg <- withr::local_tempdir()
  dir.create(file.path(pkg, "R"), recursive = TRUE)
  writeLines('print("debug")', file.path(pkg, "R", "foo.R"))
  writeLines(
    c("Package: testpkg", "Version: 0.0.1"),
    file.path(pkg, "DESCRIPTION")
  )

  expect_invisible(package_print_and_cat(pkg))
})

test_that("package_print_and_cat with fix = TRUE replaces print in files", {
  pkg <- withr::local_tempdir()
  dir.create(file.path(pkg, "R"), recursive = TRUE)
  writeLines('print("debug")', file.path(pkg, "R", "foo.R"))
  writeLines(
    c("Package: testpkg", "Version: 0.0.1"),
    file.path(pkg, "DESCRIPTION")
  )

  package_print_and_cat(pkg, fix = TRUE)
  expect_equal(
    readLines(file.path(pkg, "R", "foo.R"), warn = FALSE),
    'message("debug")'
  )
})

test_that("package_print_and_cat with fix = TRUE fixes multiple files", {
  pkg <- withr::local_tempdir()
  dir.create(file.path(pkg, "R"), recursive = TRUE)
  writeLines('print("a")', file.path(pkg, "R", "foo.R"))
  writeLines('cat("b\\n")', file.path(pkg, "R", "bar.R"))
  writeLines(
    c("Package: testpkg", "Version: 0.0.1"),
    file.path(pkg, "DESCRIPTION")
  )

  package_print_and_cat(pkg, fix = TRUE)
  expect_equal(
    readLines(file.path(pkg, "R", "foo.R"), warn = FALSE),
    'message("a")'
  )
  expect_equal(
    readLines(file.path(pkg, "R", "bar.R"), warn = FALSE),
    'message("b\\n")'
  )
})

test_that("package_print_and_cat reports multiple files with issues", {
  pkg <- withr::local_tempdir()
  dir.create(file.path(pkg, "R"), recursive = TRUE)
  writeLines('print("debug")', file.path(pkg, "R", "foo.R"))
  writeLines('message("ok")', file.path(pkg, "R", "bar.R"))
  writeLines('cat("bad\\n")', file.path(pkg, "R", "baz.R"))
  writeLines(
    c("Package: testpkg", "Version: 0.0.1"),
    file.path(pkg, "DESCRIPTION")
  )

  expect_false(package_print_and_cat(pkg))
})

# ---------------------------------------------------------------------------
# scan_file_print_cat -- unit tests
# ---------------------------------------------------------------------------

test_that("scan_file_print_cat returns ok=TRUE for clean file", {
  tmp <- withr::local_tempfile(fileext = ".R")
  writeLines('message("ok")', tmp)

  res <- scan_file_print_cat(tmp)
  expect_true(res$ok)
  expect_length(res$errors, 0)
})

test_that("scan_file_print_cat returns ok=FALSE for file with print()", {
  tmp <- withr::local_tempfile(fileext = ".R")
  writeLines('print("bad")', tmp)

  res <- scan_file_print_cat(tmp)
  expect_false(res$ok)
  expect_length(res$errors, 1)
  expect_equal(res$errors[[1]]$line, 1)
})

test_that("scan_file_print_cat with fix = TRUE modifies file", {
  tmp <- withr::local_tempfile(fileext = ".R")
  writeLines('cat("bad\\n")', tmp)

  scan_file_print_cat(tmp, fix = TRUE)
  expect_equal(readLines(tmp, warn = FALSE), 'message("bad\\n")')
})

test_that("scan_file_print_cat error uses original line content", {
  tmp <- withr::local_tempfile(fileext = ".R")
  writeLines('print("bad")', tmp)

  res <- scan_file_print_cat(tmp, fix = TRUE)
  expect_match(res$errors[[1]]$caret, "print", fixed = TRUE)
  expect_match(res$errors[[1]]$caret, "bad", fixed = TRUE)
  expect_no_match(res$errors[[1]]$caret, "message", fixed = TRUE)
})
