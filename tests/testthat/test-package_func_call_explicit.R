# ---------------------------------------------------------------------------
# package_func_call_explicit -- integration tests
# ---------------------------------------------------------------------------

test_that("aborts when path is not a package", {
  expect_error(
    package_func_call_explicit(tempdir()),
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
    package_func_call_explicit(pkg, use_packages = "dplyr"),
    "Successfully processed all 1 file"
  )
})

test_that("processes multiple R files", {
  pkg <- withr::local_tempdir()
  dir.create(file.path(pkg, "R"), recursive = TRUE)
  writeLines("filter(mpg > 20)", file.path(pkg, "R", "foo.R"))
  writeLines("select(df, a, b)", file.path(pkg, "R", "bar.R"))
  writeLines(
    c("Package: testpkg", "Version: 0.0.1"),
    file.path(pkg, "DESCRIPTION")
  )

  expect_message(
    package_func_call_explicit(pkg, use_packages = "dplyr"),
    "Successfully processed all 2 files"
  )
})

test_that("passes use_packages and ignore_functions to make_func_call_explicit", {
  pkg <- withr::local_tempdir()
  dir.create(file.path(pkg, "R"), recursive = TRUE)
  writeLines("filter(mpg > 20)", file.path(pkg, "R", "foo.R"))
  writeLines(
    c("Package: testpkg", "Version: 0.0.1"),
    file.path(pkg, "DESCRIPTION")
  )

  called_with <- list()
  local_mocked_bindings(
    make_func_call_explicit = function(
      path,
      use_packages,
      ignore_functions,
      ...
    ) {
      called_with <<- append(
        called_with,
        list(list(
          path = path,
          use_packages = use_packages,
          ignore_functions = ignore_functions
        ))
      )
    },
    .package = "rpkgkit"
  )

  package_func_call_explicit(
    pkg,
    use_packages = c("dplyr", "tidyr"),
    ignore_functions = c("library", "require")
  )

  expect_length(called_with, 1L)
  expect_match(called_with[[1L]]$path, "foo\\.R$")
  expect_equal(called_with[[1L]]$use_packages, c("dplyr", "tidyr"))
  expect_equal(called_with[[1L]]$ignore_functions, c("library", "require"))
})

test_that("returns invisibly when files are processed successfully", {
  pkg <- withr::local_tempdir()
  dir.create(file.path(pkg, "R"), recursive = TRUE)
  writeLines("filter(mpg > 20)", file.path(pkg, "R", "foo.R"))
  writeLines(
    c("Package: testpkg", "Version: 0.0.1"),
    file.path(pkg, "DESCRIPTION")
  )

  expect_invisible(package_func_call_explicit(pkg, use_packages = "dplyr"))
})
