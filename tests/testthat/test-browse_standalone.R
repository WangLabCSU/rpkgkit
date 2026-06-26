# Test: browse_standalone ------------------------------------------------------

# Helper: create a mock GitHub Code Search API response
mock_search_response <- function(items_list) {
  list(
    total_count = length(items_list),
    incomplete_results = FALSE,
    items = items_list
  )
}

# Helper: create a single search result item, mimicking GitHub API format
mock_search_item <- function(
  repo,
  name,
  path = file.path("R", name),
  repo_desc = NULL
) {
  list(
    name = name,
    path = path,
    sha = "abc123",
    url = paste0("https://api.github.com/repos/", repo, "/contents/", path),
    html_url = paste0("https://github.com/", repo, "/blob/main/", path),
    git_url = paste0(
      "https://api.github.com/repos/",
      repo,
      "/git/blobs/abc123"
    ),
    repository = list(
      full_name = repo,
      html_url = paste0("https://github.com/", repo),
      description = repo_desc
    )
  )
}

# ==============================================================================
# Error handling: dots validation
# ==============================================================================

test_that("browse_standalone calls check_dots_empty0", {
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
    gh = function(...) mock_search_response(list()),
    .package = "gh"
  )

  browse_standalone()
  expect_true(dots_checked)
})

# ==============================================================================
# Error handling: package installation checks
# ==============================================================================

test_that("browse_standalone errors when gh is not installed", {
  local_mocked_bindings(
    check_installed = function(pkg, ...) {
      if ("gh" %in% pkg) {
        rlang::abort("gh is not installed")
      }
      invisible()
    },
    .package = "rlang"
  )

  expect_error(browse_standalone(), "gh is not installed")
})

test_that("browse_standalone errors when dplyr is not installed", {
  local_mocked_bindings(
    check_installed = function(pkg, ...) {
      if ("dplyr" %in% pkg) {
        rlang::abort("dplyr is not installed")
      }
      invisible()
    },
    .package = "rlang"
  )

  expect_error(browse_standalone(), "dplyr is not installed")
})

# ==============================================================================
# Empty / no-results cases
# ==============================================================================

test_that("browse_standalone returns empty tibble when no standalone files exist", {
  local_mocked_bindings(
    check_installed = function(pkg, ...) invisible(),
    .package = "rlang"
  )

  local_mocked_bindings(
    gh = function(...) mock_search_response(list()),
    .package = "gh"
  )

  result <- browse_standalone()
  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 0L)

  expected_cols <- c(
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
  expect_setequal(names(result), expected_cols)
})

# ==============================================================================
# Results parsing: single item
# ==============================================================================

test_that("browse_standalone parses a single result into expected columns", {
  local_mocked_bindings(
    check_installed = function(pkg, ...) invisible(),
    .package = "rlang"
  )

  local_mocked_bindings(
    gh = function(...) mock_search_response(list(
      mock_search_item("owner/repo1", "standalone-utils.R")
    )),
    .package = "gh"
  )

  result <- browse_standalone()
  expect_equal(nrow(result), 1L)
  expect_equal(result$repo, "owner/repo1")
  expect_equal(result$name, "standalone-utils.R")
  expect_equal(result$path, "R/standalone-utils.R")
  expect_equal(result$sha, "abc123")
  expect_match(result$url, "owner/repo1")
  expect_match(result$html_url, "owner/repo1")
  expect_match(result$git_url, "owner/repo1")
  expect_match(result$repo_url, "owner/repo1")
})

# ==============================================================================
# Results parsing: multiple items
# ==============================================================================

test_that("browse_standalone parses multiple results", {
  local_mocked_bindings(
    check_installed = function(pkg, ...) invisible(),
    .package = "rlang"
  )

  local_mocked_bindings(
    gh = function(...) mock_search_response(list(
      mock_search_item("owner/repo1", "standalone-utils.R"),
      mock_search_item("owner/repo2", "standalone-helpers.R"),
      mock_search_item("owner/repo3", "standalone-parsers.R")
    )),
    .package = "gh"
  )

  result <- browse_standalone()
  expect_equal(nrow(result), 3L)
  expect_equal(result$repo, c("owner/repo1", "owner/repo2", "owner/repo3"))
})

# ==============================================================================
# Filtering: non-standalone filenames are excluded
# ==============================================================================

test_that("browse_standalone filters out files not starting with standalone-", {
  local_mocked_bindings(
    check_installed = function(pkg, ...) invisible(),
    .package = "rlang"
  )

  local_mocked_bindings(
    gh = function(...) mock_search_response(list(
      mock_search_item("owner/repo1", "standalone-utils.R"),
      mock_search_item("owner/repo1", "other-file.R"),    # should be filtered
      mock_search_item("owner/repo2", "standalone-parsers.R"),
      mock_search_item("owner/repo2", "import-helper.R")   # should be filtered
    )),
    .package = "gh"
  )

  result <- browse_standalone()
  expect_equal(nrow(result), 2L)
  expect_equal(result$name, c("standalone-utils.R", "standalone-parsers.R"))
})

# ==============================================================================
# NULL repo_description → NA
# ==============================================================================

test_that("browse_standalone converts NULL repo_description to NA", {
  local_mocked_bindings(
    check_installed = function(pkg, ...) invisible(),
    .package = "rlang"
  )

  # item with description = NULL
  item_no_desc <- mock_search_item("owner/repo1", "standalone-utils.R")
  # item with description provided
  item_with_desc <- mock_search_item(
    "owner/repo2",
    "standalone-helpers.R",
    repo_desc = "An R package"
  )

  local_mocked_bindings(
    gh = function(...) mock_search_response(list(item_no_desc, item_with_desc)),
    .package = "gh"
  )

  result <- browse_standalone()
  expect_true(is.na(result$repo_description[1]))
  expect_equal(result$repo_description[2], "An R package")
})

# ==============================================================================
# Warning on empty results
# ==============================================================================

test_that("browse_standalone warns when no result items are returned", {
  local_mocked_bindings(
    check_installed = function(pkg, ...) invisible(),
    .package = "rlang"
  )

  local_mocked_bindings(
    gh = function(...) mock_search_response(list()),
    .package = "gh"
  )

  expect_warning(
    browse_standalone(),
    "No standalone files found"
  )
})

# ==============================================================================
# Response without $items field (gh edge case)
# ==============================================================================

test_that("browse_standalone handles response without $items field", {
  local_mocked_bindings(
    check_installed = function(pkg, ...) invisible(),
    .package = "rlang"
  )

  # gh::gh with some endpoints may return the list directly
  local_mocked_bindings(
    gh = function(...) list(
      mock_search_item("owner/repo1", "standalone-utils.R")
    ),
    .package = "gh"
  )

  result <- browse_standalone()
  expect_equal(nrow(result), 1L)
  expect_equal(result$name, "standalone-utils.R")
  expect_equal(result$repo, "owner/repo1")
})
