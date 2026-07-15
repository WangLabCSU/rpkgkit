# Test: open_cffinit ------------------------------------------------------------

# ==============================================================================
# Normal behavior: opens correct URL
# ==============================================================================

test_that("open_cffinit calls browseURL with the CFF initializer URL", {
  url_called <- NULL

  local_mocked_bindings(
    browseURL = function(url) {
      url_called <<- url
      invisible()
    },
    .package = "utils"
  )

  open_cffinit()
  expect_equal(
    url_called,
    "https://citation-file-format.github.io/cff-initializer-javascript/#/"
  )
})

# ==============================================================================
# Return value: invisible TRUE
# ==============================================================================

test_that("open_cffinit returns invisible TRUE", {
  local_mocked_bindings(
    browseURL = function(url) invisible(),
    .package = "utils"
  )

  result <- open_cffinit()
  expect_true(result)
})

# ==============================================================================
# Error handling: dots must be empty
# ==============================================================================

test_that("open_cffinit errors when extra arguments are supplied", {
  local_mocked_bindings(
    browseURL = function(url) invisible(),
    .package = "utils"
  )

  expect_error(
    open_cffinit(extra_arg = "foo"),
    class = "rlib_error_dots"
  )
})

# ==============================================================================
# Side effect: browseURL is called exactly once
# ==============================================================================

test_that("open_cffinit calls browseURL exactly once", {
  call_count <- 0L

  local_mocked_bindings(
    browseURL = function(url) {
      call_count <<- call_count + 1L
      invisible()
    },
    .package = "utils"
  )

  open_cffinit()
  expect_equal(call_count, 1L)
})
