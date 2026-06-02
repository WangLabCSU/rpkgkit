test_that("detect_lost_glue_brace aborts when path is NULL and rstudioapi unavailable", {
  local_mocked_bindings(
    is_installed = function(pkg) FALSE,
    .package = "rlang"
  )

  expect_error(
    detect_lost_glue_brace(),
    "is required"
  )
})

test_that("detect_lost_glue_brace resolves path from rstudioapi", {
  local_mocked_bindings(
    is_installed = function(pkg) TRUE,
    .package = "rlang"
  )
  local_mocked_bindings(
    getActiveDocumentContext = function() list(path = "/mock/file.R"),
    .package = "rstudioapi"
  )
  local_mocked_bindings(
    readLines = function(path, ...) {
      expect_equal(path, "/mock/file.R")
      character(0)
    },
    .package = "base"
  )

  expect_true(detect_lost_glue_brace())
})

test_that("balanced glue::glue returns TRUE with success message", {
  local_mocked_bindings(
    readLines = function(path, ...) {
      c(
        'msg <- "Hello World"',
        'glue::glue("This is a msg: {msg}")',
        'glue::glue("{name} is {age} years old.")'
      )
    },
    .package = "base"
  )

  expect_true(detect_lost_glue_brace("dummy.R"))
})

test_that("balanced glue::glue emits 'No need to fix' message", {
  local_mocked_bindings(
    readLines = function(path, ...) {
      c(
        'glue::glue("Hello {name}")',
        'glue::glue("{a} + {b} = {c}")'
      )
    },
    .package = "base"
  )

  expect_message(
    detect_lost_glue_brace("dummy.R"),
    "No need to fix"
  )
})

test_that("unbalanced glue::glue (missing closing brace) returns FALSE", {
  local_mocked_bindings(
    readLines = function(path, ...) {
      c(
        'glue::glue("Hello {name")'
      )
    },
    .package = "base"
  )

  expect_false(detect_lost_glue_brace("dummy.R"))
})

test_that("unbalanced glue::glue (extra closing brace) returns FALSE", {
  local_mocked_bindings(
    readLines = function(path, ...) {
      c(
        'glue::glue("Hello name}")'
      )
    },
    .package = "base"
  )

  expect_false(detect_lost_glue_brace("dummy.R"))
})

test_that("unbalanced glue::glue emits error message with line number", {
  local_mocked_bindings(
    readLines = function(path, ...) {
      c(
        'x <- 1',
        'glue::glue("Hello {name")'
      )
    },
    .package = "base"
  )

  expect_message(
    detect_lost_glue_brace("dummy.R"),
    "Found 1 line.*mismatched braces.*2"
  )
})

test_that("detects unbalanced cli::cli_inform brace", {
  local_mocked_bindings(
    readLines = function(path, ...) {
      c(
        'cli::cli_inform("Processing {file}")', # line 1 - balanced
        'cli::cli_inform("Warning: {missing")' # line 2 - unbalanced
      )
    },
    .package = "base"
  )

  expect_false(detect_lost_glue_brace("dummy.R"))
})

test_that("detects unbalanced cli::cli_alert_info brace", {
  local_mocked_bindings(
    readLines = function(path, ...) {
      c(
        'cli::cli_alert_info("Value is {x}")', # balanced
        'cli::cli_alert_info("Missing } brace")' # unbalanced: extra }
      )
    },
    .package = "base"
  )

  expect_false(detect_lost_glue_brace("dummy.R"))
})

test_that("detects unbalanced glue_data brace", {
  local_mocked_bindings(
    readLines = function(path, ...) {
      c(
        'glue::glue_data(.x, "This is {name}")', # line 1 - balanced
        'glue_data(.x, "Lost brace {name")' # line 2 - unbalanced
      )
    },
    .package = "base"
  )

  expect_false(detect_lost_glue_brace("dummy.R"))
})

test_that("reports multiple error lines", {
  local_mocked_bindings(
    readLines = function(path, ...) {
      c(
        'glue::glue("ok {a}")', # line 1 - balanced
        'glue::glue("bad {a")', # line 2 - unbalanced
        'x <- 42', # line 3 - no glue
        'cli::cli_warn("bad {b")' # line 4 - unbalanced
      )
    },
    .package = "base"
  )

  expect_message(
    detect_lost_glue_brace("dummy.R"),
    "Found 2 lines.*mismatched braces.*2.*4"
  )
  expect_false(detect_lost_glue_brace("dummy.R"))
})

test_that("no glue or cli calls returns TRUE", {
  local_mocked_bindings(
    readLines = function(path, ...) {
      c(
        'x <- 1',
        'y <- x + 2',
        'print(y)'
      )
    },
    .package = "base"
  )

  expect_true(detect_lost_glue_brace("dummy.R"))
})

test_that("handles single-quoted strings", {
  local_mocked_bindings(
    readLines = function(path, ...) {
      c(
        "glue::glue('Hello {name}')", # balanced
        "cli::cli_alert_info('Missing brace {name')" # unbalanced
      )
    },
    .package = "base"
  )

  expect_false(detect_lost_glue_brace("dummy.R"))
})

test_that("handles escaped quotes in strings", {
  local_mocked_bindings(
    readLines = function(path, ...) {
      c(
        'glue::glue("He said \\"{name}\\"")' # balanced: {name} has both braces
      )
    },
    .package = "base"
  )

  expect_true(detect_lost_glue_brace("dummy.R"))
})

test_that("empty file returns TRUE", {
  local_mocked_bindings(
    readLines = function(path, ...) character(0),
    .package = "base"
  )

  expect_true(detect_lost_glue_brace("empty.R"))
})

test_that("glue::glue( with spaces before parenthesis matches", {
  local_mocked_bindings(
    readLines = function(path, ...) {
      c(
        'glue::glue  ("Hello {name}")' # balanced
      )
    },
    .package = "base"
  )

  expect_true(detect_lost_glue_brace("dummy.R"))
})

test_that("passes explicit path to readLines", {
  tmp <- tempfile(fileext = ".R")
  writeLines('glue::glue("ok")', tmp)
  on.exit(unlink(tmp))

  expect_true(detect_lost_glue_brace(tmp))
})

test_that("returns invisibly", {
  local_mocked_bindings(
    readLines = function(path, ...) {
      c(
        'glue::glue("Hello {name}")'
      )
    },
    .package = "base"
  )

  expect_invisible(detect_lost_glue_brace("dummy.R"))
})
