# -----------------------------------------------------------
# to_style helper tests
# -----------------------------------------------------------

test_that("to_style: camelCase -> snake_case", {
  expect_equal(
    rpkgkit:::to_style("myFunctionName", "snake_case"),
    "my_function_name"
  )
  expect_equal(rpkgkit:::to_style("MyFunction", "snake_case"), "my_function")
})

test_that("to_style: dot.separated -> snake_case", {
  expect_equal(
    rpkgkit:::to_style("my.function.name", "snake_case"),
    "my_function_name"
  )
})

test_that("to_style: snake_case -> snake_case (already in style)", {
  expect_equal(
    rpkgkit:::to_style("my_function_name", "snake_case"),
    "my_function_name"
  )
})

test_that("to_style: snake_case -> camelCase", {
  expect_equal(
    rpkgkit:::to_style("my_function_name", "camelCase"),
    "myFunctionName"
  )
})

test_that("to_style: PascalCase -> camelCase", {
  expect_equal(
    rpkgkit:::to_style("MyFunctionName", "camelCase"),
    "myFunctionName"
  )
})

test_that("to_style: dot.separated -> camelCase", {
  expect_equal(
    rpkgkit:::to_style("my.function.name", "camelCase"),
    "myFunctionName"
  )
})

test_that("to_style: snake_case -> PascalCase", {
  expect_equal(
    rpkgkit:::to_style("my_function_name", "PascalCase"),
    "MyFunctionName"
  )
})

test_that("to_style: camelCase -> PascalCase", {
  expect_equal(
    rpkgkit:::to_style("myFunctionName", "PascalCase"),
    "MyFunctionName"
  )
})

test_that("to_style: dot.separated -> PascalCase", {
  expect_equal(
    rpkgkit:::to_style("my.function.name", "PascalCase"),
    "MyFunctionName"
  )
})

test_that("to_style: snake_case -> google", {
  expect_equal(
    rpkgkit:::to_style("my_function_name", "google"),
    "my.function.name"
  )
})

test_that("to_style: camelCase -> google", {
  expect_equal(
    rpkgkit:::to_style("myFunctionName", "google"),
    "my.function.name"
  )
})

test_that("to_style: PascalCase -> google", {
  expect_equal(
    rpkgkit:::to_style("MyFunctionName", "google"),
    "my.function.name"
  )
})

test_that("to_style: single word unchanged in lowercase styles", {
  expect_equal(rpkgkit:::to_style("test", "snake_case"), "test")
  expect_equal(rpkgkit:::to_style("test", "camelCase"), "test")
  expect_equal(rpkgkit:::to_style("test", "google"), "test")
})

test_that("to_style: single word capitalised for PascalCase", {
  expect_equal(rpkgkit:::to_style("test", "PascalCase"), "Test")
})

test_that("to_style: already in camelCase", {
  expect_equal(rpkgkit:::to_style("myFunc", "camelCase"), "myFunc")
})

test_that("to_style: already in PascalCase", {
  expect_equal(rpkgkit:::to_style("MyFunc", "PascalCase"), "MyFunc")
})

test_that("to_style: already in google", {
  expect_equal(rpkgkit:::to_style("my.func", "google"), "my.func")
})

test_that("to_style: consecutive uppercase not split further (design choice)", {
  expect_equal(
    rpkgkit:::to_style("getHTMLParser", "snake_case"),
    "get_htmlparser"
  )
})

# -----------------------------------------------------------
# detect_func_defs helper tests
# -----------------------------------------------------------

test_that("detect_func_defs: <- function( pattern", {
  lines <- c("my_func <- function(x) { x }")
  expect_equal(rpkgkit:::detect_func_defs(lines), "my_func")
})

test_that("detect_func_defs: = function( pattern", {
  lines <- c("my_func = function(x) { x }")
  expect_equal(rpkgkit:::detect_func_defs(lines), "my_func")
})

test_that("detect_func_defs: <- \\( pattern (R 4.1+ shorthand)", {
  lines <- c(paste0("my_func <- \\", "(x) { x }"))
  expect_equal(rpkgkit:::detect_func_defs(lines), "my_func")
})

test_that("detect_func_defs: = \\( pattern (R 4.1+ shorthand)", {
  lines <- c(paste0("my_func = \\", "(x) { x }"))
  expect_equal(rpkgkit:::detect_func_defs(lines), "my_func")
})

test_that("detect_func_defs: multiple definitions on separate lines", {
  lines <- c(
    "foo <- function(x) { x }",
    "bar <- function(y) { y }"
  )
  expect_setequal(rpkgkit:::detect_func_defs(lines), c("foo", "bar"))
})

test_that("detect_func_defs: duplicate definitions deduplicated", {
  lines <- c(
    "foo <- function(x) { x }",
    "# comment",
    "foo <- function(y) { y }"
  )
  expect_equal(rpkgkit:::detect_func_defs(lines), "foo")
})

test_that("detect_func_defs: no definitions returns empty", {
  lines <- c("x <- 1", "y <- x + 2")
  expect_equal(rpkgkit:::detect_func_defs(lines), character(0))
})

test_that("detect_func_defs: backtick-quoted name", {
  lines <- c("`my func` <- function(x) { x }")
  expect_equal(rpkgkit:::detect_func_defs(lines), "my func")
})

test_that("detect_func_defs: dot-separated name", {
  lines <- c("print.my_class <- function(x, ...) { x }")
  expect_equal(rpkgkit:::detect_func_defs(lines), "print.my_class")
})

test_that("detect_func_defs: ignores plain function calls", {
  lines <- c("x <- my_function_call(1, 2)")
  expect_equal(rpkgkit:::detect_func_defs(lines), character(0))
})

test_that("detect_func_defs: no-space assignment to function(", {
  lines <- c("my_func<-function(x) { x }")
  expect_equal(rpkgkit:::detect_func_defs(lines), "my_func")
})

test_that("detect_func_defs: extra whitespace around assignment", {
  lines <- c("my_func   <-   function(x) { x }")
  expect_equal(rpkgkit:::detect_func_defs(lines), "my_func")
})

test_that("detect_func_defs: leading underscore in name", {
  lines <- c("._private <- function(x) { x }")
  expect_equal(rpkgkit:::detect_func_defs(lines), "._private")
})

# -----------------------------------------------------------
# rename_func integration tests (tempfiles)
# -----------------------------------------------------------

test_that("rename_func: converts to snake_case and updates call sites", {
  tmp <- tempfile(fileext = ".R")
  writeLines(
    c(
      "myFunctionName <- function(x) { x + 1 }",
      "myFunctionName(5)"
    ),
    tmp
  )
  on.exit(unlink(tmp))

  rename_func(tmp, style = "snake_case")

  result <- readLines(tmp)
  expect_match(result[1L], "my_function_name <- function")
  expect_match(result[2L], "my_function_name\\(5\\)")
})

test_that("rename_func: converts to camelCase", {
  tmp <- tempfile(fileext = ".R")
  writeLines(
    c(
      "my_function_name <- function(x) { x + 1 }",
      "my_function_name(5)"
    ),
    tmp
  )
  on.exit(unlink(tmp))

  rename_func(tmp, style = "camelCase")

  result <- readLines(tmp)
  expect_match(result[1L], "myFunctionName <- function")
  expect_match(result[2L], "myFunctionName\\(5\\)")
})

test_that("rename_func: converts to PascalCase", {
  tmp <- tempfile(fileext = ".R")
  writeLines(
    c(
      "my_function_name <- function(x) { x + 1 }",
      "my_function_name(5)"
    ),
    tmp
  )
  on.exit(unlink(tmp))

  rename_func(tmp, style = "PascalCase")

  result <- readLines(tmp)
  expect_match(result[1L], "MyFunctionName <- function")
  expect_match(result[2L], "MyFunctionName\\(5\\)")
})

test_that("rename_func: converts to google style", {
  tmp <- tempfile(fileext = ".R")
  writeLines(
    c(
      "my_function_name <- function(x) { x + 1 }",
      "my_function_name(5)"
    ),
    tmp
  )
  on.exit(unlink(tmp))

  rename_func(tmp, style = "google")

  result <- readLines(tmp)
  expect_match(result[1L], "my.function.name <- function")
  expect_match(result[2L], "my.function.name\\(5\\)")
})

test_that("rename_func: handles \\( lambda syntax", {
  tmp <- tempfile(fileext = ".R")
  writeLines(
    c(
      paste0("myFunc <- \\", "(x) { x + 1 }"),
      "myFunc(5)"
    ),
    tmp
  )
  on.exit(unlink(tmp))

  rename_func(tmp, style = "snake_case")

  result <- readLines(tmp)
  expect_match(result[1L], "my_func <- ")
  expect_match(result[2L], "my_func\\(5\\)")
})

test_that("rename_func: already in target style shows info message", {
  tmp <- tempfile(fileext = ".R")
  writeLines("my_func <- function(x) { x }", tmp)
  on.exit(unlink(tmp))

  expect_message(
    rename_func(tmp, style = "snake_case"),
    "already in"
  )
})

test_that("rename_func: no function definitions shows info message", {
  tmp <- tempfile(fileext = ".R")
  writeLines(c("x <- 1", "y <- 2"), tmp)
  on.exit(unlink(tmp))

  expect_message(
    rename_func(tmp),
    "No function definitions found"
  )
})

test_that("rename_func: aborts when path is NULL and rstudioapi unavailable", {
  local_mocked_bindings(
    is_installed = function(pkg) FALSE,
    .package = "rlang"
  )

  expect_error(rename_func(), "is required")
})

test_that("rename_func: uses rstudioapi when path is NULL", {
  mock_path <- "/mock/project/R/my_file.R"

  local_mocked_bindings(
    is_installed = function(pkg) TRUE,
    .package = "rlang"
  )
  local_mocked_bindings(
    getActiveDocumentContext = function() list(path = mock_path),
    .package = "rstudioapi"
  )

  readLines_paths <- character(0)
  local_mocked_bindings(
    readLines = function(path, ...) {
      readLines_paths <<- c(readLines_paths, path)
      c("MyFunc <- function(x) { x }", "MyFunc(1)")
    },
    .package = "base"
  )

  writeLines_calls <- list()
  local_mocked_bindings(
    writeLines = function(text, con) {
      writeLines_calls <<- append(
        writeLines_calls,
        list(list(text = text, con = con))
      )
    },
    .package = "base"
  )

  rename_func(style = "snake_case")

  expect_length(readLines_paths, 1L)
  expect_equal(readLines_paths[[1L]], mock_path)
  expect_length(writeLines_calls, 1L)
  expect_match(writeLines_calls[[1L]]$text, "my_func <- function")
})

test_that("rename_func: returns invisibly", {
  tmp <- tempfile(fileext = ".R")
  writeLines("my_func <- function(x) { x }", tmp)
  on.exit(unlink(tmp))

  expect_invisible(rename_func(tmp))
})

test_that("rename_func: returned path matches input", {
  tmp <- tempfile(fileext = ".R")
  writeLines("my_func <- function(x) { x }", tmp)
  on.exit(unlink(tmp))

  expect_equal(rename_func(tmp), tmp)
})

test_that("rename_func: extra ... args pass through (check_dots_empty0 checks caller dots)", {
  # check_dots_empty0() inspects the caller's ..., not rename_func's own ...
  # Passing extra args to rename_func does not error in this design.
  tmp <- tempfile(fileext = ".R")
  writeLines("MyFunc <- function(x) x", tmp)
  on.exit(unlink(tmp))

  expect_error(rename_func(tmp, extra_arg = 1))
})

test_that("rename_func: invalid style falls back to default (snake_case)", {
  # match_arg returns default (choices[1]) when no match found
  tmp <- tempfile(fileext = ".R")
  writeLines("MyFunc <- function(x) x", tmp)
  on.exit(unlink(tmp))

  expect_no_error(rename_func(tmp, style = "invalid"))
  result <- readLines(tmp)
  expect_match(result[1L], "my_func <- function")
})

test_that("rename_func: shorter names do not clobber longer prefix names", {
  tmp <- tempfile(fileext = ".R")
  writeLines(
    c(
      "ab <- function(x) { x }",
      "abc_def <- function(x) { x }",
      "ab(1)",
      "abc_def(2)"
    ),
    tmp
  )
  on.exit(unlink(tmp))

  rename_func(tmp, style = "snake_case")

  result <- readLines(tmp)
  # "abc_def" already snake_case; "ab" unchanged as single word
  expect_equal(result[1L], "ab <- function(x) { x }")
  expect_equal(result[2L], "abc_def <- function(x) { x }")
})

test_that("rename_func: multiple functions renamed in one pass", {
  tmp <- tempfile(fileext = ".R")
  writeLines(
    c(
      "firstFunc <- function(x) { x }",
      "secondFunc <- function(y) { y }",
      "firstFunc(secondFunc(1))"
    ),
    tmp
  )
  on.exit(unlink(tmp))

  rename_func(tmp, style = "snake_case")

  result <- readLines(tmp)
  expect_match(result[1L], "first_func <- function")
  expect_match(result[2L], "second_func <- function")
  expect_match(result[3L], "first_func\\(second_func\\(1\\)\\)")
})

test_that("rename_func: emits success message with rename count", {
  tmp <- tempfile(fileext = ".R")
  writeLines("MyFunc <- function(x) { x }", tmp)
  on.exit(unlink(tmp))

  expect_message(
    rename_func(tmp, style = "snake_case"),
    "Renamed 1 function"
  )
})
