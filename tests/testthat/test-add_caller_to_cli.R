test_that("add_caller_to_cli prepends caller name to character message", {
  captured <- NULL
  mock_cli <- function(...) {
    captured <<- list(...)
  }

  wrapped <- rpkgkit:::add_caller_to_cli(mock_cli, offset = 1L)

  local_mocked_bindings(
    get_caller_name = function(...) "my_func()",
    .package = "rpkgkit"
  )

  wrapped("Hello world")
  expect_equal(captured[[1L]], "[my_func()]: Hello world")
})

test_that("add_caller_to_cli does not modify message when no arguments", {
  captured <- NULL
  # `add_caller_to_cli()` always forwards `.envir`, so the mock mirrors the
  # signature of the cli functions it wraps and keeps `.envir` out of `...`
  mock_cli <- function(..., .envir = parent.frame()) {
    captured <<- list(...)
  }

  wrapped <- rpkgkit:::add_caller_to_cli(mock_cli)

  local_mocked_bindings(
    get_caller_name = function(...) "global",
    .package = "rpkgkit"
  )

  wrapped()
  expect_length(captured, 0L)
})

test_that("add_caller_to_cli does not modify non-character first message", {
  captured <- NULL
  mock_cli <- function(...) {
    captured <<- list(...)
  }

  wrapped <- rpkgkit:::add_caller_to_cli(mock_cli)

  local_mocked_bindings(
    get_caller_name = function(...) "f()",
    .package = "rpkgkit"
  )

  wrapped(42L, "text")
  expect_equal(captured[[1L]], 42L)
  expect_equal(captured[[2L]], "text")
})

test_that("add_caller_to_cli only modifies the first message element", {
  captured <- NULL
  mock_cli <- function(...) {
    captured <<- list(...)
  }

  wrapped <- rpkgkit:::add_caller_to_cli(mock_cli)

  local_mocked_bindings(
    get_caller_name = function(...) "g()",
    .package = "rpkgkit"
  )

  wrapped("first", "second", "third")
  expect_match(captured[[1L]], "^\\[g\\(\\)\\]: first$")
  expect_equal(captured[[2L]], "second")
  expect_equal(captured[[3L]], "third")
})

test_that("add_caller_to_cli passes custom offset to get_caller_name", {
  captured_offset <- NULL
  local_mocked_bindings(
    get_caller_name = function(offset) {
      captured_offset <<- offset
      "custom()"
    },
    .package = "rpkgkit"
  )

  mock_cli <- function(...) {}
  wrapped <- rpkgkit:::add_caller_to_cli(mock_cli, offset = 5L)
  wrapped("msg")

  expect_equal(captured_offset, 5L)
})
