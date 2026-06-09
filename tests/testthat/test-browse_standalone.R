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
