# Tests for get_positron_version() from R/91_get_positron_version.R

test_that("get_positron_version() returns POSITRON_VERSION inside Positron", {
  withr::local_envvar(
    POSITRON = "1",
    POSITRON_VERSION = "2025.01.0",
    POSITRON_LONG_VERSION = "2025.01.0-123"
  )
  local_mocked_bindings(
    Sys.which = function(x) "",
    system2 = function(...) stop("system2() should not be called"),
    .package = "base"
  )

  version <- get_positron_version()

  expect_equal(version, "2025.01.0")
  expect_type(version, "character")
  expect_length(version, 1L)
})

test_that("get_positron_version(long = TRUE) returns POSITRON_LONG_VERSION", {
  withr::local_envvar(
    POSITRON = "1",
    POSITRON_VERSION = "2025.01.0",
    POSITRON_LONG_VERSION = "2025.01.0-123"
  )
  local_mocked_bindings(
    Sys.which = function(x) "",
    .package = "base"
  )

  expect_equal(get_positron_version(long = TRUE), "2025.01.0-123")
})

test_that("get_positron_version() falls back to .ps.positron_version()", {
  withr::local_envvar(
    POSITRON = "1",
    POSITRON_VERSION = NA,
    POSITRON_LONG_VERSION = NA
  )
  assign(".ps.positron_version", function() "2024.12.0-99", envir = globalenv())
  withr::defer(rm(".ps.positron_version", envir = globalenv()))
  local_mocked_bindings(
    Sys.which = function(x) "",
    .package = "base"
  )

  expect_equal(get_positron_version(), "2024.12.0-99")
})

test_that("get_positron_version() ignores .ps.positron_version() outside Positron", {
  withr::local_envvar(
    POSITRON = NA,
    POSITRON_VERSION = NA,
    POSITRON_LONG_VERSION = NA
  )
  assign(".ps.positron_version", function() "2024.12.0-99", envir = globalenv())
  withr::defer(rm(".ps.positron_version", envir = globalenv()))
  local_mocked_bindings(
    Sys.which = function(x) "",
    .package = "base"
  )

  expect_identical(get_positron_version(), NA_character_)
})

test_that("get_positron_version() ignores environment variables outside Positron", {
  withr::local_envvar(
    POSITRON = NA,
    POSITRON_VERSION = "2025.01.0",
    POSITRON_LONG_VERSION = "2025.01.0-123"
  )
  local_mocked_bindings(
    Sys.which = function(x) "",
    .package = "base"
  )

  expect_identical(get_positron_version(), NA_character_)
  expect_identical(get_positron_version(long = TRUE), NA_character_)
})

test_that("get_positron_version() falls back to the positron CLI", {
  withr::local_envvar(
    POSITRON = NA,
    POSITRON_VERSION = NA,
    POSITRON_LONG_VERSION = NA
  )
  local_mocked_bindings(
    Sys.which = function(x) "/usr/local/bin/positron",
    system2 = function(...) "2025.01.0",
    .package = "base"
  )

  expect_equal(get_positron_version(), "2025.01.0")
})

test_that("get_positron_version(long = TRUE) skips POSITRON_VERSION", {
  withr::local_envvar(
    POSITRON = "1",
    POSITRON_VERSION = "2025.01.0",
    POSITRON_LONG_VERSION = NA
  )
  local_mocked_bindings(
    Sys.which = function(x) "/usr/local/bin/positron",
    system2 = function(...) "2025.01.0-123",
    .package = "base"
  )

  expect_equal(get_positron_version(long = TRUE), "2025.01.0-123")
})

test_that("get_positron_version() calls the CLI with --version and trims output", {
  withr::local_envvar(
    POSITRON = NA,
    POSITRON_VERSION = NA,
    POSITRON_LONG_VERSION = NA
  )

  capture <- new.env(parent = emptyenv())
  local_mocked_bindings(
    Sys.which = function(x) "/usr/local/bin/positron",
    system2 = function(command, args, stderr = TRUE, ...) {
      capture$command <- command
      capture$args <- args
      capture$stderr <- stderr
      c("  2025.01.0-123  ", "second line")
    },
    .package = "base"
  )

  expect_equal(get_positron_version(), "2025.01.0-123")
  expect_equal(capture$command, "/usr/local/bin/positron")
  expect_equal(capture$args, "--version")
  expect_false(capture$stderr)
})

test_that("get_positron_version() returns NA when the positron CLI is missing", {
  withr::local_envvar(
    POSITRON = NA,
    POSITRON_VERSION = NA,
    POSITRON_LONG_VERSION = NA
  )
  local_mocked_bindings(
    Sys.which = function(x) "",
    system2 = function(...) stop("system2() should not be called"),
    .package = "base"
  )

  expect_identical(get_positron_version(), NA_character_)
})

test_that("get_positron_version() returns NA when the CLI produces no output", {
  withr::local_envvar(
    POSITRON = NA,
    POSITRON_VERSION = NA,
    POSITRON_LONG_VERSION = NA
  )
  local_mocked_bindings(
    Sys.which = function(x) "/usr/local/bin/positron",
    system2 = function(...) character(),
    .package = "base"
  )

  expect_identical(get_positron_version(), NA_character_)
})

test_that("get_positron_version() returns NA when the CLI call fails", {
  withr::local_envvar(
    POSITRON = NA,
    POSITRON_VERSION = NA,
    POSITRON_LONG_VERSION = NA
  )
  local_mocked_bindings(
    Sys.which = function(x) "/usr/local/bin/positron",
    system2 = function(...) stop("cannot run positron"),
    .package = "base"
  )

  expect_identical(get_positron_version(), NA_character_)
})

test_that("get_positron_version() falls through when .ps.positron_version() errors", {
  withr::local_envvar(
    POSITRON = "1",
    POSITRON_VERSION = NA,
    POSITRON_LONG_VERSION = NA
  )
  assign(
    ".ps.positron_version",
    function() stop("helper failed"),
    envir = globalenv()
  )
  withr::defer(rm(".ps.positron_version", envir = globalenv()))
  local_mocked_bindings(
    Sys.which = function(x) "/usr/local/bin/positron",
    system2 = function(...) "2025.01.0-456",
    .package = "base"
  )

  expect_equal(get_positron_version(), "2025.01.0-456")
})
