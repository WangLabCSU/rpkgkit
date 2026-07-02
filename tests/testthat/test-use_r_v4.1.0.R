test_that("aborts when path is not a package root", {
  tmp <- withr::local_tempdir()

  expect_error(
    use_r_v4.1.0(path = tmp),
    "not an R package root"
  )
})

test_that("aborts when ... is not empty", {
  tmp <- withr::local_tempdir()
  file.create(file.path(tmp, "DESCRIPTION"))

  expect_error(
    use_r_v4.1.0(path = tmp, extra_arg = "foo"),
    "must be empty"
  )
})

test_that("calls usethis::use_package with R, Depends, and min_version 4.1.0", {
  tmp <- withr::local_tempdir()
  file.create(file.path(tmp, "DESCRIPTION"))

  local_mocked_bindings(
    proj_set = function(...) NULL,
    use_package = function(package, type, min_version, ...) {
      list(package = package, type = type, min_version = min_version)
    },
    .package = "usethis"
  )

  result <- use_r_v4.1.0(path = tmp)
  expect_equal(result$package, "R")
  expect_equal(result$type, "Depends")
  expect_equal(result$min_version, "4.1.0")
})

test_that("returns invisibly", {
  tmp <- withr::local_tempdir()
  file.create(file.path(tmp, "DESCRIPTION"))

  local_mocked_bindings(
    proj_set = function(...) NULL,
    use_package = function(...) invisible(NULL),
    .package = "usethis"
  )

  expect_invisible(use_r_v4.1.0(path = tmp))
})
