test_that("aborts when path is not a package root", {
  tmp <- withr::local_tempdir()

  expect_error(
    use_bugreports(url = "https://github.com/foo/bar/issues", path = tmp),
    "not an R package root"
  )
})

test_that("aborts when ... is not empty", {
  tmp <- withr::local_tempdir()
  file.create(file.path(tmp, "DESCRIPTION"))

  expect_error(
    use_bugreports(
      url = "https://github.com/foo/bar/issues",
      path = tmp,
      extra = "x"
    ),
    "must be empty"
  )
})

test_that("uses explicit url", {
  tmp <- withr::local_tempdir()
  file.create(file.path(tmp, "DESCRIPTION"))

  local_mocked_bindings(
    proj_set = function(...) NULL,
    .package = "usethis"
  )
  local_mocked_bindings(
    desc_set = function(key, value, file) value,
    .package = "desc"
  )

  expect_equal(
    use_bugreports(url = "https://example.com/bugs", path = tmp),
    "https://example.com/bugs"
  )
})

test_that("derives url from git remote by appending /issues", {
  tmp <- withr::local_tempdir()
  file.create(file.path(tmp, "DESCRIPTION"))

  local_mocked_bindings(
    proj_set = function(...) NULL,
    git_remotes = function(...) c(origin = "git@github.com:foo/bar.git"),
    .package = "usethis"
  )
  local_mocked_bindings(
    desc_set = function(key, value, file) value,
    .package = "desc"
  )

  expect_equal(
    use_bugreports(path = tmp),
    "https://github.com/foo/bar/issues"
  )
})

test_that("aborts when no git remote and no url given", {
  tmp <- withr::local_tempdir()
  file.create(file.path(tmp, "DESCRIPTION"))

  local_mocked_bindings(
    proj_set = function(...) NULL,
    git_remotes = function(...) character(),
    .package = "usethis"
  )

  expect_error(use_bugreports(path = tmp), "No .+ remote configured")
})

test_that("returns invisibly", {
  tmp <- withr::local_tempdir()
  file.create(file.path(tmp, "DESCRIPTION"))

  local_mocked_bindings(
    proj_set = function(...) NULL,
    .package = "usethis"
  )
  local_mocked_bindings(
    desc_set = function(...) invisible(NULL),
    .package = "desc"
  )

  expect_invisible(
    use_bugreports(url = "https://github.com/foo/bar/issues", path = tmp)
  )
})
