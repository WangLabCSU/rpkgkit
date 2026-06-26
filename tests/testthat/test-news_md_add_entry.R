test_that("news_md_add_entry creates NEWS.md when it does not exist", {
  tmp <- tempfile("pkg_")
  dir.create(tmp)
  writeLines("Package: testpkg\nVersion: 1.0.0", file.path(tmp, "DESCRIPTION"))
  on.exit(unlink(tmp, recursive = TRUE))

  result <- news_md_add_entry("Added new function foo()", path = tmp)
  expect_equal(result, file.path(tmp, "NEWS.md"))
  expect_true(file.exists(file.path(tmp, "NEWS.md")))

  content <- readLines(file.path(tmp, "NEWS.md"))
  expect_match(
    content[1],
    "# testpkg 1.0.0 \\([0-9]{4}-[0-9]{2}-[0-9]{2}\\)"
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
  expect_match(content[1], "testpkg 2\\.0\\.0 \\(2026-06-01\\)")
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

  existing <- c(
    "# testpkg 1.0.0 (2026-01-01)",
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

  existing <- c(
    "# testpkg 1.0.0 (2026-01-01)",
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

  existing <- c(
    "# testpkg 1.0.0 (2026-01-01)",
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

  existing <- c(
    "# testpkg 1.0.0 (2026-01-01)"
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

  existing <- c(
    "# testpkg 2.0.0 (2026-06-01)",
    "",
    "## NEW FEATURES",
    "",
    "* v2 feature",
    "",
    "# testpkg 1.0.0 (2026-01-01)",
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
  v2_header_idx <- grep("# testpkg 2\\.0\\.0", content)
  v1_header_idx <- grep("# testpkg 1\\.0\\.0", content)
  # New entry should be in v2 section, before v1 section
  expect_gt(v2_entry_idx, v2_header_idx)
  expect_lt(v2_entry_idx, v1_header_idx)
})

test_that("open_section = TRUE adds new section when existing section is 'closed'", {
  tmp <- tempfile("pkg_")
  dir.create(tmp)
  writeLines("Package: testpkg\nVersion: 1.0.0", file.path(tmp, "DESCRIPTION"))

  # "closed" section: v2 version header followed by v1 version header
  existing <- c(
    "# testpkg 2.0.0 (2026-06-01)",
    "",
    "## NEW FEATURES",
    "",
    "* v2 feature",
    "",
    "# testpkg 1.0.0 (2026-01-01)"
  )
  writeLines(existing, file.path(tmp, "NEWS.md"))
  on.exit(unlink(tmp, recursive = TRUE))

  # Add to v1 with open_section = TRUE (it's "closed" because v2 section follows)
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

test_that("version provided but DESCRIPTION missing gives informative error", {
  tmp <- tempfile("pkg_no_desc")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE))

  expect_error(
    news_md_add_entry("test entry", path = tmp, version = "1.0.0"),
    "DESCRIPTION"
  )
})

test_that("open_section = TRUE inserts into existing category when section is open", {
  tmp <- tempfile("pkg_")
  dir.create(tmp)
  writeLines("Package: testpkg\nVersion: 1.0.0", file.path(tmp, "DESCRIPTION"))

  # "open" section: a single version with content, no following version header
  existing <- c(
    "# testpkg 1.0.0 (2026-01-01)",
    "",
    "## NEW FEATURES",
    "",
    "* Existing feature"
  )
  writeLines(existing, file.path(tmp, "NEWS.md"))
  on.exit(unlink(tmp, recursive = TRUE))

  # open_section = TRUE with existing content → inserts into existing category
  news_md_add_entry("Second feature", path = tmp, category = "NEW FEATURES")

  content <- readLines(file.path(tmp, "NEWS.md"))
  nf_idx <- grep("^## NEW FEATURES$", content)
  second_idx <- grep("Second feature", content)
  first_idx <- grep("Existing feature", content)
  expect_gt(second_idx, nf_idx)
  expect_gt(first_idx, nf_idx)
  # New entry is inserted before existing entries
  expect_lt(second_idx, first_idx)
})

test_that("open_section = TRUE adds new category to existing open section", {
  tmp <- tempfile("pkg_")
  dir.create(tmp)
  writeLines("Package: testpkg\nVersion: 1.0.0", file.path(tmp, "DESCRIPTION"))

  existing <- c(
    "# testpkg 1.0.0 (2026-01-01)",
    "",
    "## NEW FEATURES",
    "",
    "* Existing feature"
  )
  writeLines(existing, file.path(tmp, "NEWS.md"))
  on.exit(unlink(tmp, recursive = TRUE))

  # Add a different category to the same open section
  news_md_add_entry("Fixed a bug", path = tmp, category = "BUG FIXES")

  content <- readLines(file.path(tmp, "NEWS.md"))
  expect_true(any(grepl("^## BUG FIXES$", content)))
  expect_true(any(grepl("^## NEW FEATURES$", content)))
  expect_true(any(grepl("Fixed a bug", content)))
})

test_that("multiple categories added in sequence to same version", {
  tmp <- tempfile("pkg_")
  dir.create(tmp)
  writeLines("Package: testpkg\nVersion: 1.0.0", file.path(tmp, "DESCRIPTION"))
  on.exit(unlink(tmp, recursive = TRUE))

  # Add two different categories in sequence
  news_md_add_entry("New function bar()", path = tmp, category = "NEW FEATURES")
  news_md_add_entry("Fixed crash in foo()", path = tmp, category = "BUG FIXES")

  content <- readLines(file.path(tmp, "NEWS.md"))
  # Both categories should be present
  expect_true(any(grepl("^## NEW FEATURES$", content)))
  expect_true(any(grepl("^## BUG FIXES$", content)))
  expect_true(any(grepl("New function bar\\(\\)", content)))
  expect_true(any(grepl("Fixed crash in foo\\(\\)", content)))
  # BUG FIXES appears before NEW FEATURES because the second call inserts
  # a new category right after the version header (before existing categories)
  nf_idx <- grep("^## NEW FEATURES$", content)
  bf_idx <- grep("^## BUG FIXES$", content)
  expect_lt(bf_idx, nf_idx)
})

test_that("contributor attribution with vectorized entries", {
  tmp <- tempfile("pkg_")
  dir.create(tmp)
  writeLines("Package: testpkg\nVersion: 1.0.0", file.path(tmp, "DESCRIPTION"))
  on.exit(unlink(tmp, recursive = TRUE))

  news_md_add_entry(c("Feature A", "Feature B"), path = tmp, contributor = "dev1")

  content <- readLines(file.path(tmp, "NEWS.md"))
  feat_a <- grep("Feature A", content, value = TRUE)
  feat_b <- grep("Feature B", content, value = TRUE)
  expect_match(feat_a, "@dev1")
  expect_match(feat_b, "@dev1")
})

test_that("open_section = FALSE with existing content adds to current section (not new version)", {
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

  # open_section = FALSE adds a new category to the existing section
  news_md_add_entry(
    "Fresh entry",
    path = tmp,
    version = "1.0.0",
    open_section = FALSE
  )

  content <- readLines(file.path(tmp, "NEWS.md"))
  # Should only have one version header (added to existing, not new version)
  version_headers <- grep("^# testpkg 1\\.0\\.0", content)
  expect_length(version_headers, 1)
  # The entry should be present in a new category
  expect_true(any(grepl("Fresh entry", content)))
  # A new category section should have been created
  expect_true(any(grepl("^## NEW FEATURES$", content)))
})
