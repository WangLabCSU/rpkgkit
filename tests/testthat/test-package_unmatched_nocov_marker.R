# ---------------------------------------------------------------------------
# package_unmatched_nocov_marker -- integration tests
# ---------------------------------------------------------------------------

marker_start <- paste0("# nocov", " start")
marker_end <- paste0("# nocov", " end")

# Fill `pkg` with a DESCRIPTION and the given files (path -> lines).
write_test_pkg <- function(pkg, files = list()) {
  writeLines(
    c("Package: testpkg", "Version: 0.0.1"),
    file.path(pkg, "DESCRIPTION")
  )
  for (name in names(files)) {
    target <- file.path(pkg, name)
    dir.create(dirname(target), recursive = TRUE, showWarnings = FALSE)
    writeLines(files[[name]], target)
  }
  pkg
}

test_that("package_unmatched_nocov_marker aborts when path is not a package", {
  non_pkg <- withr::local_tempdir()
  expect_error(
    package_unmatched_nocov_marker(non_pkg),
    "is not an R package"
  )
})

test_that("package_unmatched_nocov_marker returns TRUE for a package with no R files", {
  pkg <- write_test_pkg(withr::local_tempdir())
  dir.create(file.path(pkg, "R"))
  expect_true(package_unmatched_nocov_marker(pkg))
})

test_that("package_unmatched_nocov_marker returns TRUE when all markers are consistent", {
  pkg <- write_test_pkg(
    withr::local_tempdir(),
    list(
      "R/foo.R" = c(marker_start, "a <- 1", marker_end),
      "R/bar.R" = c("b <- 2", marker_start, "c <- 3")
    )
  )
  expect_true(package_unmatched_nocov_marker(pkg))
})

test_that("package_unmatched_nocov_marker detects problems in R/ files", {
  pkg <- write_test_pkg(
    withr::local_tempdir(),
    list("R/foo.R" = c("a <- 1", marker_end))
  )
  expect_false(package_unmatched_nocov_marker(pkg))
})

test_that("package_unmatched_nocov_marker reports file name and line", {
  pkg <- write_test_pkg(
    withr::local_tempdir(),
    list("R/foo.R" = c("a <- 1", marker_end))
  )
  expect_message(
    package_unmatched_nocov_marker(pkg),
    "R/foo.R",
    fixed = TRUE
  )
  expect_message(
    package_unmatched_nocov_marker(pkg),
    "`nocov end` at line 2, column 1 has no matching `nocov start`",
    fixed = TRUE
  )
  expect_message(
    package_unmatched_nocov_marker(pkg),
    paste0(marker_end, "\n", strrep("^", nchar(marker_end))),
    fixed = TRUE
  )
})

test_that("package_unmatched_nocov_marker scans tests/testthat by default", {
  pkg <- write_test_pkg(
    withr::local_tempdir(),
    list(
      "R/foo.R" = "a <- 1",
      "tests/testthat/test-a.R" = c("test_that", marker_end)
    )
  )
  expect_false(package_unmatched_nocov_marker(pkg))
  expect_true(package_unmatched_nocov_marker(pkg, dirs = "R"))
})

test_that("package_unmatched_nocov_marker counts problems across files", {
  pkg <- write_test_pkg(
    withr::local_tempdir(),
    list(
      "R/foo.R" = marker_end,
      "R/bar.R" = c(marker_end, "a <- 1", marker_end),
      "R/baz.R" = c(marker_start, "b <- 2", marker_end)
    )
  )
  expect_false(package_unmatched_nocov_marker(pkg))
  expect_message(
    package_unmatched_nocov_marker(pkg),
    "Found 3 mismatched `nocov` markers in 2 of 3 files",
    fixed = TRUE
  )
})

test_that("package_unmatched_nocov_marker is silent with verbose = FALSE", {
  bad <- write_test_pkg(
    withr::local_tempdir(),
    list("R/foo.R" = marker_end)
  )
  expect_silent(package_unmatched_nocov_marker(bad, verbose = FALSE))

  ok <- write_test_pkg(
    withr::local_tempdir(),
    list("R/foo.R" = "a <- 1")
  )
  expect_silent(package_unmatched_nocov_marker(ok, verbose = FALSE))
})

test_that("package_unmatched_nocov_marker returns invisibly", {
  pkg <- write_test_pkg(
    withr::local_tempdir(),
    list("R/foo.R" = marker_end)
  )
  expect_invisible(package_unmatched_nocov_marker(pkg))
})
