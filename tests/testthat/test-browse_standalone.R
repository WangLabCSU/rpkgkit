# Test: browse_standalone -------------------------------------------------------
#
# The crawl runs in Rust (`browse_standalone_rs()`): these tests cover the R
# interface, i.e. argument validation, the arguments handed to the crawler, the
# empty-result warning and the conversion of the returned columns into a tibble.

# Helper: the named columns that `browse_standalone_rs()` returns.
search_columns <- function(
  repos,
  descriptions = rep(NA_character_, length(repos))
) {
  count <- length(repos)
  list(
    repo = repos,
    name = rep("standalone-utils.R", count),
    path = rep("R/standalone-utils.R", count),
    sha = rep("abc123", count),
    url = rep(
      "https://api.github.com/repos/owner/repo/contents/R/standalone-utils.R",
      count
    ),
    html_url = rep(
      "https://github.com/owner/repo/blob/main/R/standalone-utils.R",
      count
    ),
    git_url = rep(
      "https://api.github.com/repos/owner/repo/git/blobs/abc123",
      count
    ),
    repo_url = if (count == 0L) {
      character()
    } else {
      paste0("https://github.com/", repos)
    },
    repo_description = as.character(descriptions)
  )
}

# ==============================================================================
# Argument validation
# ==============================================================================

test_that("browse_standalone rejects arguments in `...`", {
  expect_error(
    browse_standalone(not_an_argument = TRUE),
    "must be empty"
  )
})

test_that("browse_standalone validates per_page", {
  expect_error(browse_standalone(per_page = 0), "must be")
  expect_error(browse_standalone(per_page = 101), "must be")
  expect_error(browse_standalone(per_page = "100"), "must be")
})

test_that("browse_standalone validates limit", {
  expect_error(browse_standalone(limit = 0), "must be")
  expect_error(browse_standalone(limit = -1), "must be")
})

test_that("browse_standalone reports a crawler failure", {
  local_mocked_bindings(
    browse_standalone_rs = function(per_page, limit, token) {
      rlang::abort("GitHub returned HTTP 403")
    }
  )

  expect_error(browse_standalone(), "HTTP 403")
})

# ==============================================================================
# Arguments handed to the crawler
# ==============================================================================

test_that("browse_standalone forwards per_page, limit and token", {
  seen <- NULL
  local_mocked_bindings(
    browse_standalone_rs = function(per_page, limit, token) {
      seen <<- list(per_page = per_page, limit = limit, token = token)
      search_columns("owner/repo")
    }
  )
  withr::local_envvar(GITHUB_PAT = "pat-token")

  suppressMessages(browse_standalone(per_page = 50L, limit = 20L))

  expect_identical(seen$per_page, 50L)
  expect_identical(seen$limit, 20)
  expect_identical(seen$token, "pat-token")
})

test_that("browse_standalone turns limit = Inf into a finite request", {
  seen <- NULL
  local_mocked_bindings(
    browse_standalone_rs = function(per_page, limit, token) {
      seen <<- limit
      search_columns("owner/repo")
    }
  )

  suppressMessages(browse_standalone(limit = Inf))

  expect_true(is.infinite(seen))
})

test_that("browse_standalone prefers an explicit token", {
  seen <- NULL
  local_mocked_bindings(
    browse_standalone_rs = function(per_page, limit, token) {
      seen <<- token
      search_columns("owner/repo")
    }
  )
  withr::local_envvar(GITHUB_PAT = "pat-token")

  suppressMessages(browse_standalone(token = "explicit"))

  expect_identical(seen, "explicit")
})

# ==============================================================================
# Output shape
# ==============================================================================

test_that("browse_standalone returns the documented columns", {
  local_mocked_bindings(
    browse_standalone_rs = function(per_page, limit, token) {
      search_columns(c("owner/repo", "other/repo2"), c("An R package", NA))
    }
  )

  result <- suppressMessages(browse_standalone())

  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 2L)
  expect_named(
    result,
    c(
      "repo",
      "name",
      "path",
      "sha",
      "url",
      "html_url",
      "git_url",
      "repo_url",
      "repo_description"
    )
  )
})

test_that("browse_standalone keeps a missing repository description as NA", {
  local_mocked_bindings(
    browse_standalone_rs = function(per_page, limit, token) {
      search_columns(c("owner/repo", "other/repo2"), c("An R package", NA))
    }
  )

  result <- suppressMessages(browse_standalone())

  expect_equal(result$repo_description, c("An R package", NA_character_))
})

test_that("browse_standalone warns and returns a zero-row tibble on no match", {
  local_mocked_bindings(
    browse_standalone_rs = function(per_page, limit, token) {
      search_columns(character())
    }
  )

  expect_warning(
    result <- suppressMessages(browse_standalone()),
    "No standalone files found"
  )
  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 0L)
})

test_that("browse_standalone announces the search", {
  local_mocked_bindings(
    browse_standalone_rs = function(per_page, limit, token) {
      search_columns("owner/repo")
    }
  )

  expect_message(browse_standalone(), "standalone")
})
