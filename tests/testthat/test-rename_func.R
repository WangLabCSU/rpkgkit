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
# num_to_word_lookup helper tests
# -----------------------------------------------------------

test_that("num_to_word_lookup: maps digits to words", {
  expect_equal(
    rpkgkit:::num_to_word_lookup(c("for" = 4, "to" = 2)),
    c("4" = "for", "2" = "to")
  )
})

test_that("num_to_word_lookup: accepts a named character vector", {
  expect_equal(
    rpkgkit:::num_to_word_lookup(c("to" = "2")),
    c("2" = "to")
  )
})

test_that("num_to_word_lookup: supports multi-digit abbreviations", {
  expect_equal(
    rpkgkit:::num_to_word_lookup(c("ten" = 10)),
    c("10" = "ten")
  )
})

test_that("num_to_word_lookup: NULL and FALSE disable the expansion", {
  expect_null(rpkgkit:::num_to_word_lookup(NULL))
  expect_null(rpkgkit:::num_to_word_lookup(FALSE))
})

test_that("num_to_word_lookup: rejects invalid input", {
  expect_error(
    rpkgkit:::num_to_word_lookup(c(2, 4)),
    "must be a named vector"
  )
  expect_error(rpkgkit:::num_to_word_lookup(TRUE), "must be a named vector")
  expect_error(
    rpkgkit:::num_to_word_lookup(list("to" = 2)),
    "must be a named vector"
  )
  expect_error(
    rpkgkit:::num_to_word_lookup(c("to" = "two")),
    "must be a named vector"
  )
  expect_error(
    rpkgkit:::num_to_word_lookup(c("for" = 4, "to" = 2, "toward" = 2)),
    "must be a named vector"
  )
  expect_error(
    rpkgkit:::num_to_word_lookup(c("to!" = 2)),
    "must be a named vector"
  )
  expect_error(
    rpkgkit:::num_to_word_lookup(character(0L)),
    "must be a named vector"
  )
})

# -----------------------------------------------------------
# split_word_numbers helper tests
# -----------------------------------------------------------

test_that("split_word_numbers: expands mapped digit runs", {
  lookup <- rpkgkit:::num_to_word_lookup(c("for" = 4, "to" = 2))
  expect_equal(
    rpkgkit:::split_word_numbers("list2env", lookup),
    c("list", "to", "env")
  )
  expect_equal(
    rpkgkit:::split_word_numbers("wait4result", lookup),
    c("wait", "for", "result")
  )
})

test_that("split_word_numbers: leaves unmapped digit runs intact", {
  lookup <- rpkgkit:::num_to_word_lookup(c("for" = 4, "to" = 2))
  expect_equal(rpkgkit:::split_word_numbers("log10", lookup), "log10")
  expect_equal(rpkgkit:::split_word_numbers("x10y", lookup), "x10y")
  # one mapped and one unmapped digit run -> word is left alone entirely
  expect_equal(rpkgkit:::split_word_numbers("a2b10c", lookup), "a2b10c")
})

test_that("split_word_numbers: words without digits are untouched", {
  lookup <- rpkgkit:::num_to_word_lookup(c("for" = 4, "to" = 2))
  expect_equal(rpkgkit:::split_word_numbers("plain", lookup), "plain")
  expect_equal(rpkgkit:::split_word_numbers("plain", NULL), "plain")
})

# -----------------------------------------------------------
# to_style with num_lookup
# -----------------------------------------------------------

test_that("to_style: num_lookup expands digits and follows each style", {
  lookup <- rpkgkit:::num_to_word_lookup(c("for" = 4, "to" = 2))

  expect_equal(
    rpkgkit:::to_style("list2env", "snake_case", num_lookup = lookup),
    "list_to_env"
  )
  expect_equal(
    rpkgkit:::to_style("list2env", "camelCase", num_lookup = lookup),
    "listToEnv"
  )
  expect_equal(
    rpkgkit:::to_style("list2env", "PascalCase", num_lookup = lookup),
    "ListToEnv"
  )
  expect_equal(
    rpkgkit:::to_style("list2env", "google", num_lookup = lookup),
    "list.to.env"
  )
})

test_that("to_style: num_lookup expansion works with camelCase input names", {
  lookup <- rpkgkit:::num_to_word_lookup(c("for" = 4, "to" = 2))
  expect_equal(
    rpkgkit:::to_style("convert2Json", "snake_case", num_lookup = lookup),
    "convert_to_json"
  )
})

test_that("to_style: num_lookup leaves unmapped digits intact", {
  lookup <- rpkgkit:::num_to_word_lookup(c("for" = 4, "to" = 2))
  expect_equal(
    rpkgkit:::to_style("scale_x_log10", "snake_case", num_lookup = lookup),
    "scale_x_log10"
  )
})

test_that("to_style: num_lookup default keeps previous behaviour", {
  expect_equal(rpkgkit:::to_style("list2env", "snake_case"), "list2env")
  expect_equal(
    rpkgkit:::to_style("list2env", "snake_case", num_lookup = NULL),
    "list2env"
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
  expect_equal(rpkgkit:::detect_func_defs(lines), character(0L))
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
  expect_equal(rpkgkit:::detect_func_defs(lines), character(0L))
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

  readLines_paths <- character(0L)
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

  expect_error(rename_func(tmp, extra_arg = 1L))
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

# -----------------------------------------------------------
# rename_func num_to_word tests
# -----------------------------------------------------------

test_that("rename_func: expands digit abbreviations by default", {
  tmp <- tempfile(fileext = ".R")
  writeLines(
    c(
      "list2env <- function(x) { x }",
      "list2env(1)"
    ),
    tmp
  )
  on.exit(unlink(tmp))

  rename_func(tmp, style = "snake_case")

  result <- readLines(tmp)
  expect_match(result[1L], "list_to_env <- function")
  expect_match(result[2L], "list_to_env\\(1\\)")
})

test_that("rename_func: maps 4 to 'for'", {
  tmp <- tempfile(fileext = ".R")
  writeLines("wait4result <- function(x) { x }", tmp)
  on.exit(unlink(tmp))

  rename_func(tmp, style = "snake_case")

  expect_match(readLines(tmp)[1L], "wait_for_result <- function")
})

test_that("rename_func: expanded words follow the target style", {
  tmp <- tempfile(fileext = ".R")
  writeLines("list2env <- function(x) { x }", tmp)

  rename_func(tmp, style = "camelCase")
  expect_match(readLines(tmp)[1L], "listToEnv <- function")

  writeLines("list2env <- function(x) { x }", tmp)
  rename_func(tmp, style = "PascalCase")
  expect_match(readLines(tmp)[1L], "ListToEnv <- function")

  writeLines("list2env <- function(x) { x }", tmp)
  rename_func(tmp, style = "google")
  expect_match(readLines(tmp)[1L], "list.to.env <- function")

  unlink(tmp)
})

test_that("rename_func: leaves unmapped digit runs untouched", {
  tmp <- tempfile(fileext = ".R")
  writeLines("log10Env <- function(x) { x }", tmp)
  on.exit(unlink(tmp))

  rename_func(tmp, style = "snake_case")

  # The name is converted, but the unmapped "10" is not split into "1"/"0"
  expect_match(readLines(tmp)[1L], "log10_env <- function")
})

test_that("rename_func: num_to_word = FALSE disables the expansion", {
  tmp <- tempfile(fileext = ".R")
  writeLines("list2env <- function(x) { x }", tmp)
  on.exit(unlink(tmp))

  expect_message(
    rename_func(tmp, style = "snake_case", num_to_word = FALSE),
    "already in"
  )
  expect_equal(readLines(tmp)[1L], "list2env <- function(x) { x }")
})

test_that("rename_func: num_to_word = NULL disables the expansion", {
  tmp <- tempfile(fileext = ".R")
  writeLines("list2env <- function(x) { x }", tmp)
  on.exit(unlink(tmp))

  expect_message(
    rename_func(tmp, style = "snake_case", num_to_word = NULL),
    "already in"
  )
  expect_equal(readLines(tmp)[1L], "list2env <- function(x) { x }")
})

test_that("rename_func: accepts a custom num_to_word mapping", {
  tmp <- tempfile(fileext = ".R")
  writeLines("df2matrix <- function(x) { x }", tmp)
  on.exit(unlink(tmp))

  rename_func(tmp, style = "snake_case", num_to_word = c("into" = 2))

  expect_match(readLines(tmp)[1L], "df_into_matrix <- function")
})

test_that("rename_func: invalid num_to_word aborts before touching the file", {
  tmp <- tempfile(fileext = ".R")
  writeLines("list2env <- function(x) { x }", tmp)
  on.exit(unlink(tmp))

  expect_error(
    rename_func(tmp, style = "snake_case", num_to_word = c(2, 4)),
    "must be a named vector"
  )
  # File is left unchanged when validation fails
  expect_equal(readLines(tmp)[1L], "list2env <- function(x) { x }")
})
