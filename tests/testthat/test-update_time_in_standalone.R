test_that("update_time_in_standalone aborts when path is NULL and rstudioapi unavailable", {
  local_mocked_bindings(
    is_installed = function(pkg) FALSE,
    .package = "rlang"
  )

  expect_error(
    update_time_in_standalone(),
    "path.*is required"
  )
})

test_that("update_time_in_standalone aborts when path is NA", {
  expect_error(
    update_time_in_standalone(NA_character_),
    "path.*is required"
  )
})

test_that("update_time_in_standalone aborts when path is empty string", {
  expect_error(
    update_time_in_standalone(""),
    "path.*is required"
  )
})

test_that("update_time_in_standalone uses rstudioapi active document path when path is NULL", {
  mock_path <- "/home/user/project/R/standalone-utils.R"

  local_mocked_bindings(
    is_installed = function(pkg) TRUE,
    .package = "rlang"
  )

  local_mocked_bindings(
    getActiveDocumentContext = function() list(path = mock_path),
    .package = "rstudioapi"
  )

  # Mock file.exists to return TRUE (it's a file)
  local_mocked_bindings(
    file.exists = function(x) TRUE,
    .package = "base"
  )

  local_mocked_bindings(
    dir.exists = function(x) FALSE,
    .package = "base"
  )

  readLines_calls <- list()
  local_mocked_bindings(
    readLines = function(f, warn = FALSE) {
      readLines_calls <<- append(readLines_calls, f)
      c(
        "# ---",
        "# repo: owner/repo",
        "# file: standalone-utils.R",
        "# last-updated: 2025-01-01",
        "# license: unlicense",
        "# imports: []",
        "# ---"
      )
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

  result <- update_time_in_standalone()

  expect_equal(readLines_calls[[1L]], mock_path)
  expect_length(writeLines_calls, 1L)
  expect_equal(writeLines_calls[[1L]]$con, mock_path)
  expect_match(
    writeLines_calls[[1L]]$text[4L],
    "^# last-updated: \\d{4}-\\d{2}-\\d{2}"
  )
  expect_false(
    identical(writeLines_calls[[1L]]$text[4L], "# last-updated: 2025-01-01")
  )
  expect_equal(result, mock_path)
})

test_that("update_time_in_standalone updates a single standalone file", {
  tmp_file <- tempfile(fileext = ".R")
  on.exit(unlink(tmp_file))

  original_lines <- c(
    "# ---",
    "# repo: owner/repo",
    "# file: standalone-helper.R",
    "# last-updated: 2025-03-15",
    "# license: MIT",
    "# imports: [cli]",
    "# ---"
  )

  writeLines(original_lines, tmp_file)

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

  result <- update_time_in_standalone(tmp_file)

  expect_length(writeLines_calls, 1L)
  expect_equal(writeLines_calls[[1L]]$con, tmp_file)

  # Other lines unchanged
  expect_equal(writeLines_calls[[1L]]$text[1L], "# ---")
  expect_equal(writeLines_calls[[1L]]$text[2L], "# repo: owner/repo")
  expect_equal(writeLines_calls[[1L]]$text[3L], "# file: standalone-helper.R")
  expect_equal(writeLines_calls[[1L]]$text[5L], "# license: MIT")
  expect_equal(writeLines_calls[[1L]]$text[6L], "# imports: [cli]")

  # last-updated changed to today's date
  expect_match(
    writeLines_calls[[1L]]$text[4L],
    "^# last-updated: \\d{4}-\\d{2}-\\d{2}"
  )
  expect_false(
    identical(writeLines_calls[[1L]]$text[4L], "# last-updated: 2025-03-15")
  )

  expect_equal(result, tmp_file)
})

test_that("update_time_in_standalone finds standalone files in a package directory", {
  tmp <- tempfile("pkg_test")
  dir.create(file.path(tmp, "R"), recursive = TRUE)
  file.create(file.path(tmp, "DESCRIPTION"))
  on.exit(unlink(tmp, recursive = TRUE))

  # Create two standalone files
  file1 <- file.path(tmp, "R", "standalone-a.R")
  file2 <- file.path(tmp, "R", "standalone-b.R")
  file3 <- file.path(tmp, "R", "not-standalone.R")

  writeLines(c("# last-updated: 2025-06-01", "# content a"), file1)
  writeLines(c("# last-updated: 2025-06-15", "# content b"), file2)
  writeLines(c("# some other file"), file3)

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

  result <- update_time_in_standalone(tmp)

  expect_length(writeLines_calls, 2L)
  updated_files <- sapply(writeLines_calls, `[[`, "con")
  expect_true(file1 %in% updated_files)
  expect_true(file2 %in% updated_files)
  expect_false(file3 %in% updated_files)
  expect_true(file1 %in% result)
  expect_true(file2 %in% result)
})

test_that("update_time_in_standalone finds standalone files in a regular directory", {
  tmp <- tempfile("dir_test")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE))

  file1 <- file.path(tmp, "standalone-x.R")
  file2 <- file.path(tmp, "standalone-y.R")
  file3 <- file.path(tmp, "other.R")

  writeLines(c("# last-updated: 2025-01-01", "# x"), file1)
  writeLines(c("# last-updated: 2025-02-02", "# y"), file2)
  writeLines(c("# other"), file3)

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

  result <- update_time_in_standalone(tmp)

  expect_length(writeLines_calls, 2L)
  updated_files <- sapply(writeLines_calls, `[[`, "con")
  expect_true(file1 %in% updated_files)
  expect_true(file2 %in% updated_files)
})

test_that("update_time_in_standalone informs when no standalone files found", {
  tmp <- tempfile("empty_dir")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE))

  expect_message(
    result <- update_time_in_standalone(tmp),
    "No standalone files found"
  )

  expect_equal(result, character())
})

test_that("update_time_in_standalone aborts when path does not exist", {
  non_existent <- tempfile("nonexistent")

  expect_error(
    update_time_in_standalone(non_existent),
    "does not exist"
  )
})

test_that("update_time_in_standalone warns when file has no last-updated field", {
  tmp_file <- tempfile(fileext = ".R")
  on.exit(unlink(tmp_file))

  lines <- c(
    "# ---",
    "# repo: owner/repo",
    "# file: standalone-nodate.R",
    "# license: MIT",
    "# ---"
  )
  writeLines(lines, tmp_file)

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

  expect_warning(
    result <- update_time_in_standalone(tmp_file),
    "last-updated.*field found"
  )

  expect_length(writeLines_calls, 0L)
  expect_equal(result, character())
})

test_that("update_time_in_standalone updates last-updated with today's date format", {
  tmp_file <- tempfile(fileext = ".R")
  on.exit(unlink(tmp_file))

  writeLines(c("# last-updated: 2024-12-25", "# content"), tmp_file)

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

  result <- update_time_in_standalone(tmp_file)

  updated_text <- writeLines_calls[[1L]]$text[1L]
  today <- format(Sys.time(), "%Y-%m-%d")
  expect_equal(updated_text, paste("# last-updated:", today))
})

test_that("update_time_in_standalone handles path that is a package directory with no standalone files", {
  tmp <- tempfile("pkg_empty")
  dir.create(file.path(tmp, "R"), recursive = TRUE)
  file.create(file.path(tmp, "DESCRIPTION"))
  on.exit(unlink(tmp, recursive = TRUE))

  expect_message(
    result <- update_time_in_standalone(tmp),
    "No standalone files found"
  )

  expect_equal(result, character())
})
