# Test: inquire_standalone ------------------------------------------------------

# Helper: create a mock GitHub API response for directory contents
# Each element represents a file object as returned by GitHub Contents API
mock_gh_response <- function(files) {
  # files: a list of named lists, each with at least $name and $type
  lapply(files, function(f) {
    base <- list(
      name = f$name,
      path = file.path("R", f$name),
      sha = "abc123",
      size = 100L,
      url = "https://api.github.com/repos/owner/repo/contents/R/file.R",
      html_url = "https://github.com/owner/repo/blob/main/R/file.R",
      git_url = "https://api.github.com/repos/owner/repo/git/blobs/abc123",
      download_url = "https://raw.githubusercontent.com/owner/repo/main/R/file.R",
      type = "file",
      `_links` = list(
        self = "https://api.github.com/repos/owner/repo/contents/R/file.R",
        git = "https://api.github.com/repos/owner/repo/git/blobs/abc123",
        html = "https://github.com/owner/repo/blob/main/R/file.R"
      )
    )
    utils::modifyList(base, f)
  })
}

# ==============================================================================
# Error handling: dots validation
# ==============================================================================

test_that("inquire_standalone calls check_dots_empty0", {
  dots_checked <- FALSE

  local_mocked_bindings(
    check_dots_empty0 = function(...) {
      dots_checked <<- TRUE
      invisible()
    },
    .package = "rlang"
  )

  local_mocked_bindings(
    check_installed = function(pkg, ...) invisible(),
    .package = "rlang"
  )

  local_mocked_bindings(
    gh = function(...) list(),
    .package = "gh"
  )

  inquire_standalone("owner", "repo")
  expect_true(dots_checked)
})

# ==============================================================================
# Error handling: package installation checks
# ==============================================================================

test_that("inquire_standalone errors when gh is not installed", {
  local_mocked_bindings(
    check_installed = function(pkg, ...) {
      if ("gh" %in% pkg) {
        rlang::abort("gh is not installed")
      }
      invisible()
    },
    .package = "rlang"
  )

  expect_error(
    inquire_standalone("owner", "repo"),
    "gh is not installed"
  )
})

test_that("inquire_standalone errors when dplyr is not installed", {
  local_mocked_bindings(
    check_installed = function(pkg, ...) {
      if ("dplyr" %in% pkg) {
        rlang::abort("dplyr is not installed")
      }
      invisible()
    },
    .package = "rlang"
  )

  expect_error(
    inquire_standalone("owner", "repo"),
    "dplyr is not installed"
  )
})

# ==============================================================================
# Input handling: owner/repo spec
# ==============================================================================

test_that("inquire_standalone treats owner containing '/' as full repo_spec", {
  gh_calls <- list()

  local_mocked_bindings(
    check_installed = function(pkg, ...) invisible(),
    .package = "rlang"
  )

  local_mocked_bindings(
    gh = function(endpoint, ..., .accept = NULL) {
      gh_calls <<- append(gh_calls, list(list(
        endpoint = endpoint,
        repo_spec = list(...)$repo_spec
      )))
      list()
    },
    .package = "gh"
  )

  inquire_standalone("org/repo-name")

  expect_length(gh_calls, 1L)
  expect_equal(gh_calls[[1L]]$repo_spec, "org/repo-name")
})

test_that("inquire_standalone combines separate owner and repo", {
  gh_calls <- list()

  local_mocked_bindings(
    check_installed = function(pkg, ...) invisible(),
    .package = "rlang"
  )

  local_mocked_bindings(
    gh = function(endpoint, ..., .accept = NULL) {
      gh_calls <<- append(gh_calls, list(list(
        endpoint = endpoint,
        repo_spec = list(...)$repo_spec
      )))
      list()
    },
    .package = "gh"
  )

  inquire_standalone("tidyverse", "dplyr")

  expect_length(gh_calls, 1L)
  expect_equal(gh_calls[[1L]]$repo_spec, "tidyverse/dplyr")
})

# ==============================================================================
# Happy path: standalone files found
# ==============================================================================

test_that("inquire_standalone returns tibble when standalone files exist", {
  local_mocked_bindings(
    check_installed = function(pkg, ...) invisible(),
    .package = "rlang"
  )

  local_mocked_bindings(
    gh = function(endpoint, ..., .accept = NULL) {
      mock_gh_response(list(
        list(name = "standalone-cli.R"),
        list(name = "standalone-purrr.R"),
        list(name = "standalone-zeallot.R")
      ))
    },
    .package = "gh"
  )

  result <- inquire_standalone("r-lib", "rlang")

  expect_s3_class(result, "tbl_df")
  expect_true(nrow(result) >= 1L)
  expect_true("name" %in% names(result))
  expect_false("_links" %in% names(result))
})

test_that("inquire_standalone filters out non-standalone files", {
  local_mocked_bindings(
    check_installed = function(pkg, ...) invisible(),
    .package = "rlang"
  )

  response_files <- mock_gh_response(list(
    list(name = "standalone-utils.R"),
    list(name = "normal-file.R"),
    list(name = "another-normal.R"),
    list(name = "standalone-helpers.R")
  ))

  local_mocked_bindings(
    gh = function(endpoint, ..., .accept = NULL) response_files,
    .package = "gh"
  )

  result <- inquire_standalone("owner", "repo")

  # Should only include standalone- files
  expect_true(any(grepl("standalone-", result$name)))
  expect_false(any(result$name == "normal-file.R"))
  expect_false(any(result$name == "another-normal.R"))
})

test_that("inquire_standalone handles response with only non-standalone files", {
  local_mocked_bindings(
    check_installed = function(pkg, ...) invisible(),
    .package = "rlang"
  )

  local_mocked_bindings(
    gh = function(endpoint, ..., .accept = NULL) {
      mock_gh_response(list(
        list(name = "utils.R"),
        list(name = "helpers.R")
      ))
    },
    .package = "gh"
  )

  # All files are non-standalone, so bind_rows on all-NULL list returns
  # a 0-row tibble
  result <- inquire_standalone("owner", "repo")

  # bind_rows on all-NULL list may produce 0-row tibble or warning
  expect_s3_class(result, "tbl_df")
})

test_that("inquire_standalone handles empty directory response", {
  local_mocked_bindings(
    check_installed = function(pkg, ...) invisible(),
    .package = "rlang"
  )

  local_mocked_bindings(
    gh = function(endpoint, ..., .accept = NULL) list(),
    .package = "gh"
  )

  # Empty directory returns empty response list, resulting in 0-row tibble
  result <- inquire_standalone("owner", "repo")
  expect_s3_class(result, "tbl_df")
})

# ==============================================================================
# Output structure verification
# ==============================================================================

test_that("inquire_standalone removes _links column from output", {
  local_mocked_bindings(
    check_installed = function(pkg, ...) invisible(),
    .package = "rlang"
  )

  local_mocked_bindings(
    gh = function(endpoint, ..., .accept = NULL) {
      mock_gh_response(list(
        list(name = "standalone-foo.R")
      ))
    },
    .package = "gh"
  )

  result <- inquire_standalone("owner", "repo")

  expect_false("_links" %in% names(result))
})

test_that("inquire_standalone output contains expected content columns", {
  local_mocked_bindings(
    check_installed = function(pkg, ...) invisible(),
    .package = "rlang"
  )

  local_mocked_bindings(
    gh = function(endpoint, ..., .accept = NULL) {
      mock_gh_response(list(
        list(name = "standalone-cli.R", size = 1024L),
        list(name = "standalone-purrr.R", size = 2048L)
      ))
    },
    .package = "gh"
  )

  result <- inquire_standalone("owner", "repo")

  # Core columns from GitHub Contents API should be present
  expect_true("name" %in% names(result))
  expect_true("path" %in% names(result))
  expect_true("type" %in% names(result))
  expect_true("sha" %in% names(result))

  # _links should be excluded
  expect_false("_links" %in% names(result))
})

# ==============================================================================
# Input edge cases
# ==============================================================================

test_that("inquire_standalone handles owner with trailing slash in combined form", {
  local_mocked_bindings(
    check_installed = function(pkg, ...) invisible(),
    .package = "rlang"
  )

  gh_calls <- list()
  local_mocked_bindings(
    gh = function(endpoint, ..., .accept = NULL) {
      gh_calls <<- append(gh_calls, list(list(
        repo_spec = list(...)$repo_spec
      )))
      list()
    },
    .package = "gh"
  )

  inquire_standalone("org/repo/")

  expect_equal(gh_calls[[1L]]$repo_spec, "org/repo/")
})

test_that("inquire_standalone handles multiple standalone files with same name (distinct)", {
  local_mocked_bindings(
    check_installed = function(pkg, ...) invisible(),
    .package = "rlang"
  )

  local_mocked_bindings(
    gh = function(endpoint, ..., .accept = NULL) {
      mock_gh_response(list(
        list(name = "standalone-cli.R"),
        list(name = "standalone-cli.R")  # duplicate entry
      ))
    },
    .package = "gh"
  )

  result <- inquire_standalone("owner", "repo")

  # distinct() should deduplicate
  expect_equal(nrow(result), 1L)
})