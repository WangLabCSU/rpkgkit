# Test: inquire_standalone ------------------------------------------------------
#
# The crawl runs in Rust (`inquire_standalone_rs()`): these tests cover the R
# interface, i.e. argument validation, the repository identifier, token
# resolution and the conversion of the returned columns into a tibble.

# Helper: the named columns that `inquire_standalone_rs()` returns.
standalone_columns <- function(
  names,
  descriptions = rep(NA_character_, length(names))
) {
  count <- length(names)
  list(
    name = names,
    path = if (count == 0L) character() else paste0("R/", names),
    sha = rep("abc123", count),
    size = rep(100, count),
    url = rep(
      "https://api.github.com/repos/owner/repo/contents/R/file.R",
      count
    ),
    html_url = rep("https://github.com/owner/repo/blob/main/R/file.R", count),
    git_url = rep(
      "https://api.github.com/repos/owner/repo/git/blobs/abc123",
      count
    ),
    download_url = rep(
      "https://raw.githubusercontent.com/owner/repo/main/R/file.R",
      count
    ),
    type = rep("file", count),
    repo = rep("owner/repo", count),
    description = as.character(descriptions),
    usage = if (count == 0L) {
      character()
    } else {
      paste0('usethis::use_standalone("owner/repo", "', names, '")')
    }
  )
}

# ==============================================================================
# Argument validation
# ==============================================================================

test_that("inquire_standalone rejects arguments in `...`", {
  expect_error(
    inquire_standalone("owner", "repo", not_an_argument = TRUE),
    "must be empty"
  )
})

test_that("inquire_standalone rejects a non-string owner", {
  expect_error(inquire_standalone(1), "must be a single string")
})

test_that("inquire_standalone rejects a non-string token", {
  expect_error(
    inquire_standalone("owner", "repo", token = 42),
    "must be a single string"
  )
})

test_that("inquire_standalone reports a crawler failure", {
  local_mocked_bindings(
    inquire_standalone_rs = function(repo_spec, token) {
      rlang::abort("GitHub returned HTTP 404 for owner/repo")
    }
  )

  expect_error(
    inquire_standalone("owner", "repo"),
    "HTTP 404"
  )
})

# ==============================================================================
# Repository identifier
# ==============================================================================

test_that("inquire_standalone prefers an owner that contains '/'", {
  seen <- NULL
  local_mocked_bindings(
    inquire_standalone_rs = function(repo_spec, token) {
      seen <<- repo_spec
      standalone_columns("standalone-cli.R")
    }
  )

  inquire_standalone("org/repo-name")

  expect_equal(seen, "org/repo-name")
})

test_that("inquire_standalone combines a separate owner and repo", {
  seen <- NULL
  local_mocked_bindings(
    inquire_standalone_rs = function(repo_spec, token) {
      seen <<- repo_spec
      standalone_columns("standalone-cli.R")
    }
  )

  inquire_standalone("tidyverse", "dplyr")

  expect_equal(seen, "tidyverse/dplyr")
})

# ==============================================================================
# Token resolution
# ==============================================================================

test_that("inquire_standalone falls back to GITHUB_PAT then GITHUB_TOKEN", {
  seen <- character()
  local_mocked_bindings(
    inquire_standalone_rs = function(repo_spec, token) {
      seen <<- c(seen, token)
      standalone_columns("standalone-cli.R")
    }
  )

  withr::local_envvar(GITHUB_PAT = "pat-token", GITHUB_TOKEN = "env-token")
  inquire_standalone("owner", "repo")

  withr::local_envvar(GITHUB_PAT = "", GITHUB_TOKEN = "env-token")
  inquire_standalone("owner", "repo")

  withr::local_envvar(GITHUB_PAT = "", GITHUB_TOKEN = "")
  inquire_standalone("owner", "repo")

  inquire_standalone("owner", "repo", token = "explicit")

  expect_equal(seen, c("pat-token", "env-token", "", "explicit"))
})

# ==============================================================================
# Output shape
# ==============================================================================

test_that("inquire_standalone returns a tibble with the documented columns", {
  local_mocked_bindings(
    inquire_standalone_rs = function(repo_spec, token) {
      standalone_columns(c("standalone-cli.R", "standalone-purrr.R"))
    }
  )

  result <- suppressMessages(inquire_standalone("owner", "repo"))

  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 2L)
  expect_true(all(
    c(
      "name",
      "path",
      "sha",
      "size",
      "url",
      "html_url",
      "git_url",
      "download_url",
      "type",
      "repo",
      "description",
      "usage"
    ) %in%
      names(result)
  ))
  expect_false("_links" %in% names(result))
  expect_false("X_links" %in% names(result))
})

test_that("inquire_standalone keeps descriptions and usage", {
  local_mocked_bindings(
    inquire_standalone_rs = function(repo_spec, token) {
      standalone_columns("standalone-cli.R", descriptions = "Colourised output")
    }
  )

  result <- suppressMessages(inquire_standalone("r-lib", "rlang"))

  expect_equal(result$description, "Colourised output")
  expect_equal(
    result$usage,
    'usethis::use_standalone("owner/repo", "standalone-cli.R")'
  )
})

test_that("inquire_standalone turns a missing description into NA", {
  local_mocked_bindings(
    inquire_standalone_rs = function(repo_spec, token) {
      standalone_columns(c("standalone-cli.R", "standalone-purrr.R"))
    }
  )

  result <- suppressMessages(inquire_standalone("owner", "repo"))

  expect_true(all(is.na(result$description)))
})

test_that("inquire_standalone keeps the GitHub columns as-is", {
  local_mocked_bindings(
    inquire_standalone_rs = function(repo_spec, token) {
      standalone_columns("standalone-cli.R")
    }
  )

  result <- suppressMessages(inquire_standalone("owner", "repo"))

  expect_equal(result$name, "standalone-cli.R")
  expect_equal(result$path, "R/standalone-cli.R")
  expect_equal(result$type, "file")
  expect_equal(result$sha, "abc123")
  expect_equal(result$repo, "owner/repo")
})

test_that("inquire_standalone returns a zero-row tibble when nothing matches", {
  local_mocked_bindings(
    inquire_standalone_rs = function(repo_spec, token) {
      standalone_columns(character())
    }
  )

  result <- suppressMessages(inquire_standalone("owner", "repo"))

  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 0L)
  expect_true("name" %in% names(result))
})

test_that("inquire_standalone reports the repository it crawls", {
  local_mocked_bindings(
    inquire_standalone_rs = function(repo_spec, token) {
      standalone_columns("standalone-cli.R")
    }
  )

  expect_message(
    inquire_standalone("owner", "repo"),
    "owner/repo"
  )
})
