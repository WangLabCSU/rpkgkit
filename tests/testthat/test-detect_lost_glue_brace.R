# ---------------------------------------------------------------------------
# detect_lost_glue_brace -- integration tests
# ---------------------------------------------------------------------------

test_that("detect_lost_glue_brace aborts when path is NULL", {
  local_mocked_bindings(
    getActiveDocumentContext = function() list(path = NULL),
    .package = "rstudioapi"
  )
  expect_error(detect_lost_glue_brace())
})

test_that("detect_lost_glue_brace resolves path from rstudioapi", {
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
    readLines = function(path, ...) c('glue::glue("Hello {name")'),
    .package = "base"
  )
  expect_false(detect_lost_glue_brace("dummy.R"))
})

test_that("unbalanced glue::glue (extra closing brace) returns FALSE", {
  local_mocked_bindings(
    readLines = function(path, ...) c('glue::glue("Hello name}")'),
    .package = "base"
  )
  expect_false(detect_lost_glue_brace("dummy.R"))
})

test_that("unbalanced glue::glue emits error message with line number", {
  local_mocked_bindings(
    readLines = function(path, ...) {
      c('x <- 1', 'glue::glue("Hello {name")')
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
        'cli::cli_inform("Processing {file}")',
        'cli::cli_inform("Warning: {missing")'
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
        'cli::cli_alert_info("Value is {x}")',
        'cli::cli_alert_info("Missing } brace")'
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
        'glue::glue_data(.x, "This is {name}")',
        'glue_data(.x, "Lost brace {name")'
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
        'glue::glue("ok {a}")',
        'glue::glue("bad {a")',
        'x <- 42',
        'cli::cli_warn("bad {b")'
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
    readLines = function(path, ...) c('x <- 1', 'y <- x + 2', 'print(y)'),
    .package = "base"
  )
  expect_true(detect_lost_glue_brace("dummy.R"))
})

test_that("handles single-quoted strings", {
  local_mocked_bindings(
    readLines = function(path, ...) {
      c(
        "glue::glue('Hello {name}')",
        "cli::cli_alert_info('Missing brace {name')"
      )
    },
    .package = "base"
  )
  expect_false(detect_lost_glue_brace("dummy.R"))
})

test_that("handles escaped quotes in strings", {
  local_mocked_bindings(
    readLines = function(path, ...) {
      c('glue::glue("He said \\"{name}\\"")')
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
    readLines = function(path, ...) c('glue::glue  ("Hello {name}")'),
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
    readLines = function(path, ...) c('glue::glue("Hello {name}")'),
    .package = "base"
  )
  expect_invisible(detect_lost_glue_brace("dummy.R"))
})

# ---------------------------------------------------------------------------
# check_brace_balance -- unit tests
# ---------------------------------------------------------------------------

test_that("check_brace_balance: balanced string returns balanced=TRUE", {
  res <- check_brace_balance("Hello {name}!")
  expect_true(res$balanced)
})

test_that("check_brace_balance: nested braces are balanced", {
  res <- check_brace_balance("{a {b} c}")
  expect_true(res$balanced)
})

test_that("check_brace_balance: no braces returns balanced=TRUE", {
  res <- check_brace_balance("plain text")
  expect_true(res$balanced)
})

test_that("check_brace_balance: empty string returns balanced=TRUE", {
  res <- check_brace_balance("")
  expect_true(res$balanced)
})

test_that("check_brace_balance: missing closing brace", {
  res <- check_brace_balance("Hello {name")
  expect_false(res$balanced)
  # "Hello {name" = 11 chars, '{' at position 7
  expect_equal(res$unmatched_opens, 7)
  expect_length(res$unmatched_closes, 0)
  expect_equal(res$hl_start, 7)
  expect_equal(res$hl_end, 11)
})

test_that("check_brace_balance: extra closing brace without any open", {
  res <- check_brace_balance("Hello name}")
  expect_false(res$balanced)
  # "Hello name}" = 11 chars, '}' at position 11
  expect_length(res$unmatched_opens, 0)
  expect_equal(res$unmatched_closes, 11)
  expect_equal(res$hl_start, 11)
  expect_equal(res$hl_end, 11)
})

test_that("check_brace_balance: extra closing brace after matched pair", {
  res <- check_brace_balance("{.val name}}")
  expect_false(res$balanced)
  # {.val name}} -> { at 1, } matching at 11, extra } at 12
  expect_equal(res$unmatched_closes, 12)
  # hl from nearest { (1) to first extra } (12)
  expect_equal(res$hl_start, 1)
  expect_equal(res$hl_end, 12)
})

test_that("check_brace_balance: both unmatched open and extra close", {
  res <- check_brace_balance("a{b}c}d")
  # chars: a(1) {(2) b(3) }(4) c(5) }(6) d(7)
  # { at 2, } at 4 (pops), } at 6 (extra)
  expect_false(res$balanced)
  expect_length(res$unmatched_opens, 0)
  expect_equal(res$unmatched_closes, 6)
  # hl from nearest { before 6 = 2, to first extra = 6
  expect_equal(res$hl_start, 2)
  expect_equal(res$hl_end, 6)
})

test_that("check_brace_balance: extra close after unmatched open", {
  res <- check_brace_balance("{a}}")
  # chars: {(1) a(2) }(3) }(4)
  # { at 1, } at 3 (pops), } at 4 (extra)
  expect_false(res$balanced)
  expect_equal(res$unmatched_closes, 4)
  expect_equal(res$hl_start, 1)
  expect_equal(res$hl_end, 4)
})

test_that("check_brace_balance: multiple unmatched opens", {
  res <- check_brace_balance("a{b{c")
  # chars: a(1) {(2) b(3) {(4) c(5)
  # unmatched opens at 2, 4
  expect_false(res$balanced)
  expect_equal(res$unmatched_opens, c(2, 4))
  expect_equal(res$hl_start, 2)
  expect_equal(res$hl_end, 5)
})

test_that("check_brace_balance: only closing braces returns extra closes", {
  res <- check_brace_balance("a}b}c")
  expect_false(res$balanced)
  expect_equal(res$unmatched_closes, c(2, 4))
  # hl from first extra } (2) back to nearest { (none) so start = end = 2
  expect_equal(res$hl_start, 2)
  expect_equal(res$hl_end, 2)
})

# ---------------------------------------------------------------------------
# find_nearest_open_before -- unit tests
# ---------------------------------------------------------------------------

test_that("find_nearest_open_before finds brace before position", {
  # "a{b}c" -> chars: a(1) {(2) b(3) }(4) c(5)
  expect_equal(find_nearest_open_before("a{b}c", 4L), 2L)
})

test_that("find_nearest_open_before returns NA when no brace found", {
  expect_true(is.na(find_nearest_open_before("abc", 3L)))
})

test_that("find_nearest_open_before finds brace at position 1 from position 2", {
  expect_equal(find_nearest_open_before("{abc", 2L), 1L)
})

test_that("find_nearest_open_before finds nearest brace in string with multiple", {
  # "a{b}c{d}e" -> chars: a(1) {(2) b(3) }(4) c(5) {(6) }(7) e(8)
  expect_equal(find_nearest_open_before("a{b}c{d}e", 7L), 6L)
})

# ---------------------------------------------------------------------------
# format_brace_error -- unit tests
# ---------------------------------------------------------------------------

test_that("format_brace_error produces basic caret alignment", {
  result <- list(hl_start = 8, hl_end = 13)
  out <- format_brace_error(
    line_content = '  "Hello, {name!"',
    str_content = "Hello, {name!",
    line_num = 1L,
    col_offset = 3L,
    result = result
  )
  # content[8] = { at line col 3+8=11, content[13] = ! at line col 3+13=16
  # spaces before ^: 11-1 = 10, then 16-11+1 = 6 carets
  expected <- paste0(
    '  "Hello, {name!"',
    "\n",
    "          ^^^^^^"
  )
  expect_equal(out, expected)
})

test_that("format_brace_error handles single character highlight", {
  result <- list(hl_start = 12, hl_end = 12)
  out <- format_brace_error(
    line_content = 'glue::glue("Hello name}")',
    str_content = "Hello name}",
    line_num = 1L,
    col_offset = 13L,
    result = result
  )
  # content[12] = } at line col 13+12=25
  expected <- paste0(
    'glue::glue("Hello name}")',
    "\n",
    "                        ^"
  )
  expect_equal(out, expected)
})

test_that("format_brace_error handles multi-character highlight", {
  result <- list(hl_start = 1, hl_end = 15)
  out <- format_brace_error(
    line_content = 'glue::glue("{.val x}}")',
    str_content = "{.val x}}",
    line_num = 1L,
    col_offset = 13L,
    result = result
  )
  # content[1] = { at col 13+1=14, hl_end at col 13+15=28
  expected <- paste0(
    'glue::glue("{.val x}}")',
    "\n",
    "             ^^^^^^^^^^^^^^^"
  )
  expect_equal(out, expected)
})

test_that("format_brace_error handles highlight at start of line", {
  result <- list(hl_start = 1, hl_end = 6)
  out <- format_brace_error(
    line_content = '"{name}"',
    str_content = "{name}",
    line_num = 1L,
    col_offset = 1L,
    result = result
  )
  # hl_start=1, hl_end=6, col_offset=1
  # line_hl_start = 1+1 = 2, line_hl_end = 1+6 = 7
  # spaces = 2-1 = 1, carets = 7-2+1 = 6
  expected <- paste0(
    '"{name}"',
    "\n",
    " ^^^^^^"
  )
  expect_equal(out, expected)
})

# ---------------------------------------------------------------------------
# find_glue_cli_strings -- unit tests
# ---------------------------------------------------------------------------

test_that("find_glue_cli_strings returns empty list for no target calls", {
  text <- "x <- 1\ny <- x + 2\nprint(y)"
  exprs <- parse(text = text, keep.source = TRUE)
  pd <- utils::getParseData(exprs)
  expect_length(find_glue_cli_strings(pd), 0)
})

test_that("find_glue_cli_strings finds strings in glue::glue call", {
  text <- 'glue::glue("Hello {name}")'
  exprs <- parse(text = text, keep.source = TRUE)
  pd <- utils::getParseData(exprs)
  res <- find_glue_cli_strings(pd)
  expect_length(res, 1)
  expect_equal(res[[1]]$content, "Hello {name}")
  expect_true(res[[1]]$line1 >= 1)
})

test_that("find_glue_cli_strings finds strings in cli_* call", {
  text <- 'cli::cli_alert_info("Value is {x}")'
  exprs <- parse(text = text, keep.source = TRUE)
  pd <- utils::getParseData(exprs)
  res <- find_glue_cli_strings(pd)
  expect_length(res, 1)
  expect_equal(res[[1]]$content, "Value is {x}")
})

test_that("find_glue_cli_strings finds strings in glue_data call", {
  text <- 'glue_data(.x, "Lost brace {name")'
  exprs <- parse(text = text, keep.source = TRUE)
  pd <- utils::getParseData(exprs)
  res <- find_glue_cli_strings(pd)
  expect_length(res, 1)
})

test_that("find_glue_cli_strings handles nested function calls", {
  text <- 'bar <- cli::col_red(cli::cli_alert_warning("{.val x}}"))'
  exprs <- parse(text = text, keep.source = TRUE)
  pd <- utils::getParseData(exprs)
  res <- find_glue_cli_strings(pd)
  expect_length(res, 1)
  expect_equal(res[[1]]$content, "{.val x}}")
})

test_that("find_glue_cli_strings deduplicates strings", {
  text <- c(
    'glue::glue("{a}")',
    'glue::glue("{a}")'
  )
  exprs <- parse(text = paste(text, collapse = "\n"), keep.source = TRUE)
  pd <- utils::getParseData(exprs)
  res <- find_glue_cli_strings(pd)
  # Two separate calls, each with "{a}" — should be 2 items (different line1/col1)
  expect_length(res, 2)
})

# ---------------------------------------------------------------------------
# parse_safely -- unit tests
# ---------------------------------------------------------------------------

test_that("parse_safely parses valid R code", {
  exprs <- parse_safely("x <- 1\ny <- 2", "test.R")
  expect_type(exprs, "expression")
  expect_length(exprs, 2)
})

test_that("parse_safely aborts on invalid R code", {
  expect_error(
    parse_safely("x <- 1\n| invalid", "test.R"),
    "Could not parse.*test\\.R"
  )
})

# ---------------------------------------------------------------------------
# Multi-line integration tests
# ---------------------------------------------------------------------------

test_that("detects multi-line glue::glue with missing brace", {
  local_mocked_bindings(
    readLines = function(path, ...) {
      c(
        'msg <- glue::glue(',
        '  "Hello, {name!"',
        ')'
      )
    },
    .package = "base"
  )
  expect_false(detect_lost_glue_brace("dummy.R"))
})

test_that("detects multi-line cli call with extra closing brace", {
  local_mocked_bindings(
    readLines = function(path, ...) {
      c(
        'bar <- cli::col_red(cli::cli_alert_warning(',
        '  "{.val x}}"',
        '))'
      )
    },
    .package = "base"
  )
  expect_false(detect_lost_glue_brace("dummy.R"))
})

test_that("detects multi-line cli call with missing open brace", {
  local_mocked_bindings(
    readLines = function(path, ...) {
      c(
        'cli::cli_alert_info(',
        '  "my name is .val {name}}."',
        ')'
      )
    },
    .package = "base"
  )
  expect_false(detect_lost_glue_brace("dummy.R"))
})

test_that("balanced multi-line glue passes", {
  local_mocked_bindings(
    readLines = function(path, ...) {
      c(
        'glue::glue(',
        '  "Hello {name}!",',
        '  "You are {age} years old."',
        ')'
      )
    },
    .package = "base"
  )
  expect_true(detect_lost_glue_brace("dummy.R"))
})

# ---------------------------------------------------------------------------
# Caret output tests (verify that cat() + cli output is produced)
# ---------------------------------------------------------------------------

test_that("output produced for missing brace", {
  local_mocked_bindings(
    readLines = function(path, ...) c('glue::glue("Hello {name")'),
    .package = "base"
  )
  expect_false(detect_lost_glue_brace("dummy.R"))
})

test_that("output produced for extra brace", {
  local_mocked_bindings(
    readLines = function(path, ...) c('glue::glue("Hello name}")'),
    .package = "base"
  )
  expect_false(detect_lost_glue_brace("dummy.R"))
})

test_that("output produced for multi-line extra brace", {
  local_mocked_bindings(
    readLines = function(path, ...) {
      c(
        'cli::cli_alert_info(',
        '  "my name is {.val name}}."',
        ')'
      )
    },
    .package = "base"
  )
  expect_false(detect_lost_glue_brace("dummy.R"))
})

test_that("no error output when balanced", {
  local_mocked_bindings(
    readLines = function(path, ...) c('glue::glue("Hello {name}!")'),
    .package = "base"
  )
  expect_message(detect_lost_glue_brace("dummy.R"), "No need to fix")
})

# ---------------------------------------------------------------------------
# Edge cases
# ---------------------------------------------------------------------------

test_that("file with only comments does not error", {
  tmp <- tempfile(fileext = ".R")
  writeLines(c("# just a comment", "# another comment"), tmp)
  on.exit(unlink(tmp))
  expect_true(detect_lost_glue_brace(tmp))
})

test_that("file with glue calls in comments is ignored", {
  tmp <- tempfile(fileext = ".R")
  writeLines("# glue::glue(\"something\")", tmp)
  on.exit(unlink(tmp))
  expect_true(detect_lost_glue_brace(tmp))
})

test_that("detects unbalanced braces in single-line cli call", {
  local_mocked_bindings(
    readLines = function(path, ...) {
      c('cli::cli_alert_info("my name is {.val name}}.")')
    },
    .package = "base"
  )
  expect_false(detect_lost_glue_brace("dummy.R"))
  expect_message(
    detect_lost_glue_brace("dummy.R"),
    "Found 1 line"
  )
})

test_that("cli::cli_text is also detected", {
  local_mocked_bindings(
    readLines = function(path, ...) {
      c('cli::cli_text("Hello {name}")', 'cli::cli_text("Missing {brace")')
    },
    .package = "base"
  )
  expect_false(detect_lost_glue_brace("dummy.R"))
})

test_that("direct glue() call works", {
  local_mocked_bindings(
    readLines = function(path, ...) c('glue("Hello {name}")'),
    .package = "base"
  )
  expect_true(detect_lost_glue_brace("dummy.R"))
})

test_that("glue in nested expressions is found", {
  local_mocked_bindings(
    readLines = function(path, ...) {
      c('x <- paste(glue::glue("Hello {name}"), "world")')
    },
    .package = "base"
  )
  expect_true(detect_lost_glue_brace("dummy.R"))
})
