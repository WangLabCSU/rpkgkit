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

  pkg_name <- basename(tmp)
  existing <- c(
    sprintf("# %s 1.0.0 (2026-01-01)", pkg_name),
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

  news_md_add_entry("Fixed a bug", path = tmp, contributor = "johndoe")

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

  news_md_add_entry(
    "Custom version entry",
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

  pkg_name <- basename(tmp)
  existing <- c(
    sprintf("# %s 1.0.0 (2026-01-01)", pkg_name),
    "",
    "## NEW FEATURES",
    "",
    "* Existing entry"
  )
  writeLines(existing, file.path(tmp, "NEWS.md"))
  on.exit(unlink(tmp, recursive = TRUE))

  news_md_add_entry(
    "Forced new section entry",
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

  pkg_name <- basename(tmp)
  existing <- c(
    sprintf("# %s 1.0.0 (2026-01-01)", pkg_name),
    "",
    "## NEW FEATURES",
    "",
    "* First feature"
  )
  writeLines(existing, file.path(tmp, "NEWS.md"))
  on.exit(unlink(tmp, recursive = TRUE))

  news_md_add_entry("Fixed a crash", path = tmp, category = "BUG FIXES")

  content <- readLines(file.path(tmp, "NEWS.md"))
  expect_true(any(grepl("BUG FIXES", content)))
  expect_true(any(grepl("Fixed a crash", content)))
})

test_that("entry with pre-existing (@user) attribution does not get duplicate contributor", {
  tmp <- tempfile("pkg_")
  dir.create(tmp)
  writeLines("Package: testpkg\nVersion: 1.0.0", file.path(tmp, "DESCRIPTION"))
  on.exit(unlink(tmp, recursive = TRUE))

  news_md_add_entry(
    "Fixed bug (@existing_user)",
    path = tmp,
    contributor = "new_user"
  )

  content <- readLines(file.path(tmp, "NEWS.md"))
  entry_line <- grep("Fixed bug", content, value = TRUE)
  expect_match(entry_line, "@existing_user")
  expect_no_match(entry_line, "new_user")
})

test_that("entry with * prefix and contributor gets contributor appended correctly", {
  tmp <- tempfile("pkg_")
  dir.create(tmp)
  writeLines("Package: testpkg\nVersion: 1.0.0", file.path(tmp, "DESCRIPTION"))
  on.exit(unlink(tmp, recursive = TRUE))

  news_md_add_entry("* Already has star", path = tmp, contributor = "dev1")

  content <- readLines(file.path(tmp, "NEWS.md"))
  entry_line <- grep("Already has star", content, value = TRUE)
  expect_match(entry_line, "@dev1")
})

test_that("adds entry to existing category in non-empty version section", {
  tmp <- tempfile("pkg_")
  dir.create(tmp)
  writeLines("Package: testpkg\nVersion: 1.0.0", file.path(tmp, "DESCRIPTION"))

  pkg_name <- basename(tmp)
  existing <- c(
    sprintf("# %s 1.0.0 (2026-01-01)", pkg_name),
    "",
    "## NEW FEATURES",
    "",
    "* First feature"
  )
  writeLines(existing, file.path(tmp, "NEWS.md"))
  on.exit(unlink(tmp, recursive = TRUE))

  news_md_add_entry("Second feature", path = tmp, category = "NEW FEATURES")

  content <- readLines(file.path(tmp, "NEWS.md"))
  nf_idx <- grep("^## NEW FEATURES$", content)
  second_idx <- grep("Second feature", content)
  first_idx <- grep("First feature", content)
  # Both entries should be under NEW FEATURES
  expect_gt(second_idx, nf_idx)
  expect_gt(first_idx, nf_idx)
  # New entry is inserted before existing entries within the category
  expect_lt(second_idx, first_idx)
})

test_that("adds new category to existing non-empty version section", {
  tmp <- tempfile("pkg_")
  dir.create(tmp)
  writeLines("Package: testpkg\nVersion: 1.0.0", file.path(tmp, "DESCRIPTION"))

  pkg_name <- basename(tmp)
  existing <- c(
    sprintf("# %s 1.0.0 (2026-01-01)", pkg_name),
    "",
    "## NEW FEATURES",
    "",
    "* First feature"
  )
  writeLines(existing, file.path(tmp, "NEWS.md"))
  on.exit(unlink(tmp, recursive = TRUE))

  news_md_add_entry("Performance tweak", path = tmp, category = "PERFORMANCE")

  content <- readLines(file.path(tmp, "NEWS.md"))
  perf_idx <- grep("^## PERFORMANCE$", content)
  nf_idx <- grep("^## NEW FEATURES$", content)
  # PERFORMANCE should appear before NEW FEATURES (inserted right after version header)
  expect_lt(perf_idx, nf_idx)
  expect_true(any(grepl("Performance tweak", content)))
})

test_that("adds category and entry to empty version section (header only)", {
  tmp <- tempfile("pkg_")
  dir.create(tmp)
  writeLines("Package: testpkg\nVersion: 1.0.0", file.path(tmp, "DESCRIPTION"))

  pkg_name <- basename(tmp)
  existing <- c(
    sprintf("# %s 1.0.0 (2026-01-01)", pkg_name)
  )
  writeLines(existing, file.path(tmp, "NEWS.md"))
  on.exit(unlink(tmp, recursive = TRUE))

  news_md_add_entry("Only entry", path = tmp)

  content <- readLines(file.path(tmp, "NEWS.md"))
  expect_true(any(grepl("^## NEW FEATURES$", content)))
  expect_true(any(grepl("Only entry", content)))
})

test_that("adds entry to first version when multiple versions exist", {
  tmp <- tempfile("pkg_")
  dir.create(tmp)
  writeLines("Package: testpkg\nVersion: 2.0.0", file.path(tmp, "DESCRIPTION"))

  pkg_name <- basename(tmp)
  existing <- c(
    sprintf("# %s 2.0.0 (2026-06-01)", pkg_name),
    "",
    "## NEW FEATURES",
    "",
    "* v2 feature",
    "",
    sprintf("# %s 1.0.0 (2026-01-01)", pkg_name),
    "",
    "## BUG FIXES",
    "",
    "* v1 fix",
    ""
  )
  writeLines(existing, file.path(tmp, "NEWS.md"))
  on.exit(unlink(tmp, recursive = TRUE))

  news_md_add_entry("New v2 entry", path = tmp)

  content <- readLines(file.path(tmp, "NEWS.md"))
  v2_entry_idx <- grep("New v2 entry", content)
  v2_header_idx <- grep(sprintf("# %s 2\\.0\\.0", pkg_name), content)
  v1_header_idx <- grep(sprintf("# %s 1\\.0\\.0", pkg_name), content)
  # New entry should be in v2 section, before v1 section
  expect_gt(v2_entry_idx, v2_header_idx)
  expect_lt(v2_entry_idx, v1_header_idx)
})

test_that("open_section = TRUE adds new section when existing section is 'closed'", {
  tmp <- tempfile("pkg_")
  dir.create(tmp)
  writeLines("Package: testpkg\nVersion: 1.0.0", file.path(tmp, "DESCRIPTION"))

  pkg_name <- basename(tmp)
  # "closed" section: version header followed by another version header without content
  existing <- c(
    sprintf("# %s 2.0.0 (2026-06-01)", pkg_name),
    "",
    "## NEW FEATURES",
    "",
    "* v2 feature",
    "",
    sprintf("# %s 1.0.0 (2026-01-01)", pkg_name)
  )
  writeLines(existing, file.path(tmp, "NEWS.md"))
  on.exit(unlink(tmp, recursive = TRUE))

  # Add to v1 with open_section = TRUE (it's "closed" because v2 section follows)
  # The function should find the version section for 1.0.0 (from DESCRIPTION)
  news_md_add_entry(
    "New v1 feature",
    path = tmp,
    version = "1.0.0",
    open_section = TRUE
  )

  content <- readLines(file.path(tmp, "NEWS.md"))
  expect_true(any(grepl("New v1 feature", content)))
})

test_that("vectorized entries with mixed * prefix handled correctly", {
  tmp <- tempfile("pkg_")
  dir.create(tmp)
  writeLines("Package: testpkg\nVersion: 1.0.0", file.path(tmp, "DESCRIPTION"))
  on.exit(unlink(tmp, recursive = TRUE))

  news_md_add_entry(c("* Already starred", "Plain entry"), path = tmp)

  content <- readLines(file.path(tmp, "NEWS.md"))
  expect_true(any(grepl("^\\* Already starred$", content)))
  expect_true(any(grepl("^\\* Plain entry$", content)))
})
