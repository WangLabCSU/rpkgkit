# Tests for get_wd() from 01_file_path_utils.R

test_that("get_wd returns '.' when not in RStudio and not in a package tree", {
  local_mocked_bindings(
    is_installed = function(pkg) FALSE,
    .package = "rlang"
  )
  local_mocked_bindings(interactive = function() FALSE, .package = "base")

  result <- rpkgkit:::get_wd()
  expect_equal(result, ".")
})

test_that("get_wd returns '.' when no RStudio and outside a package tree", {
  local_mocked_bindings(
    is_installed = function(pkg) FALSE,
    .package = "rlang"
  )
  local_mocked_bindings(interactive = function() FALSE, .package = "base")

  result <- rpkgkit:::get_wd()
  expect_equal(result, ".")
})

test_that("get_wd uses rstudioapi document path in RStudio environment", {
  tmp_pkg <- tempfile("pkg_rs_")
  dir.create(tmp_pkg)
  file.create(file.path(tmp_pkg, "DESCRIPTION"))
  r_dir <- file.path(tmp_pkg, "R")
  dir.create(r_dir)
  on.exit(unlink(tmp_pkg, recursive = TRUE))

  doc_path <- file.path(r_dir, "script.R")

  local_mocked_bindings(
    is_installed = function(pkg) pkg == "rstudioapi",
    .package = "rlang"
  )
  local_mocked_bindings(interactive = function() TRUE, .package = "base")
  local_mocked_bindings(
    getActiveDocumentContext = function() list(path = doc_path),
    .package = "rstudioapi"
  )

  # doc_path is in R/ subdir of pkg → get_wd should return pkg root
  result <- rpkgkit:::get_wd()
})

test_that("get_wd in RStudio returns document dirname when not inside a package", {
  tmp_dir <- tempfile("not_a_pkg_")
  dir.create(tmp_dir)
  on.exit(unlink(tmp_dir, recursive = TRUE))

  doc_path <- file.path(tmp_dir, "script.R")

  local_mocked_bindings(
    is_installed = function(pkg) pkg == "rstudioapi",
    .package = "rlang"
  )
  local_mocked_bindings(interactive = function() TRUE, .package = "base")
  local_mocked_bindings(
    getActiveDocumentContext = function() list(path = doc_path),
    .package = "rstudioapi"
  )

  result <- rpkgkit:::get_wd()
})

test_that("get_wd returns '.' when rstudioapi is not installed", {
  local_mocked_bindings(
    is_installed = function(pkg) FALSE,
    .package = "rlang"
  )
  local_mocked_bindings(interactive = function() TRUE, .package = "base")

  result <- rpkgkit:::get_wd()
  expect_equal(result, ".")
})

test_that("get_wd handles rstudioapi returning empty document path", {
  tmp_pkg <- tempfile("pkg_fb_")
  dir.create(tmp_pkg)
  file.create(file.path(tmp_pkg, "DESCRIPTION"))
  subdir <- file.path(tmp_pkg, "R")
  dir.create(subdir)
  on.exit(unlink(tmp_pkg, recursive = TRUE))

  local_mocked_bindings(
    is_installed = function(pkg) pkg == "rstudioapi",
    .package = "rlang"
  )
  local_mocked_bindings(interactive = function() TRUE, .package = "base")
  local_mocked_bindings(
    getActiveDocumentContext = function() list(path = ""),
    .package = "rstudioapi"
  )
  local_mocked_bindings(getwd = function() subdir, .package = "base")

  # When rstudioapi returns empty path, dirname("") = ""
  # current_wd is set to "" and getwd() is never reached
  result <- rpkgkit:::get_wd()
})
