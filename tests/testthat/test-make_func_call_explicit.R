test_that("make_func_call_explicit reads file, adds colons, and writes back", {
  mock_path <- "/mock/project/R/my_file.R"
  mock_input_code <- paste(
    "cars %>% filter(mpg > 20) %>% summarise(across(everything(), n_distinct))",
    collapse = "\n"
  )
  mock_output_code <- paste(
    "cars %>% dplyr::filter(mpg > 20) %>% dplyr::summarise(dplyr::across(dplyr::everything(), n_distinct))",
    collapse = "\n"
  )

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
      mock_input_code
    },
    .package = "base"
  )

  add_double_colons_calls <- list()
  local_mocked_bindings(
    add_double_colons = function(code, use_packages, ignore_functions) {
      add_double_colons_calls <<- append(
        add_double_colons_calls,
        list(list(
          code = code,
          use_packages = use_packages,
          ignore_functions = ignore_functions
        ))
      )
      mock_output_code
    },
    .package = "pedant"
  )

  writeLines_calls <- list()
  local_mocked_bindings(
    writeLines = function(text, con) {
      writeLines_calls <<- append(
        writeLines_calls,
        list(list(
          text = text,
          con = con
        ))
      )
    },
    .package = "base"
  )

  make_func_call_explicit(
    use_packages = c("dplyr", "stats"),
    ignore_functions = c("library", "require")
  )

  expect_length(readLines_paths, 1L)
  expect_equal(readLines_paths[[1L]], mock_path)

  expect_length(add_double_colons_calls, 1L)
  expect_equal(add_double_colons_calls[[1L]]$code, mock_input_code)
  expect_equal(add_double_colons_calls[[1L]]$use_packages, c("dplyr", "stats"))
  expect_equal(
    add_double_colons_calls[[1L]]$ignore_functions,
    c("library", "require")
  )

  expect_length(writeLines_calls, 1L)
  expect_equal(writeLines_calls[[1L]]$text, mock_output_code)
  expect_equal(writeLines_calls[[1L]]$con, mock_path)
})
