# ---------------------------------------------------------------------------
# package_lost_glue_brace -- integration tests
# ---------------------------------------------------------------------------

test_that("package_lost_glue_brace aborts when path is not a package", {
  expect_error(
    package_lost_glue_brace(tempdir()),
    "is not an R package"
  )
})

test_that("package_lost_glue_brace returns TRUE for package with no R files", {
  pkg <- withr::local_tempdir()
  dir.create(file.path(pkg, "R"))
  writeLines(
    c("Package: testpkg", "Version: 0.0.1"),
    file.path(pkg, "DESCRIPTION")
  )
  expect_true(package_lost_glue_brace(pkg))
})

test_that("package_lost_glue_brace detects unbalanced braces in R/ files", {
  pkg <- withr::local_tempdir()
  dir.create(file.path(pkg, "R"), recursive = TRUE)
  writeLines('glue::glue("Hello {name")', file.path(pkg, "R", "foo.R"))
  writeLines(
    c("Package: testpkg", "Version: 0.0.1"),
    file.path(pkg, "DESCRIPTION")
  )
  expect_false(package_lost_glue_brace(pkg))
})

test_that("package_lost_glue_brace detects unbalanced braces in test files", {
  pkg <- withr::local_tempdir()
  dir.create(file.path(pkg, "R"), recursive = TRUE)
  dir.create(file.path(pkg, "tests", "testthat"), recursive = TRUE)
  writeLines(
    'cli::cli_alert_info("Missing {brace")',
    file.path(pkg, "tests", "testthat", "test-a.R")
  )
  writeLines(
    c("Package: testpkg", "Version: 0.0.1"),
    file.path(pkg, "DESCRIPTION")
  )
  expect_false(package_lost_glue_brace(pkg))
})

test_that("package_lost_glue_brace with test_included = FALSE skips tests", {
  pkg <- withr::local_tempdir()
  dir.create(file.path(pkg, "R"), recursive = TRUE)
  dir.create(file.path(pkg, "tests", "testthat"), recursive = TRUE)
  writeLines(
    'cli::cli_alert_info("Missing {brace")',
    file.path(pkg, "tests", "testthat", "test-a.R")
  )
  # Write a clean file in R/ so we don't get "no files found"
  writeLines('message("ok")', file.path(pkg, "R", "foo.R"))
  writeLines(
    c("Package: testpkg", "Version: 0.0.1"),
    file.path(pkg, "DESCRIPTION")
  )
  expect_true(package_lost_glue_brace(pkg, test_included = FALSE))
})

test_that("package_lost_glue_brace returns invisibly", {
  pkg <- withr::local_tempdir()
  dir.create(file.path(pkg, "R"), recursive = TRUE)
  writeLines('glue::glue("Hello {name")', file.path(pkg, "R", "foo.R"))
  writeLines(
    c("Package: testpkg", "Version: 0.0.1"),
    file.path(pkg, "DESCRIPTION")
  )
  expect_invisible(package_lost_glue_brace(pkg))
})

test_that("package_lost_glue_brace all balanced returns TRUE with success", {
  pkg <- withr::local_tempdir()
  dir.create(file.path(pkg, "R"), recursive = TRUE)
  writeLines('glue::glue("Hello {name}!")', file.path(pkg, "R", "foo.R"))
  writeLines(
    c("Package: testpkg", "Version: 0.0.1"),
    file.path(pkg, "DESCRIPTION")
  )
  expect_true(package_lost_glue_brace(pkg))
})

test_that("package_lost_glue_brace detects multiple files with issues", {
  pkg <- withr::local_tempdir()
  dir.create(file.path(pkg, "R"), recursive = TRUE)
  writeLines('glue::glue("Hello {name")', file.path(pkg, "R", "foo.R"))
  writeLines(
    'cli::cli_alert_info("Missing {brace")',
    file.path(pkg, "R", "bar.R")
  )
  writeLines(
    c("Package: testpkg", "Version: 0.0.1"),
    file.path(pkg, "DESCRIPTION")
  )
  expect_false(package_lost_glue_brace(pkg))
})

test_that("package_lost_glue_brace resolves path from rstudioapi when NULL", {
  local_mocked_bindings(
    getActiveDocumentContext = function() list(path = "/mock/pkg/R/file.R"),
    .package = "rstudioapi"
  )
  local_mocked_bindings(
    is_pkg = function(path) grepl("mock/pkg", path),
    .package = "rpkgkit"
  )
  local_mocked_bindings(
    list.files = function(...) character(0L),
    .package = "base"
  )
  expect_error(package_lost_glue_brace())
})
