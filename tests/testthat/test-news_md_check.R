test_that("news_md_check detects missing NEWS.md", {
  tmp <- tempfile("empty_dir")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE))

  result <- news_md_check(path = tmp, verbose = FALSE)
  expect_false(result$valid)
  expect_match(result$errors, "NEWS.md file not found")
  expect_length(result$warnings, 0)
  expect_length(result$suggestions, 0)
})

test_that("news_md_check passes on well-formatted NEWS.md", {
  tmp <- tempfile("pkg_")
  dir.create(tmp)
  writeLines("Package: testpkg\nVersion: 1.0.0", file.path(tmp, "DESCRIPTION"))

  news_content <- c(
    "# testpkg 1.0.0 (2026-01-01)",
    "",
    "## NEW FEATURES",
    "",
    "* First new feature.",
    "",
    "## BUG FIXES",
    "",
    "* Fixed a critical bug.",
    ""
  )
  writeLines(news_content, file.path(tmp, "NEWS.md"))
  on.exit(unlink(tmp, recursive = TRUE))

  result <- news_md_check(path = tmp, verbose = FALSE)
  expect_true(result$valid)
  expect_length(result$errors, 0)
})

test_that("news_md_check detects missing version headers", {
  tmp <- tempfile("pkg_")
  dir.create(tmp)

  # NEWS.md with only bullet points, no version headers
  news_content <- c(
    "## NEW FEATURES",
    "",
    "* Some feature",
    ""
  )
  writeLines(news_content, file.path(tmp, "NEWS.md"))
  on.exit(unlink(tmp, recursive = TRUE))

  result <- news_md_check(path = tmp, verbose = FALSE)
  expect_false(result$valid)
  expect_true(any(grepl("No version headers found", result$errors)))
})

test_that("news_md_check warns on missing bullet entries", {
  tmp <- tempfile("pkg_")
  dir.create(tmp)

  news_content <- c(
    "# testpkg 1.0.0 (2026-01-01)",
    "",
    "## NEW FEATURES",
    ""
  )
  writeLines(news_content, file.path(tmp, "NEWS.md"))
  on.exit(unlink(tmp, recursive = TRUE))

  result <- news_md_check(path = tmp, verbose = FALSE)
  expect_match(result$warnings, "No bullet point entries found")
})

test_that("news_md_check detects category header outside version section", {
  tmp <- tempfile("pkg_")
  dir.create(tmp)

  # Category header before any version header
  news_content <- c(
    "## BUG FIXES",
    "",
    "* Fixed a bug",
    "",
    "# testpkg 1.0.0 (2026-01-01)",
    "",
    "## NEW FEATURES",
    "",
    "* New feature",
    ""
  )
  writeLines(news_content, file.path(tmp, "NEWS.md"))
  on.exit(unlink(tmp, recursive = TRUE))

  result <- news_md_check(path = tmp, verbose = FALSE)
  expect_false(result$valid)
  expect_match(result$errors, "Category header found outside version section")
})

test_that("news_md_check suggests against non-standard categories", {
  tmp <- tempfile("pkg_")
  dir.create(tmp)

  news_content <- c(
    "# testpkg 1.0.0 (2026-01-01)",
    "",
    "## RANDOM STUFF",
    "",
    "* Some entry",
    ""
  )
  writeLines(news_content, file.path(tmp, "NEWS.md"))
  on.exit(unlink(tmp, recursive = TRUE))

  result <- news_md_check(path = tmp, verbose = FALSE)
  # Non-standard category should be a suggestion, not an error
  cat_check <- grepl("Non-standard category", result$suggestions)
  expect_true(any(cat_check))
})

test_that("news_md_check detects trailing whitespace", {
  tmp <- tempfile("pkg_")
  dir.create(tmp)

  news_content <- c(
    "# testpkg 1.0.0 (2026-01-01)",
    " ", # trailing whitespace (space only line)
    "## NEW FEATURES",
    "",
    "* Some entry.  ", # trailing whitespace
    ""
  )
  writeLines(news_content, file.path(tmp, "NEWS.md"))
  on.exit(unlink(tmp, recursive = TRUE))

  result <- news_md_check(path = tmp, verbose = FALSE)
  expect_true(any(grepl("trailing whitespace", result$suggestions, ignore.case = TRUE)))
})

test_that("news_md_check suggests final blank line", {
  tmp <- tempfile("pkg_")
  dir.create(tmp)

  # No blank line at end
  news_content <- c(
    "# testpkg 1.0.0 (2026-01-01)",
    "",
    "## NEW FEATURES",
    "",
    "* Some entry."
  )
  writeLines(news_content, file.path(tmp, "NEWS.md"))
  on.exit(unlink(tmp, recursive = TRUE))

  result <- news_md_check(path = tmp, verbose = FALSE)
  expect_true(any(grepl("end with a blank line", result$suggestions)))
})

test_that("news_md_check: strict=TRUE turns warnings into errors", {
  tmp <- tempfile("pkg_")
  dir.create(tmp)

  # Bad version header format
  news_content <- c(
    "# testpkg 1.0 (broken-format)",
    "",
    "## NEW FEATURES",
    "",
    "* Some entry",
    ""
  )
  writeLines(news_content, file.path(tmp, "NEWS.md"))
  on.exit(unlink(tmp, recursive = TRUE))

  result_strict <- news_md_check(path = tmp, strict = TRUE, verbose = FALSE)
  result_lax <- news_md_check(path = tmp, strict = FALSE, verbose = FALSE)

  # Under strict, format warning becomes error and valid becomes FALSE
  expect_false(result_strict$valid)
  expect_true(length(result_strict$errors) > 0)

  # Under lax, same issue is a warning
  expect_true(length(result_lax$warnings) > 0)
})

test_that("news_md_check returns correct list structure", {
  tmp <- tempfile("pkg_")
  dir.create(tmp)
  writeLines("Package: testpkg\nVersion: 1.0.0", file.path(tmp, "DESCRIPTION"))

  news_content <- c(
    "# testpkg 1.0.0 (2026-01-01)",
    "",
    "## NEW FEATURES",
    "",
    "* A well-written entry.",
    ""
  )
  writeLines(news_content, file.path(tmp, "NEWS.md"))
  on.exit(unlink(tmp, recursive = TRUE))

  result <- news_md_check(path = tmp, verbose = FALSE)
  expect_type(result, "list")
  expect_named(result, c("valid", "errors", "warnings", "suggestions"))
  expect_true(is.logical(result$valid))
  expect_true(is.character(result$errors))
  expect_true(is.character(result$warnings))
  expect_true(is.character(result$suggestions))
})

test_that("news_md_check flags bad version header format", {
  tmp <- tempfile("pkg_")
  dir.create(tmp)

  # Version header with invalid date format (non-date string in parens)
  news_content <- c(
    "# testpkg 1.0.0 (not-a-date)",
    "",
    "## NEW FEATURES",
    "",
    "* Some entry",
    ""
  )
  writeLines(news_content, file.path(tmp, "NEWS.md"))
  on.exit(unlink(tmp, recursive = TRUE))

  result <- news_md_check(path = tmp, verbose = FALSE)
  expect_true(
    any(grepl("should follow format", result$warnings)) ||
      any(grepl("should follow format", result$errors))
  )
})

test_that("news_md_check suggests blank line before version header", {
  tmp <- tempfile("pkg_")
  dir.create(tmp)

  news_content <- c(
    "# testpkg 1.0.0 (2026-01-01)",
    "",
    "## NEW FEATURES",
    "",
    "* First entry.",
    "# testpkg 2.0.0 (2026-06-01)",
    "",
    "## NEW FEATURES",
    "",
    "* Second entry.",
    ""
  )
  writeLines(news_content, file.path(tmp, "NEWS.md"))
  on.exit(unlink(tmp, recursive = TRUE))

  result <- news_md_check(path = tmp, verbose = FALSE)
  expect_true(any(grepl("Blank line recommended before version header", result$suggestions)))
})
