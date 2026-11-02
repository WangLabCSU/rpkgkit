test_that("add_timestamp_to_cli prepends timestamp to character messages", {
  # Capture the arguments passed to the wrapped function
  captured <- NULL
  mock_cli <- function(...) {
    captured <<- list(...)
  }

  wrapped <- rpkgkit:::add_timestamp_to_cli(mock_cli)
  wrapped("Hello, world")

  # The first message should have an evaluated timestamp prepended
  expect_match(
    captured[[1L]],
    "^\\[\\d{4}/\\d{2}/\\d{2} \\d{2}:\\d{2}:\\d{2}\\] Hello, world$"
  )
})

test_that("add_timestamp_to_cli does nothing when no messages", {
  captured <- NULL
  mock_cli <- function(...) {
    captured <<- list(...)
  }

  wrapped <- rpkgkit:::add_timestamp_to_cli(mock_cli)
  wrapped()

  expect_length(captured, 0L)
})

test_that("add_timestamp_to_cli does not modify non-character first message", {
  captured <- NULL
  mock_cli <- function(...) {
    captured <<- list(...)
  }

  wrapped <- rpkgkit:::add_timestamp_to_cli(mock_cli)
  wrapped(42L, "some text")

  expect_equal(captured[[1L]], 42L)
  expect_equal(captured[[2L]], "some text")
})

test_that("add_timestamp_to_cli only modifies the first message when character", {
  captured <- NULL
  mock_cli <- function(...) {
    captured <<- list(...)
  }

  wrapped <- rpkgkit:::add_timestamp_to_cli(mock_cli)
  wrapped("First message", "Second message")

  # First message gets timestamp, second is unchanged
  expect_match(
    captured[[1L]],
    "^\\[\\d{4}/\\d{2}/\\d{2} \\d{2}:\\d{2}:\\d{2}\\] First message$"
  )
  expect_equal(captured[[2L]], "Second message")
})

test_that("add_timestamp_to_cli works with named arguments", {
  captured <- NULL
  mock_cli <- function(..., .envir = parent.frame()) {
    captured <<- list(msg = list(...), .envir = .envir)
  }

  wrapped <- rpkgkit:::add_timestamp_to_cli(mock_cli)
  wrapped("msg text", .envir = rlang::current_env())

  expect_match(
    captured$msg[[1L]],
    "^\\[\\d{4}/\\d{2}/\\d{2} \\d{2}:\\d{2}:\\d{2}\\] msg text$"
  )
  expect_true(is.environment(captured$.envir))
})

test_that("add_timestamp_to_cli works with cli::cli_alert_info (integration)", {
  # Use cli_alert_info but pipe output to a file to avoid console output noise
  tmp <- tempfile(fileext = ".txt")
  on.exit(unlink(tmp))

  wrapped <- rpkgkit:::add_timestamp_to_cli(cli::cli_alert_info)

  # We can't easily capture cli output, just verify the function runs without error
  # and returns invisibly as expected
  expect_invisible(wrapped("test message"))
})

test_that("add_timestamp_to_cli produces output with cli_alert_info (integration)", {
  wrapped <- rpkgkit:::add_timestamp_to_cli(cli::cli_alert_info)

  # cli_alert_info outputs via message(), so capture that
  msg_text <- NULL
  withCallingHandlers(
    wrapped("integration test"),
    message = function(m) {
      msg_text <<- conditionMessage(m)
      invokeRestart("muffleMessage")
    }
  )

  # The message should contain an actual timestamp (not raw glue syntax)
  expect_match(msg_text, "\\[\\d{4}/\\d{2}/\\d{2} \\d{2}:\\d{2}:\\d{2}\\]")
  expect_match(msg_text, "integration test")
})

test_that("add_timestamp_to_cli wraps named arguments correctly with mock", {
  captured_msgs <- NULL
  captured_env <- NULL
  mock_cli <- function(..., .envir = parent.frame()) {
    captured_msgs <<- list(...)
    captured_env <<- .envir
    invisible()
  }

  wrapped <- rpkgkit:::add_timestamp_to_cli(mock_cli)
  env <- rlang::new_environment()
  wrapped("A", "B", .envir = env)

  expect_match(
    captured_msgs[[1L]],
    "^\\[\\d{4}/\\d{2}/\\d{2} \\d{2}:\\d{2}:\\d{2}\\] A$"
  )
  expect_equal(captured_msgs[[2L]], "B")
  expect_identical(captured_env, env)
})
