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
    list.files = function(...) character(0),
    .package = "base"
  )
  expect_error(package_lost_glue_brace())
})

# ---------------------------------------------------------------------------
# scan_file_braces -- unit tests
# ---------------------------------------------------------------------------

test_that("scan_file_braces returns ok=TRUE for clean file with no glue/cli", {
  tmp <- withr::local_tempfile(fileext = ".R")
  writeLines('message("ok")', tmp)
  res <- scan_file_braces(tmp)
  expect_true(res$ok)
  expect_length(res$errors, 0)
  expect_equal(res$file, tmp)
})

test_that("scan_file_braces returns ok=TRUE for file with balanced braces", {
  tmp <- withr::local_tempfile(fileext = ".R")
  writeLines('glue::glue("Hello {name}!")', tmp)
  res <- scan_file_braces(tmp)
  expect_true(res$ok)
  expect_length(res$errors, 0)
})

test_that("scan_file_braces returns ok=FALSE for file with missing closing brace", {
  tmp <- withr::local_tempfile(fileext = ".R")
  writeLines('glue::glue("Hello {name")', tmp)
  res <- scan_file_braces(tmp)
  expect_false(res$ok)
  expect_length(res$errors, 1)
  expect_equal(res$errors[[1]]$line, 1)
})

test_that("scan_file_braces returns ok=FALSE for file with extra closing brace", {
  tmp <- withr::local_tempfile(fileext = ".R")
  writeLines('glue::glue("Hello name}")', tmp)
  res <- scan_file_braces(tmp)
  expect_false(res$ok)
  expect_length(res$errors, 1)
})

test_that("scan_file_braces reports errors for multiple issues in same file", {
  tmp <- withr::local_tempfile(fileext = ".R")
  writeLines(
    c('glue::glue("bad {a")', 'cli::cli_alert_info("bad {b")'),
    tmp
  )
  res <- scan_file_braces(tmp)
  expect_false(res$ok)
  expect_length(res$errors, 2)
  expect_setequal(vapply(res$errors, `[[`, integer(1), "line"), c(1L, 2L))
})

test_that("scan_file_braces caret references original source line", {
  tmp <- withr::local_tempfile(fileext = ".R")
  writeLines('glue::glue("Hello {name")', tmp)
  res <- scan_file_braces(tmp)
  expect_match(res$errors[[1]]$caret, "glue::glue", fixed = TRUE)
  expect_match(res$errors[[1]]$caret, "Hello {name", fixed = TRUE)
  expect_true(grepl("\\^", res$errors[[1]]$caret))
})

test_that("scan_file_braces handles empty file", {
  tmp <- withr::local_tempfile(fileext = ".R")
  writeLines(character(0), tmp)
  res <- scan_file_braces(tmp)
  expect_true(res$ok)
  expect_length(res$errors, 0)
})

test_that("scan_file_braces handles file with only comments", {
  tmp <- withr::local_tempfile(fileext = ".R")
  writeLines(c("# just a comment", "# glue::glue(\"something\")"), tmp)
  res <- scan_file_braces(tmp)
  expect_true(res$ok)
  expect_length(res$errors, 0)
})
