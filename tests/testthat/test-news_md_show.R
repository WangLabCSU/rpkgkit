test_that("news_md_show aborts when NEWS.md not found", {
  tmp <- tempfile("empty_pkg")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE))

  expect_error(
    news_md_show(path = tmp),
    "NEWS.md not found"
  )
})

test_that("news_md_show warns when no version sections found", {
  tmp <- tempfile("pkg_")
  dir.create(tmp)

  news_content <- c(
    "Just some text",
    "No version headers here"
  )
  writeLines(news_content, file.path(tmp, "NEWS.md"))
  on.exit(unlink(tmp, recursive = TRUE))

  expect_warning(
    news_md_show(path = tmp),
    "No version sections"
  )
})

test_that("news_md_show displays latest version only", {
  tmp <- tempfile("pkg_")
  dir.create(tmp)

  news_content <- c(
    "# testpkg 2.0.0 (2026-06-01)",
    "",
    "## NEW FEATURES",
    "",
    "* Latest feature",
    "",
    "# testpkg 1.0.0 (2026-01-01)",
    "",
    "## BUG FIXES",
    "",
    "* Old fix",
    ""
  )
  writeLines(news_content, file.path(tmp, "NEWS.md"))
  on.exit(unlink(tmp, recursive = TRUE))

  output <- capture.output(
    result <- news_md_show(path = tmp, version = "latest")
  )

  expect_true(any(grepl("Latest feature", output)))
  expect_false(any(grepl("Old fix", output)))
  expect_invisible(news_md_show(path = tmp, version = "latest"))
})

test_that("news_md_show displays specific version", {
  tmp <- tempfile("pkg_")
  dir.create(tmp)

  news_content <- c(
    "# testpkg 2.0.0 (2026-06-01)",
    "",
    "## NEW FEATURES",
    "",
    "* Latest feature",
    "",
    "# testpkg 1.0.0 (2026-01-01)",
    "",
    "## BUG FIXES",
    "",
    "* Old fix",
    ""
  )
  writeLines(news_content, file.path(tmp, "NEWS.md"))
  on.exit(unlink(tmp, recursive = TRUE))

  output <- capture.output(
    news_md_show(path = tmp, version = "1.0.0")
  )

  expect_true(any(grepl("Old fix", output)))
  expect_false(any(grepl("Latest feature", output)))
})

test_that("news_md_show aborts on unknown version", {
  tmp <- tempfile("pkg_")
  dir.create(tmp)

  news_content <- c(
    "# testpkg 1.0.0 (2026-01-01)",
    "",
    "## NEW FEATURES",
    "",
    "* Some feature",
    ""
  )
  writeLines(news_content, file.path(tmp, "NEWS.md"))
  on.exit(unlink(tmp, recursive = TRUE))

  expect_error(
    news_md_show(path = tmp, version = "9.9.9"),
    "not found"
  )
})

test_that("news_md_show limits to max_versions", {
  tmp <- tempfile("pkg_")
  dir.create(tmp)

  news_content <- c(
    "# testpkg 3.0.0 (2026-06-01)",
    "",
    "## NEW FEATURES",
    "",
    "* v3 feature",
    "",
    "# testpkg 2.0.0 (2026-05-01)",
    "",
    "## BUG FIXES",
    "",
    "* v2 fix",
    "",
    "# testpkg 1.0.0 (2026-01-01)",
    "",
    "## NEW FEATURES",
    "",
    "* v1 feature",
    ""
  )
  writeLines(news_content, file.path(tmp, "NEWS.md"))
  on.exit(unlink(tmp, recursive = TRUE))

  output <- capture.output(
    news_md_show(path = tmp, max_versions = 2)
  )

  expect_true(any(grepl("v3 feature", output)))
  expect_true(any(grepl("v2 fix", output)))
  expect_false(any(grepl("v1 feature", output)))
})

test_that("news_md_show shows all versions when no filter", {
  tmp <- tempfile("pkg_")
  dir.create(tmp)

  news_content <- c(
    "# testpkg 2.0.0 (2026-06-01)",
    "",
    "## NEW FEATURES",
    "",
    "* Latest feature",
    "",
    "# testpkg 1.0.0 (2026-01-01)",
    "",
    "## BUG FIXES",
    "",
    "* Old fix",
    ""
  )
  writeLines(news_content, file.path(tmp, "NEWS.md"))
  on.exit(unlink(tmp, recursive = TRUE))

  output <- capture.output(
    news_md_show(path = tmp)
  )

  expect_true(any(grepl("Latest feature", output)))
  expect_true(any(grepl("Old fix", output)))
})

test_that("news_md_show returns content invisibly", {
  tmp <- tempfile("pkg_")
  dir.create(tmp)

  news_content <- c(
    "# testpkg 1.0.0 (2026-01-01)",
    "",
    "## NEW FEATURES",
    "",
    "* A feature",
    ""
  )
  writeLines(news_content, file.path(tmp, "NEWS.md"))
  on.exit(unlink(tmp, recursive = TRUE))

  output <- capture.output(
    result <- news_md_show(path = tmp, version = "latest")
  )

  expect_type(result, "character")
  expect_true(any(grepl("A feature", result)))
})

test_that("news_md_show handles single version NEWS.md", {
  tmp <- tempfile("pkg_")
  dir.create(tmp)

  # Single version section
  news_content <- c(
    "# testpkg 1.0.0 (2026-01-01)",
    "",
    "## NEW FEATURES",
    "",
    "* Only version",
    ""
  )
  writeLines(news_content, file.path(tmp, "NEWS.md"))
  on.exit(unlink(tmp, recursive = TRUE))

  output <- capture.output(
    news_md_show(path = tmp, version = "latest")
  )

  expect_true(any(grepl("Only version", output)))
})
