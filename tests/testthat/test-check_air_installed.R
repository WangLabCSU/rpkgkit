test_that("check_air_installed returns invisible TRUE when air is on PATH", {
  local_mocked_bindings(
    Sys.which = function(x) "/usr/local/bin/air",
    .package = "base"
  )
  expect_invisible(check_air_installed())
  expect_true(check_air_installed())
})

test_that("check_air_installed aborts when air is not found", {
  local_mocked_bindings(
    Sys.which = function(x) "",
    interactive = function() FALSE,
    .package = "base"
  )
  expect_error(check_air_installed(), "air is not installed")
})

test_that("check_air_installed gives Linux-specific instructions", {
  local_mocked_bindings(
    Sys.which = function(x) "",
    interactive = function() FALSE,
    .package = "base"
  )
  local_mocked_bindings(
    Sys.info = function() c(sysname = "Linux"),
    .package = "base"
  )
  expect_error(check_air_installed(), "air-installer.sh")
  expect_error(check_air_installed(), "curl")
})

test_that("check_air_installed gives macOS-specific instructions", {
  local_mocked_bindings(
    Sys.which = function(x) "",
    interactive = function() FALSE,
    .package = "base"
  )
  local_mocked_bindings(
    Sys.info = function() c(sysname = "Darwin"),
    .package = "base"
  )
  expect_error(check_air_installed(), "curl --proto '=https' --tlsv1.2")
  expect_error(check_air_installed(), "air-installer.sh")
})

test_that("check_air_installed gives Windows-specific instructions", {
  local_mocked_bindings(
    Sys.which = function(x) "",
    interactive = function() FALSE,
    .package = "base"
  )
  local_mocked_bindings(
    Sys.info = function() c(sysname = "Windows"),
    .package = "base"
  )
  expect_error(check_air_installed(), "powershell")
  expect_error(check_air_installed(), "air-installer.ps1")
})

test_that("check_air_installed gives generic instructions for unknown OS", {
  local_mocked_bindings(
    Sys.which = function(x) "",
    interactive = function() FALSE,
    .package = "base"
  )
  local_mocked_bindings(
    Sys.info = function() c(sysname = "SunOS"),
    .package = "base"
  )
  expect_error(check_air_installed(), "github.com/posit-dev/air")
})

test_that("check_air_installed skips the prompt while testing", {
  local_mocked_bindings(
    Sys.which = function(x) "",
    Sys.info = function() c(sysname = "Linux"),
    interactive = function() TRUE,
    .package = "base"
  )
  local_mocked_bindings(
    askYesNo = function(question) {
      stop("The installation prompt must be skipped.")
    },
    .package = "utils"
  )

  expect_error(check_air_installed(), "air is not installed")
})
