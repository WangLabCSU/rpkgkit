test_that("news_md_add_entry creates NEWS.md when it does not exist", {
  tmp <- tempfile("pkg_")
  dir.create(tmp)
  writeLines("Package: testpkg\nVersion: 1.0.0", file.path(tmp, "DESCRIPTION"))
  on.exit(unlink(tmp, recursive = TRUE))

  result <- news_md_add_entry("Added new function foo()", path = tmp)
  expect_equal(result, file.path(tmp, "NEWS.md"))
  expect_true(file.exists(file.path(tmp, "NEWS.md")))

  content <- readLines(file.path(tmp, "NEWS.md"))
  pkg_name <- basename(tmp)
  expect_match(
    content[1],
    sprintf("# %s 1.0.0 \\([0-9]{4}-[0-9]{2}-[0-9]{2}\\)", pkg_name)
  )
  expect_equal(content[3], "## NEW FEATURES")
  expect_equal(content[5], "* Added new function foo()")
})

test_that("news_md_add_entry adds entry to existing NEWS.md", {
  tmp <- tempfile("pkg_")
  dir.create(tmp)
  writeLines("Package: testpkg\nVersion: 1.0.0", file.path(tmp, "DESCRIPTION"))

  existing <- c(
    "# testpkg 1.0.0 (2026-01-01)",
    "",
    "## NEW FEATURES",
    "",
    "* First feature"
  )
  writeLines(existing, file.path(tmp, "NEWS.md"))
  on.exit(unlink(tmp, recursive = TRUE))

  news_md_add_entry("Second feature", path = tmp)

  content <- readLines(file.path(tmp, "NEWS.md"))
  expect_true(any(grepl("Second feature", content)))
})

test_that("news_md_add_entry adds entry with contributor", {
  tmp <- tempfile("pkg_")
  dir.create(tmp)
  writeLines("Package: testpkg\nVersion: 1.0.0", file.path(tmp, "DESCRIPTION"))
  on.exit(unlink(tmp, recursive = TRUE))

  news_md_add_entry("Fixed a bug",
    path = tmp,
    contributor = "johndoe"
  )

  content <- readLines(file.path(tmp, "NEWS.md"))
  expect_true(any(grepl("\\(@johndoe\\)", content)))
})

test_that("news_md_add_entry handles vectorized entries", {
  tmp <- tempfile("pkg_")
  dir.create(tmp)
  writeLines("Package: testpkg\nVersion: 1.0.0", file.path(tmp, "DESCRIPTION"))
  on.exit(unlink(tmp, recursive = TRUE))

  news_md_add_entry(c("Feature A", "Feature B"), path = tmp)

  content <- readLines(file.path(tmp, "NEWS.md"))
  expect_true(any(grepl("Feature A", content)))
  expect_true(any(grepl("Feature B", content)))
})

test_that("news_md_add_entry uses custom version and date", {
  tmp <- tempfile("pkg_")
  dir.create(tmp)
  writeLines("Package: testpkg\nVersion: 1.0.0", file.path(tmp, "DESCRIPTION"))
  on.exit(unlink(tmp, recursive = TRUE))

  news_md_add_entry("Custom version entry",
    path = tmp,
    version = "2.0.0",
    date = "2026-06-01"
  )

  content <- readLines(file.path(tmp, "NEWS.md"))
  pkg_name <- basename(tmp)
  expect_match(content[1], sprintf("%s 2\\.0\\.0 \\(2026-06-01\\)", pkg_name))
})

test_that("news_md_add_entry handles open_section = FALSE", {
  tmp <- tempfile("pkg_")
  dir.create(tmp)
  writeLines("Package: testpkg\nVersion: 1.0.0", file.path(tmp, "DESCRIPTION"))

  existing <- c(
    "# testpkg 1.0.0 (2026-01-01)",
    "",
    "## NEW FEATURES",
    "",
    "* Existing entry"
  )
  writeLines(existing, file.path(tmp, "NEWS.md"))
  on.exit(unlink(tmp, recursive = TRUE))

  news_md_add_entry("Forced new section entry",
    path = tmp,
    open_section = FALSE
  )

  content <- readLines(file.path(tmp, "NEWS.md"))
  expect_true(any(grepl("Forced new section entry", content)))
})

test_that("news_md_add_entry adds entry with pre-existing * prefix correctly", {
  tmp <- tempfile("pkg_")
  dir.create(tmp)
  writeLines("Package: testpkg\nVersion: 1.0.0", file.path(tmp, "DESCRIPTION"))
  on.exit(unlink(tmp, recursive = TRUE))

  news_md_add_entry("* Already has star", path = tmp)

  content <- readLines(file.path(tmp, "NEWS.md"))
  stars <- grep("^\\*", content)
  # Should only appear once
  expect_length(stars, 1)
  expect_match(content[stars[1]], "\\* Already has star")
})

test_that("news_md_add_entry aborts when DESCRIPTION is missing and version is NULL", {
  tmp <- tempfile("pkg_no_desc")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE))

  expect_error(
    news_md_add_entry("test entry", path = tmp),
    "DESCRIPTION"
  )
})

test_that("news_md_add_entry silently defaults to first choice for invalid category", {
  tmp <- tempfile("pkg_")
  dir.create(tmp)
  writeLines("Package: testpkg\nVersion: 1.0.0", file.path(tmp, "DESCRIPTION"))
  on.exit(unlink(tmp, recursive = TRUE))

  # match_arg silently returns default (first choice) for unmatched inputs
  expect_no_error(
    news_md_add_entry("test entry", path = tmp, category = "INVALID")
  )

  content <- readLines(file.path(tmp, "NEWS.md"))
  # Should have used default category "NEW FEATURES"
  expect_true(any(grepl("NEW FEATURES", content)))
})

test_that("news_md_add_entry adds to different category in existing version section", {
  tmp <- tempfile("pkg_")
  dir.create(tmp)
  writeLines("Package: testpkg\nVersion: 1.0.0", file.path(tmp, "DESCRIPTION"))

  existing <- c(
    "# testpkg 1.0.0 (2026-01-01)",
    "",
    "## NEW FEATURES",
    "",
    "* First feature"
  )
  writeLines(existing, file.path(tmp, "NEWS.md"))
  on.exit(unlink(tmp, recursive = TRUE))

  news_md_add_entry("Fixed a crash",
    path = tmp,
    category = "BUG FIXES"
  )

  content <- readLines(file.path(tmp, "NEWS.md"))
  expect_true(any(grepl("BUG FIXES", content)))
  expect_true(any(grepl("Fixed a crash", content)))
})
