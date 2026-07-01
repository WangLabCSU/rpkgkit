# ---------------------------------------------------------------------------
# .cfs_find_matching_paren -- internal unit tests
# ---------------------------------------------------------------------------

test_that(".cfs_find_matching_paren: simple case (x) returns close pos", {
  chars <- strsplit("function(x) x + 1", NULL)[[1L]]
  # "(" is at position 9 (0-indexed... no, 1-indexed: f(1) u(2) n(3) c(4) t(5)
  # i(6) o(7) n(8) ((9) x(10) )(11) ...
  open_pos <- which(chars == "(")[[1L]]
  close <- rpkgkit:::.cfs_find_matching_paren(chars, open_pos)
  expect_equal(close, which(chars == ")")[[1L]])
})

test_that(".cfs_find_matching_paren: nested parens", {
  chars <- strsplit("(a(b)c)", NULL)[[1L]]
  # "(a(b)c)": positions: (1 a2 (3 b4 )5 c6 )7
  close <- rpkgkit:::.cfs_find_matching_paren(chars, 1L)
  expect_equal(close, 7L)
})

test_that(".cfs_find_matching_paren: deeply nested parens", {
  chars <- strsplit("(((())))", NULL)[[1L]]
  close <- rpkgkit:::.cfs_find_matching_paren(chars, 1L)
  expect_equal(close, 8L)
})

test_that(".cfs_find_matching_paren: returns NA if no match", {
  chars <- strsplit("(abc", NULL)[[1L]]
  expect_true(is.na(rpkgkit:::.cfs_find_matching_paren(chars, 1L)))
})

test_that(".cfs_find_matching_paren: from inner open position", {
  chars <- strsplit("a(b(c)d)e", NULL)[[1L]]
  # Inner ( at position 4
  inner_open <- which(chars == "(")[[2L]]
  close <- rpkgkit:::.cfs_find_matching_paren(chars, inner_open)
  expect_equal(chars[close], ")")
  expect_true(close > inner_open)
})

test_that(".cfs_find_matching_paren: empty parens", {
  chars <- strsplit("()", NULL)[[1L]]
  close <- rpkgkit:::.cfs_find_matching_paren(chars, 1L)
  expect_equal(close, 2L)
})

# ---------------------------------------------------------------------------
# .cfs_process_text_once -- to_lambda direction
# ---------------------------------------------------------------------------

test_that(".cfs_process_text_once: to_lambda converts simple function()", {
  text <- "add <- function(x) x + 1"
  res <- rpkgkit:::.cfs_process_text_once(text, "to_lambda")
  expect_equal(res, "add <- \\(x) x + 1")
})

test_that(".cfs_process_text_once: to_lambda converts function with no args", {
  text <- "hello <- function() 'world'"
  res <- rpkgkit:::.cfs_process_text_once(text, "to_lambda")
  expect_equal(res, "hello <- \\() 'world'")
})

test_that(".cfs_process_text_once: to_lambda converts function with multiple args", {
  text <- "add <- function(x, y) x + y"
  res <- rpkgkit:::.cfs_process_text_once(text, "to_lambda")
  expect_equal(res, "add <- \\(x, y) x + y")
})

test_that(".cfs_process_text_once: to_lambda converts function with default args", {
  text <- "greet <- function(name = 'World') paste('Hello', name)"
  res <- rpkgkit:::.cfs_process_text_once(text, "to_lambda")
  expect_equal(res, "greet <- \\(name = 'World') paste('Hello', name)")
})

test_that(".cfs_process_text_once: to_lambda handles nested parens in defaults", {
  text <- "f <- function(x = foo(bar(y))) x"
  res <- rpkgkit:::.cfs_process_text_once(text, "to_lambda")
  expect_equal(res, "f <- \\(x = foo(bar(y))) x")
})

test_that(".cfs_process_text_once: to_lambda converts multiple functions", {
  text <- "add <- function(x, y) x + y\nmul <- function(x, y) x * y"
  res <- rpkgkit:::.cfs_process_text_once(text, "to_lambda")
  expect_equal(res, "add <- \\(x, y) x + y\nmul <- \\(x, y) x * y")
})

test_that(".cfs_process_text_once: to_lambda ignores function in strings", {
  text <- "x <- 'function(y) hello'"
  res <- rpkgkit:::.cfs_process_text_once(text, "to_lambda")
  expect_equal(res, text)
})

test_that(".cfs_process_text_once: to_lambda ignores function in comments", {
  text <- "# using function(x) here"
  res <- rpkgkit:::.cfs_process_text_once(text, "to_lambda")
  expect_equal(res, text)
})

test_that(".cfs_process_text_once: to_lambda handles escaped quotes in strings", {
  text <- "x <- 'he said \\'function(y) hi\\''"
  res <- rpkgkit:::.cfs_process_text_once(text, "to_lambda")
  expect_equal(res, text)
})

test_that(".cfs_process_text_once: to_lambda handles double-quoted strings", {
  text <- '"function(x) not real"'
  res <- rpkgkit:::.cfs_process_text_once(text, "to_lambda")
  expect_equal(res, text)
})

test_that(".cfs_process_text_once: to_lambda function keyword at start of text", {
  text <- "function(x) x + 1"
  res <- rpkgkit:::.cfs_process_text_once(text, "to_lambda")
  expect_equal(res, "\\(x) x + 1")
})

test_that(".cfs_process_text_once: to_lambda function after newline", {
  text <- "x <- 1\nfunction(x) x + 1"
  res <- rpkgkit:::.cfs_process_text_once(text, "to_lambda")
  expect_equal(res, "x <- 1\n\\(x) x + 1")
})

test_that(".cfs_process_text_once: to_lambda no function unchanged", {
  text <- "x <- 1\ny <- 2"
  res <- rpkgkit:::.cfs_process_text_once(text, "to_lambda")
  expect_equal(res, text)
})

test_that(".cfs_process_text_once: to_lambda handles whitespace between function and (", {
  text <- "f <- function  (x) x"
  res <- rpkgkit:::.cfs_process_text_once(text, "to_lambda")
  expect_equal(res, "f <- \\(x) x")
})

test_that(".cfs_process_text_once: to_lambda handles newline between function and (", {
  text <- "f <- function\n(x) x"
  res <- rpkgkit:::.cfs_process_text_once(text, "to_lambda")
  expect_equal(res, "f <- \\(x) x")
})

test_that(".cfs_process_text_once: to_lambda ignores function without paren", {
  text <- "x <- function_name"
  res <- rpkgkit:::.cfs_process_text_once(text, "to_lambda")
  expect_equal(res, text)
})

test_that(".cfs_process_text_once: to_lambda function with body containing parens", {
  text <- "f <- function(x) if (x > 0) x else -x"
  res <- rpkgkit:::.cfs_process_text_once(text, "to_lambda")
  expect_equal(res, "f <- \\(x) if (x > 0) x else -x")
})

test_that(".cfs_process_text_once: to_lambda function in comment after real one", {
  text <- "f <- function(x) x # old: function(y) y"
  res <- rpkgkit:::.cfs_process_text_once(text, "to_lambda")
  expect_equal(res, "f <- \\(x) x # old: function(y) y")
})

# ---------------------------------------------------------------------------
# .cfs_process_text_once -- to_explicit direction
# ---------------------------------------------------------------------------

test_that(".cfs_process_text_once: to_explicit converts simple lambda", {
  text <- "add <- \\(x) x + 1"
  res <- rpkgkit:::.cfs_process_text_once(text, "to_explicit")
  expect_equal(res, "add <- function(x) x + 1")
})

test_that(".cfs_process_text_once: to_explicit converts lambda with no args", {
  text <- "hello <- \\() 'world'"
  res <- rpkgkit:::.cfs_process_text_once(text, "to_explicit")
  expect_equal(res, "hello <- function() 'world'")
})

test_that(".cfs_process_text_once: to_explicit converts lambda with multiple args", {
  text <- "add <- \\(x, y) x + y"
  res <- rpkgkit:::.cfs_process_text_once(text, "to_explicit")
  expect_equal(res, "add <- function(x, y) x + y")
})

test_that(".cfs_process_text_once: to_explicit converts lambda with default args", {
  text <- "greet <- \\(name = 'World') paste('Hello', name)"
  res <- rpkgkit:::.cfs_process_text_once(text, "to_explicit")
  expect_equal(res, "greet <- function(name = 'World') paste('Hello', name)")
})

test_that(".cfs_process_text_once: to_explicit handles nested parens in defaults", {
  text <- "f <- \\(x = foo(bar(y))) x"
  res <- rpkgkit:::.cfs_process_text_once(text, "to_explicit")
  expect_equal(res, "f <- function(x = foo(bar(y))) x")
})

test_that(".cfs_process_text_once: to_explicit converts multiple lambdas", {
  text <- "add <- \\(x, y) x + y\nmul <- \\(x, y) x * y"
  res <- rpkgkit:::.cfs_process_text_once(text, "to_explicit")
  expect_equal(res, "add <- function(x, y) x + y\nmul <- function(x, y) x * y")
})

test_that(".cfs_process_text_once: to_explicit ignores backslash in strings", {
  text <- "x <- 'this is \\\\ not a lambda'"
  res <- rpkgkit:::.cfs_process_text_once(text, "to_explicit")
  expect_equal(res, text)
})

test_that(".cfs_process_text_once: to_explicit ignores backslash in comments", {
  text <- "# \\\\(x) is not real"
  res <- rpkgkit:::.cfs_process_text_once(text, "to_explicit")
  expect_equal(res, text)
})

test_that(".cfs_process_text_once: to_explicit lambda at start of text", {
  text <- "\\(x) x + 1"
  res <- rpkgkit:::.cfs_process_text_once(text, "to_explicit")
  expect_equal(res, "function(x) x + 1")
})

test_that(".cfs_process_text_once: to_explicit no lambda unchanged", {
  text <- "x <- 1\ny <- 2"
  res <- rpkgkit:::.cfs_process_text_once(text, "to_explicit")
  expect_equal(res, text)
})

test_that(".cfs_process_text_once: to_explicit ignores backslash not followed by paren", {
  text <- "x <- \\name"
  res <- rpkgkit:::.cfs_process_text_once(text, "to_explicit")
  expect_equal(res, text)
})

# ---------------------------------------------------------------------------
# .cfs_process_text_once -- edge cases
# ---------------------------------------------------------------------------

test_that(".cfs_process_text_once: handles mixed string and code in to_lambda", {
  text <- "'hidden function(x) real' function(y) y"
  res <- rpkgkit:::.cfs_process_text_once(text, "to_lambda")
  expect_equal(res, "'hidden function(x) real' \\(y) y")
})

test_that(".cfs_process_text_once: handles mixed string and code in to_explicit", {
  text <- "'hidden \\\\(x) real' \\(y) y"
  res <- rpkgkit:::.cfs_process_text_once(text, "to_explicit")
  expect_equal(res, "'hidden \\\\(x) real' function(y) y")
})

test_that(".cfs_process_text_once: escape within string does not end string", {
  text <- '"she said: \\\"hello\\\""'
  res <- rpkgkit:::.cfs_process_text_once(text, "to_lambda")
  expect_equal(res, text)
})

test_that(".cfs_process_text_once: empty text unchanged", {
  res <- rpkgkit:::.cfs_process_text_once("", "to_lambda")
  expect_equal(res, "")
})

test_that(".cfs_process_text_once: only string unchanged", {
  text <- '"just a string with function(x) inside"'
  res <- rpkgkit:::.cfs_process_text_once(text, "to_lambda")
  expect_equal(res, text)
})

# ---------------------------------------------------------------------------
# .cfs_transform_text -- iterative multi-pass transformation
# ---------------------------------------------------------------------------

test_that(".cfs_transform_text: nested function defs fully converted", {
  text <- "f <- function(x, g = function(y) y) g(x)"
  res <- rpkgkit:::.cfs_transform_text(text, "to_lambda")
  expect_equal(res, "f <- \\(x, g = \\(y) y) g(x)")
})

test_that(".cfs_transform_text: deep nesting fully converted", {
  text <- "a <- function(x) function(y) function(z) x + y + z"
  res <- rpkgkit:::.cfs_transform_text(text, "to_lambda")
  expect_equal(res, "a <- \\(x) \\(y) \\(z) x + y + z")
})

test_that(".cfs_transform_text: nested lambdas to explicit", {
  text <- "f <- \\(x, g = \\(y) y) g(x)"
  res <- rpkgkit:::.cfs_transform_text(text, "to_explicit")
  expect_equal(res, "f <- function(x, g = function(y) y) g(x)")
})

test_that(".cfs_transform_text: no function unchanged", {
  text <- "x <- 1\ny <- 2"
  res <- rpkgkit:::.cfs_transform_text(text, "to_lambda")
  expect_equal(res, text)
})

test_that(".cfs_transform_text: mixed nested and unnested", {
  text <- "f <- function(x) x\ng <- function(y, h = function(z) z) h(y)"
  res <- rpkgkit:::.cfs_transform_text(text, "to_lambda")
  expect_equal(res, "f <- \\(x) x\ng <- \\(y, h = \\(z) z) h(y)")
})

# ---------------------------------------------------------------------------
# convert_func_syntax -- integration tests
# ---------------------------------------------------------------------------

test_that("convert_func_syntax aborts when path is NULL without RStudio", {
  local_mocked_bindings(
    getActiveDocumentContext = function() list(path = NULL),
    .package = "rstudioapi"
  )
  # Also mock is_installed so we don't enter the rstudioapi branch
  local_mocked_bindings(
    is_installed = function(pkg, ...) FALSE,
    .package = "rlang"
  )
  expect_error(convert_func_syntax(path = NULL), "path.*required")
})

test_that("convert_func_syntax resolves path from rstudioapi when path=NULL", {
  local_mocked_bindings(
    getActiveDocumentContext = function() list(path = "/mock/file.R"),
    .package = "rstudioapi"
  )
  local_mocked_bindings(
    readLines = function(path, ...) {
      expect_equal(path, "/mock/file.R")
      "x <- 1"
    },
    .package = "base"
  )
  local_mocked_bindings(
    writeLines = function(text, path, ...) invisible(),
    .package = "base"
  )
  expect_error(convert_func_syntax(path = NULL))
})

test_that("convert_func_syntax: check_dots_empty0 inspects caller dots, not own ...", {
  # check_dots_empty0() inspects the caller's ..., not convert_func_syntax's own
  # ..., so passing extra args to convert_func_syntax does not error.
  local_mocked_bindings(
    readLines = function(path, ...) c("f <- function(x) x"),
    .package = "base"
  )
  local_mocked_bindings(
    writeLines = function(text, path, ...) invisible(),
    .package = "base"
  )
  expect_message(
    convert_func_syntax(path = "dummy.R", direction = "to_lambda", 42),
    "Converted"
  )
})

test_that("convert_func_syntax: to_lambda converts and writes file", {
  tmp <- tempfile(fileext = ".R")
  writeLines("add_one <- function(x) x + 1", tmp)
  on.exit(unlink(tmp))

  convert_func_syntax(tmp, direction = "to_lambda")
  expect_equal(readLines(tmp), "add_one <- \\(x) x + 1")
})

test_that("convert_func_syntax: to_explicit converts and writes file", {
  tmp <- tempfile(fileext = ".R")
  writeLines("add_one <- \\(x) x + 1", tmp)
  on.exit(unlink(tmp))

  convert_func_syntax(tmp, direction = "to_explicit")
  expect_equal(readLines(tmp), "add_one <- function(x) x + 1")
})

test_that("convert_func_syntax: emits success message on conversion", {
  tmp <- tempfile(fileext = ".R")
  writeLines("add_one <- function(x) x + 1", tmp)
  on.exit(unlink(tmp))

  expect_message(
    convert_func_syntax(tmp, direction = "to_lambda"),
    "Converted.*to_lambda"
  )
})

test_that("convert_func_syntax: emits info when no functions to convert", {
  tmp <- tempfile(fileext = ".R")
  writeLines("x <- 1\ny <- 2", tmp)
  on.exit(unlink(tmp))

  expect_message(
    convert_func_syntax(tmp, direction = "to_lambda"),
    "No function definitions to convert"
  )
})

test_that("convert_func_syntax: returns invisible path", {
  tmp <- tempfile(fileext = ".R")
  writeLines("add_one <- function(x) x + 1", tmp)
  on.exit(unlink(tmp))

  expect_invisible(convert_func_syntax(tmp, direction = "to_lambda"))
  res <- convert_func_syntax(tmp, direction = "to_lambda")
  expect_equal(res, tmp)
})

test_that("convert_func_syntax: roundtrip to_lambda -> to_explicit is identity", {
  tmp <- tempfile(fileext = ".R")
  original <- c(
    "add <- function(x, y) x + y",
    "mul <- function(x, y) x * y"
  )
  writeLines(original, tmp)
  on.exit(unlink(tmp))

  convert_func_syntax(tmp, direction = "to_lambda")
  convert_func_syntax(tmp, direction = "to_explicit")
  expect_equal(readLines(tmp), original)
})

test_that("convert_func_syntax: roundtrip to_explicit -> to_lambda is identity", {
  tmp <- tempfile(fileext = ".R")
  original <- "add <- \\(x, y) x + y"
  writeLines(original, tmp)
  on.exit(unlink(tmp))

  convert_func_syntax(tmp, direction = "to_explicit")
  convert_func_syntax(tmp, direction = "to_lambda")
  expect_equal(readLines(tmp), original)
})

test_that("convert_func_syntax: handles nested functions in file", {
  tmp <- tempfile(fileext = ".R")
  writeLines("f <- function(x, g = function(y) y) g(x)", tmp)
  on.exit(unlink(tmp))

  convert_func_syntax(tmp, direction = "to_lambda")
  expect_equal(readLines(tmp), "f <- \\(x, g = \\(y) y) g(x)")
})

test_that("convert_func_syntax: handles deep nesting in file", {
  tmp <- tempfile(fileext = ".R")
  writeLines("a <- function(x) function(y) function(z) x + y + z", tmp)
  on.exit(unlink(tmp))

  convert_func_syntax(tmp, direction = "to_lambda")
  expect_equal(readLines(tmp), "a <- \\(x) \\(y) \\(z) x + y + z")
})

test_that("convert_func_syntax: does not modify strings or comments", {
  tmp <- tempfile(fileext = ".R")
  lines <- c(
    "# old style: function(x) x",
    "x <- 'function is not real'",
    "real <- function(x) x + 1"
  )
  writeLines(lines, tmp)
  on.exit(unlink(tmp))

  convert_func_syntax(tmp, direction = "to_lambda")
  result <- readLines(tmp)
  expect_match(result[1L], "old style: function\\(x\\) x")
  expect_match(result[2L], "function is not real")
  expect_equal(result[3L], "real <- \\(x) x + 1")
})

test_that("convert_func_syntax: handles file with only comments", {
  tmp <- tempfile(fileext = ".R")
  writeLines(c("# just a comment", "# another comment"), tmp)
  on.exit(unlink(tmp))

  expect_message(
    convert_func_syntax(tmp, direction = "to_lambda"),
    "No function definitions to convert"
  )
})

test_that("convert_func_syntax: handles empty file", {
  tmp <- tempfile(fileext = ".R")
  writeLines(character(0), tmp)
  on.exit(unlink(tmp))

  expect_message(
    convert_func_syntax(tmp, direction = "to_lambda"),
    "No function definitions to convert"
  )
})

test_that("convert_func_syntax: explicit path takes precedence", {
  tmp <- tempfile(fileext = ".R")
  writeLines("f <- function(x) x", tmp)
  on.exit(unlink(tmp))

  convert_func_syntax(tmp, direction = "to_lambda")
  expect_equal(readLines(tmp), "f <- \\(x) x")
})

test_that("convert_func_syntax: multi-line function with defaults", {
  tmp <- tempfile(fileext = ".R")
  lines <- c(
    "my_func <- function(",
    "  x = 1,",
    "  y = foo(bar(z))",
    ") {",
    "  x + y",
    "}"
  )
  writeLines(lines, tmp)
  on.exit(unlink(tmp))

  convert_func_syntax(tmp, direction = "to_lambda")
  result <- readLines(tmp)
  # Check that "function(" became "\(" and nested parens preserved
  expect_false(any(grepl("function", result)))
  expect_match(result[1L], "my_func <- \\(", fixed = TRUE)
})

test_that("convert_func_syntax: to_explicit converts file with lambdas", {
  tmp <- tempfile(fileext = ".R")
  lines <- c(
    "f <- \\(x) x + 1",
    "g <- \\(y) y * 2"
  )
  writeLines(lines, tmp)
  on.exit(unlink(tmp))

  convert_func_syntax(tmp, direction = "to_explicit")
  result <- readLines(tmp)
  expect_equal(result[1L], "f <- function(x) x + 1")
  expect_equal(result[2L], "g <- function(y) y * 2")
})

test_that("convert_func_syntax: does not modify file when already in target form", {
  tmp <- tempfile(fileext = ".R")
  writeLines("f <- \\(x) x + 1", tmp)
  on.exit(unlink(tmp))

  expect_message(
    convert_func_syntax(tmp, direction = "to_lambda"),
    "No function definitions to convert"
  )
  expect_equal(readLines(tmp), "f <- \\(x) x + 1")
})

test_that("convert_func_syntax: does not modify file with no changes in to_explicit", {
  tmp <- tempfile(fileext = ".R")
  writeLines("f <- function(x) x + 1", tmp)
  on.exit(unlink(tmp))

  expect_message(
    convert_func_syntax(tmp, direction = "to_explicit"),
    "No function definitions to convert"
  )
  expect_equal(readLines(tmp), "f <- function(x) x + 1")
})

test_that("convert_func_syntax: warning about direction partial matching", {
  tmp <- tempfile(fileext = ".R")
  writeLines("f <- function(x) x + 1", tmp)
  on.exit(unlink(tmp))

  # match.arg allows partial matching by default, so "to_l" matches "to_lambda"
  expect_message(
    convert_func_syntax(tmp, direction = "to_lambda"),
    "Converted"
  )
})
