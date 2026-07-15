test_that("convert_nonascii_code with file path reads and converts", {
  tmp <- withr::local_tempfile(fileext = ".R")
  writeLines("print('\u4e2d\u6587')", tmp)

  result <- convert_nonascii_code(tmp, overwrite = FALSE)
  expect_true(grepl("\\\\u4e2d", result))
  expect_true(grepl("\\\\u6587", result))
})

test_that("convert_nonascii_code with file path and overwrite = TRUE updates file", {
  tmp <- withr::local_tempfile(fileext = ".R")
  writeLines("print('\u4e2d\u6587')", tmp)

  convert_nonascii_code(tmp, overwrite = TRUE)
  content <- readLines(tmp, warn = FALSE)
  expect_true(any(grepl("\\\\u4e2d", content)))
  expect_true(any(grepl("\\\\u6587", content)))
})

test_that("convert_nonascii_code with non-existent file path variable prints as expr", {
  bad_path <- "/nonexistent/path.R"
  result <- convert_nonascii_code(bad_path)
  expect_true(grepl("bad_path", result, fixed = TRUE))
})

test_that("convert_nonascii_code with reverse on file path restores escapes", {
  tmp <- withr::local_tempfile(fileext = ".R")
  writeLines("print('\\u4e2d\\u6587')", tmp)

  result <- convert_nonascii_code(tmp, reverse = TRUE, overwrite = FALSE)
  expect_true(grepl("\u4e2d\u6587", result))
})

test_that("convert_nonascii_code reports when no changes needed on file", {
  tmp <- withr::local_tempfile(fileext = ".R")
  writeLines("print('hello')", tmp)

  expect_message(
    convert_nonascii_code(tmp, overwrite = FALSE),
    "No non-ASCII characters found"
  )
})

test_that("encode_nonascii encodes non-ASCII only", {
  result <- encode_nonascii("a\u4e2db\u6587c")
  expect_equal(result, "a\\u4e2db\\u6587c")
})

test_that("encode_nonascii leaves pure ASCII unchanged", {
  result <- encode_nonascii("hello world 123")
  expect_equal(result, "hello world 123")
})

test_that("restore_unicode_escapes restores all escape sequences", {
  result <- restore_unicode_escapes("a\\u4e2db\\u6587c")
  expect_equal(result, "a\u4e2db\u6587c")
})

test_that("restore_unicode_escapes leaves non-escape text unchanged", {
  result <- restore_unicode_escapes("hello world")
  expect_equal(result, "hello world")
})

test_that("convert_nonascii_code_expr encodes non-ASCII in quoted expression", {
  result <- convert_nonascii_code_expr(rlang::expr(print('\u4e2d\u6587')))
  expect_true(grepl("\\\\u4e2d", result))
  expect_true(grepl("\\\\u6587", result))
})

test_that("convert_nonascii_code_expr leaves ASCII-only expr unchanged", {
  result <- convert_nonascii_code_expr(rlang::expr(print(hello)))
  expect_true(grepl("print(hello)", result, fixed = TRUE))
})

test_that("convert_nonascii_code_expr restores escapes with reverse", {
  result <- convert_nonascii_code_expr(
    rlang::expr(print('\u4e2d\u6587')),
    reverse = TRUE
  )
  expect_true(grepl("\u4e2d\u6587", result))
})

test_that("convert_nonascii_code with NSE captures bare expression", {
  result <- convert_nonascii_code(print('\u4e2d\u6587'))
  expect_true(grepl("\\\\u4e2d", result))
  expect_true(grepl("\\\\u6587", result))
})

test_that("convert_nonascii_code NSE with reverse", {
  result <- convert_nonascii_code(print('\u4e2d\u6587'), reverse = TRUE)
  expect_true(grepl("\u4e2d\u6587", result))
})

test_that("convert_nonascii_code NSE with ASCII-only code", {
  result <- convert_nonascii_code(print("hello"))
  expect_true(grepl('print("hello")', result, fixed = TRUE))
})

test_that("convert_nonascii_code NSE with string arg that is not a file", {
  result <- convert_nonascii_code("some random string")
  expect_true(grepl("some random string", result, fixed = TRUE))
})

test_that("convert_nonascii_code handles { } multi-line expression", {
  result <- convert_nonascii_code({ cli::cli_alert_info("明月几时有") })
  expect_true(grepl("\\\\u660e", result))
  expect_true(grepl("\\\\u6708", result))
  expect_true(grepl("\\\\u51e0", result))
  expect_true(grepl("\\\\u65f6", result))
  expect_true(grepl("\\\\u6709", result))
})

test_that("convert_nonascii_code handles { } multi-line expression with reverse", {
  result <- convert_nonascii_code({ cli::cli_alert_info("明月几时有") }, reverse = TRUE)
  expect_true(grepl("明月几时有", result))
})

test_that("convert_nonascii_code_expr handles multi-line deparse", {
  result <- convert_nonascii_code_expr(
    rlang::expr({
      cli::cli_alert_info("明月几时有")
    })
  )
  expect_true(grepl("\\\\u660e", result))
  expect_true(grepl("\\\\u6708", result))
})
