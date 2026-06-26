# Test: add_changelog_in_standalone --------------------------------------------

# Helper: create a standalone file with a standard YAML header and trailing content
create_standalone_file <- function(
  path,
  header_lines,
  extra = "# future code"
) {
  writeLines(c(header_lines, extra), path)
}

# ==============================================================================
# Error handling: description validation
# ==============================================================================

test_that("add_changelog_in_standalone aborts when description is NULL", {
  expect_error(
    add_changelog_in_standalone(path = "any.R", description = NULL),
    "description.*is required"
  )
})

test_that("add_changelog_in_standalone aborts when description is NA", {
  expect_error(
    add_changelog_in_standalone(path = "any.R", description = NA_character_),
    "description.*is required"
  )
})

test_that("add_changelog_in_standalone aborts when description is empty string", {
  expect_error(
    add_changelog_in_standalone(path = "any.R", description = ""),
    "description.*is required"
  )
})

# ==============================================================================
# Error handling: path validation
# ==============================================================================

test_that("add_changelog_in_standalone aborts when path is NULL and rstudioapi unavailable", {
  local_mocked_bindings(
    is_installed = function(pkg) FALSE,
    .package = "rlang"
  )

  expect_error(
    add_changelog_in_standalone(description = "Add new feature"),
    "path.*is required"
  )
})

test_that("add_changelog_in_standalone aborts when path is NA", {
  expect_error(
    add_changelog_in_standalone(path = NA_character_, description = "Fix bug"),
    "path.*is required"
  )
})

test_that("add_changelog_in_standalone aborts when path is empty string", {
  expect_error(
    add_changelog_in_standalone(path = "", description = "Fix bug"),
    "path.*is required"
  )
})

test_that("add_changelog_in_standalone aborts when path does not exist", {
  non_existent <- tempfile("nonexistent_file")

  expect_error(
    add_changelog_in_standalone(
      path = non_existent,
      description = "Update docs"
    ),
    "does not exist"
  )
})

# ==============================================================================
# Path resolution: rstudioapi fallback
# ==============================================================================

test_that("add_changelog_in_standalone uses rstudioapi when path is NULL", {
  mock_path <- tempfile(fileext = ".R")
  on.exit(unlink(mock_path))

  create_standalone_file(
    mock_path,
    c(
      "# ---",
      "# repo: owner/repo",
      "# file: standalone-utils.R",
      "# last-updated: 2025-01-01",
      "# license: unlicense",
      "# imports: []",
      "# ---"
    )
  )

  local_mocked_bindings(
    is_installed = function(pkg) TRUE,
    .package = "rlang"
  )

  local_mocked_bindings(
    getActiveDocumentContext = function() list(path = mock_path),
    .package = "rstudioapi"
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

  result <- add_changelog_in_standalone(
    description = "Add new feature via rstudioapi"
  )

  expect_length(writeLines_calls, 1L)
  expect_equal(writeLines_calls[[1L]]$con, mock_path)
  expect_true(mock_path %in% result)
})

# ==============================================================================
# Single file: no existing Changelog section
# ==============================================================================

test_that("add_changelog_in_standalone creates changelog section when none exists", {
  tmp_file <- tempfile(fileext = ".R")
  on.exit(unlink(tmp_file))

  create_standalone_file(
    tmp_file,
    c(
      "# ---",
      "# repo: owner/repo",
      "# file: standalone-utils.R",
      "# last-updated: 2025-01-01",
      "# license: unlicense",
      "# imports: [cli]",
      "# ---"
    )
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

  result <- add_changelog_in_standalone(
    path = tmp_file,
    description = "Initial implementation"
  )

  expect_length(writeLines_calls, 1L)
  updated <- writeLines_calls[[1L]]$text

  # Last-updated should be updated to today
  expect_match(updated[4L], "^# last-updated: \\d{4}-\\d{2}-\\d{2}")
  expect_false(identical(updated[4L], "# last-updated: 2025-01-01"))

  # New changelog section should appear after the YAML header end
  changelog_line <- grep("^# ## Changelog:", updated)
  expect_length(changelog_line, 1L)
  expect_gt(changelog_line, 7L)

  # Changelog section should contain the new entry
  expect_true(any(grepl("Initial implementation", updated)))

  expect_equal(result, tmp_file)
})

test_that("add_changelog_in_standalone creates changelog with blank comment line after YAML header", {
  tmp_file <- tempfile(fileext = ".R")
  on.exit(unlink(tmp_file))

  # YAML header followed by a blank comment line and trailing content
  lines <- c(
    "# ---",
    "# repo: owner/repo",
    "# file: standalone-utils.R",
    "# last-updated: 2025-01-01",
    "# license: unlicense",
    "# imports: [cli]",
    "# ---",
    "#",
    "# actual code starts here"
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

  result <- add_changelog_in_standalone(
    path = tmp_file,
    description = "Feature after blank line"
  )

  expect_length(writeLines_calls, 1L)
  updated <- writeLines_calls[[1L]]$text

  # YAML ends at line 7, line 8 is "#", line 9 is "# actual code..."
  # In no-changelog branch: yaml_end=7, insert_pos=8, lines[8]="#", blank_before=1
  # insert_pos becomes 9, then append at after=8
  # So new_lines should be inserted between original lines 8 and 9
  changelog_line <- grep("^# ## Changelog:", updated)
  expect_length(changelog_line, 1L)

  # Feature after blank line entry should be present
  expect_true(any(grepl("Feature after blank line", updated)))

  # The original trailing content should still be at the end
  expect_match(updated[length(updated)], "actual code starts here")

  expect_equal(result, tmp_file)
})

# ==============================================================================
# Single file: existing Changelog section
# ==============================================================================

test_that("add_changelog_in_standalone appends entry to existing changelog section", {
  tmp_file <- tempfile(fileext = ".R")
  on.exit(unlink(tmp_file))

  lines <- c(
    "# ---",
    "# repo: owner/repo",
    "# file: standalone-utils.R",
    "# last-updated: 2025-06-01",
    "# license: unlicense",
    "# imports: []",
    "# ---",
    "#",
    "# Changelog:",
    "#",
    "# 2025-06-01:",
    "# Initial release",
    "#",
    "actual_code <- function() {}"
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

  result <- add_changelog_in_standalone(
    path = tmp_file,
    description = "Fixed critical bug",
    date = "2025-07-15"
  )

  expect_length(writeLines_calls, 1L)
  updated <- writeLines_calls[[1L]]$text

  # Should have the changelog header
  expect_true(any(grepl("^# Changelog:", updated)))

  # Should have the new entry
  date_line <- grep("^# 2025-07-15:", updated)
  expect_length(date_line, 1L)
  expect_true(any(grepl("Fixed critical bug", updated)))

  # The original entry should still be present
  expect_true(any(grepl("2025-06-01:", updated)))
  expect_true(any(grepl("Initial release", updated)))

  # New entry should come before the old entry (prepended to changelog)
  expect_lt(date_line[1L], grep("2025-06-01:", updated)[1L])

  # Actual code should still be at the end
  expect_true(any(grepl("actual_code", updated)))

  expect_equal(result, tmp_file)
})

test_that("add_changelog_in_standalone appends entry when changelog has no blank line after header", {
  tmp_file <- tempfile(fileext = ".R")
  on.exit(unlink(tmp_file))

  # Changelog: header followed immediately by an entry (no blank "#" line)
  lines <- c(
    "# ---",
    "# repo: owner/repo",
    "# file: standalone-utils.R",
    "# last-updated: 2025-06-01",
    "# license: unlicense",
    "# imports: []",
    "# ---",
    "#",
    "# Changelog:",
    "# 2025-06-01:",
    "# Initial release",
    "#",
    "actual_code <- function() {}"
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

  result <- add_changelog_in_standalone(
    path = tmp_file,
    description = "New fix",
    date = "2025-08-01"
  )

  expect_length(writeLines_calls, 1L)
  updated <- writeLines_calls[[1L]]$text

  # Check the new entry was inserted
  expect_true(any(grepl("2025-08-01:", updated)))
  expect_true(any(grepl("New fix", updated)))
  expect_true(any(grepl("Initial release", updated)))
  expect_true(any(grepl("actual_code", updated)))
})

# ==============================================================================
# Package directory scanning
# ==============================================================================

test_that("add_changelog_in_standalone finds standalone files in a package directory", {
  tmp <- tempfile("pkg_changelog")
  dir.create(file.path(tmp, "R"), recursive = TRUE)
  file.create(file.path(tmp, "DESCRIPTION"))
  on.exit(unlink(tmp, recursive = TRUE))

  file1 <- file.path(tmp, "R", "standalone-a.R")
  file2 <- file.path(tmp, "R", "standalone-b.R")

  header <- c(
    "# ---",
    "# repo: owner/repo",
    "# file: standalone-a.R",
    "# last-updated: 2025-01-01",
    "# license: unlicense",
    "# imports: []",
    "# ---"
  )
  create_standalone_file(file1, header)
  create_standalone_file(file2, header)

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

  result <- add_changelog_in_standalone(
    path = tmp,
    description = "Added changelog to all standalone files"
  )

  expect_length(writeLines_calls, 2L)
  updated_files <- sapply(writeLines_calls, `[[`, "con")
  expect_true(file1 %in% updated_files)
  expect_true(file2 %in% updated_files)
  expect_true(file1 %in% result)
  expect_true(file2 %in% result)
})

# ==============================================================================
# Regular directory scanning
# ==============================================================================

test_that("add_changelog_in_standalone finds standalone files in a regular directory", {
  tmp <- tempfile("dir_changelog")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE))

  file1 <- file.path(tmp, "standalone-x.R")
  file2 <- file.path(tmp, "standalone-y.R")

  header <- c(
    "# ---",
    "# repo: owner/repo",
    "# file: standalone-x.R",
    "# last-updated: 2025-01-01",
    "# license: unlicense",
    "# imports: []",
    "# ---"
  )
  create_standalone_file(file1, header)
  create_standalone_file(file2, header)

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

  result <- add_changelog_in_standalone(
    path = tmp,
    description = "Changelog for all files"
  )

  expect_length(writeLines_calls, 2L)
  updated_files <- sapply(writeLines_calls, `[[`, "con")
  expect_true(file1 %in% updated_files)
  expect_true(file2 %in% updated_files)
})

# ==============================================================================
# No files found
# ==============================================================================

test_that("add_changelog_in_standalone informs when no standalone files found", {
  tmp <- tempfile("empty_dir_changelog")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE))

  expect_message(
    result <- add_changelog_in_standalone(path = tmp, description = "No files"),
    "No standalone files found"
  )

  expect_equal(result, character())
})

test_that("add_changelog_in_standalone informs when package has no standalone files", {
  tmp <- tempfile("pkg_no_standalone")
  dir.create(file.path(tmp, "R"), recursive = TRUE)
  file.create(file.path(tmp, "DESCRIPTION"))
  on.exit(unlink(tmp, recursive = TRUE))

  expect_message(
    result <- add_changelog_in_standalone(
      path = tmp,
      description = "No standalone"
    ),
    "No standalone files found"
  )

  expect_equal(result, character())
})

# ==============================================================================
# Invalid YAML header
# ==============================================================================

test_that("add_changelog_in_standalone warns when file has no valid YAML header", {
  tmp_file <- tempfile(fileext = ".R")
  on.exit(unlink(tmp_file))

  # Only one "# ---" marker (not two)
  lines <- c("# ---", "# last-updated: 2025-01-01", "# content")
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
    result <- add_changelog_in_standalone(
      path = tmp_file,
      description = "No YAML"
    ),
    "No valid YAML header"
  )

  # No files should have been written
  expect_length(writeLines_calls, 0L)
  expect_equal(result, character())
})

# ==============================================================================
# Custom date parameter
# ==============================================================================

test_that("add_changelog_in_standalone uses the custom date parameter", {
  tmp_file <- tempfile(fileext = ".R")
  on.exit(unlink(tmp_file))

  header <- c(
    "# ---",
    "# repo: owner/repo",
    "# file: standalone-utils.R",
    "# last-updated: 2025-01-01",
    "# license: unlicense",
    "# imports: []",
    "# ---"
  )
  create_standalone_file(tmp_file, header)

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

  add_changelog_in_standalone(
    path = tmp_file,
    description = "Custom date entry",
    date = "1999-12-31"
  )

  updated <- writeLines_calls[[1L]]$text

  # last-updated should use custom date
  expect_true(any(grepl("# last-updated: 1999-12-31", updated)))

  # changelog entry should use custom date
  expect_true(any(grepl("# 1999-12-31:", updated)))
  expect_true(any(grepl("Custom date entry", updated)))
})
