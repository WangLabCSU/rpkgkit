# ---------------------------------------------------------------------------
# package_func_call_explicit -- integration tests
# ---------------------------------------------------------------------------

test_that("aborts when path is not a package", {
  # A dedicated directory rather than `tempdir()` itself: the session temp dir
  # may already hold a DESCRIPTION left behind by another test or a package
  # example, which would make `tempdir()` look like a package.
  non_pkg <- withr::local_tempdir()
  expect_error(
    package_func_call_explicit(non_pkg),
    "is not an R package"
  )
})

test_that("aborts when no R/ directory", {
  pkg <- withr::local_tempdir()
  writeLines(
    c("Package: testpkg", "Version: 0.0.1"),
    file.path(pkg, "DESCRIPTION")
  )
  expect_error(
    package_func_call_explicit(pkg),
    "No .*R/.* directory found"
  )
})

test_that("shows info when R/ is empty", {
  pkg <- withr::local_tempdir()
  dir.create(file.path(pkg, "R"), recursive = TRUE)
  writeLines(
    c("Package: testpkg", "Version: 0.0.1"),
    file.path(pkg, "DESCRIPTION")
  )
  expect_message(
    package_func_call_explicit(pkg),
    "No.*\\.R.*files found"
  )
})

test_that("processes a single R file", {
  pkg <- withr::local_tempdir()
  dir.create(file.path(pkg, "R"), recursive = TRUE)
  writeLines("filter(mpg > 20)", file.path(pkg, "R", "foo.R"))
  writeLines(
    c("Package: testpkg", "Version: 0.0.1"),
    file.path(pkg, "DESCRIPTION")
  )

  expect_message(
    package_func_call_explicit(pkg, use_packages = "stats"),
    "Successfully processed all 1 file"
  )
  expect_equal(
    readLines(file.path(pkg, "R", "foo.R")),
    "stats::filter(mpg > 20)"
  )
})

test_that("processes multiple R files", {
  pkg <- withr::local_tempdir()
  dir.create(file.path(pkg, "R"), recursive = TRUE)
  writeLines("filter(mpg > 20)", file.path(pkg, "R", "foo.R"))
  writeLines("median(df, a, b)", file.path(pkg, "R", "bar.R"))
  writeLines(
    c("Package: testpkg", "Version: 0.0.1"),
    file.path(pkg, "DESCRIPTION")
  )

  expect_message(
    package_func_call_explicit(pkg, use_packages = "stats"),
    "Successfully processed all 2 files"
  )
  expect_equal(
    readLines(file.path(pkg, "R", "bar.R")),
    "stats::median(df, a, b)"
  )
})

test_that("shares one package context between files", {
  pkg <- withr::local_tempdir()
  dir.create(file.path(pkg, "R"), recursive = TRUE)
  writeLines("filter(mpg > 20)", file.path(pkg, "R", "foo.R"))
  writeLines("median(x)", file.path(pkg, "R", "bar.R"))
  writeLines(
    c("Package: testpkg", "Version: 0.0.1"),
    file.path(pkg, "DESCRIPTION")
  )

  context_calls <- 0L
  local_mocked_bindings(
    mfce_package_context = function(use_packages, ignore_functions) {
      context_calls <<- context_calls + 1L
      list(
        use_packages = use_packages,
        ignore_functions = ignore_functions,
        fun_exports = c("filter", "median"),
        fun_packages = c("stats", "stats"),
        data_exports = character(),
        data_packages = character()
      )
    },
    .package = "rpkgkit"
  )

  package_func_call_explicit(
    pkg,
    use_packages = c("stats", "utils"),
    ignore_functions = c("library", "require")
  )

  expect_equal(context_calls, 1L)
  expect_equal(
    readLines(file.path(pkg, "R", "foo.R")),
    "stats::filter(mpg > 20)"
  )
})

test_that("processes every file of a package", {
  pkg <- withr::local_tempdir()
  dir.create(file.path(pkg, "R"), recursive = TRUE)
  writeLines("filter(mpg > 20)", file.path(pkg, "R", "foo.R"))
  writeLines("median(x)", file.path(pkg, "R", "bar.R"))
  writeLines(
    c("Package: testpkg", "Version: 0.0.1"),
    file.path(pkg, "DESCRIPTION")
  )

  paths <- character()
  local_mocked_bindings(
    mfce_process_file = function(path, context) {
      paths <<- c(paths, basename(path))
      list(changed = TRUE, not_found = character())
    },
    .package = "rpkgkit"
  )

  package_func_call_explicit(pkg, use_packages = "stats")

  expect_setequal(paths, c("foo.R", "bar.R"))
})

test_that("keeps going when one file fails", {
  pkg <- withr::local_tempdir()
  dir.create(file.path(pkg, "R"), recursive = TRUE)
  writeLines("filter(mpg > 20)", file.path(pkg, "R", "foo.R"))
  writeLines("median(x)", file.path(pkg, "R", "bar.R"))
  writeLines(
    c("Package: testpkg", "Version: 0.0.1"),
    file.path(pkg, "DESCRIPTION")
  )

  local_mocked_bindings(
    mfce_process_file = function(path, context) {
      if (basename(path) == "bar.R") {
        stop("boom", call. = FALSE)
      }
      list(changed = TRUE, not_found = character())
    },
    .package = "rpkgkit"
  )

  expect_message(
    result <- package_func_call_explicit(pkg, use_packages = "stats"),
    "1 failed"
  )
  expect_false(result)
})

test_that("returns invisibly when files are processed successfully", {
  pkg <- withr::local_tempdir()
  dir.create(file.path(pkg, "R"), recursive = TRUE)
  writeLines("filter(mpg > 20)", file.path(pkg, "R", "foo.R"))
  writeLines(
    c("Package: testpkg", "Version: 0.0.1"),
    file.path(pkg, "DESCRIPTION")
  )

  expect_invisible(package_func_call_explicit(pkg, use_packages = "stats"))
})
