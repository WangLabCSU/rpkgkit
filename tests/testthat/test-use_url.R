test_that("aborts when path is not a package root", {
  tmp <- withr::local_tempdir()

  expect_error(
    use_url(url = "https://github.com/foo/bar", path = tmp),
    "not an R package root"
  )
})

test_that("aborts when ... is not empty", {
  tmp <- withr::local_tempdir()
  file.create(file.path(tmp, "DESCRIPTION"))

  expect_error(
    use_url(url = "https://github.com/foo/bar", path = tmp, extra = "x"),
    "must be empty"
  )
})

test_that("uses explicit url and optional pkgdown_url", {
  tmp <- withr::local_tempdir()
  file.create(file.path(tmp, "DESCRIPTION"))

  local_mocked_bindings(
    proj_set = function(...) NULL,
    .package = "usethis"
  )
  local_mocked_bindings(
    desc_set_urls = function(urls, file) urls,
    .package = "desc"
  )

  urls <- use_url(
    url = "https://github.com/foo/bar",
    pkgdown_url = "https://foo.github.io/bar/",
    path = tmp
  )
  expect_equal(
    urls,
    c("https://github.com/foo/bar", "https://foo.github.io/bar/")
  )
})

test_that("detects url from git remote (https)", {
  tmp <- withr::local_tempdir()
  file.create(file.path(tmp, "DESCRIPTION"))

  local_mocked_bindings(
    proj_set = function(...) NULL,
    git_remotes = function(...) c(origin = "https://github.com/foo/bar.git"),
    .package = "usethis"
  )
  local_mocked_bindings(
    desc_set_urls = function(urls, file) urls,
    .package = "desc"
  )

  expect_equal(use_url(path = tmp), "https://github.com/foo/bar")
})

test_that("detects url from git remote (ssh)", {
  tmp <- withr::local_tempdir()
  file.create(file.path(tmp, "DESCRIPTION"))

  local_mocked_bindings(
    proj_set = function(...) NULL,
    git_remotes = function(...) c(origin = "git@github.com:foo/bar.git"),
    .package = "usethis"
  )
  local_mocked_bindings(
    desc_set_urls = function(urls, file) urls,
    .package = "desc"
  )

  expect_equal(use_url(path = tmp), "https://github.com/foo/bar")
})

test_that("aborts when no git remote and no url given", {
  tmp <- withr::local_tempdir()
  file.create(file.path(tmp, "DESCRIPTION"))

  local_mocked_bindings(
    proj_set = function(...) NULL,
    git_remotes = function(...) character(),
    .package = "usethis"
  )

  expect_error(use_url(path = tmp), "No .+ remote configured")
})

test_that("returns invisibly", {
  tmp <- withr::local_tempdir()
  file.create(file.path(tmp, "DESCRIPTION"))

  local_mocked_bindings(
    proj_set = function(...) NULL,
    .package = "usethis"
  )
  local_mocked_bindings(
    desc_set_urls = function(...) invisible(NULL),
    .package = "desc"
  )

  expect_invisible(use_url(url = "https://github.com/foo/bar", path = tmp))
})
