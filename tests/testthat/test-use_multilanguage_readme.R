# Tests for use_multilanguage_readme() and badge_translated_by_ai()
# (R/44_use_multilanguage_readme.R)

# ---------------------------------------------------------------------------
# use_multilanguage_readme()
# ---------------------------------------------------------------------------

test_that("aborts when path is not an R package root", {
  tmp <- withr::local_tempdir()

  expect_error(
    use_multilanguage_readme(path = tmp),
    "not an R package root"
  )
})

test_that("creates inst/translations/ directory", {
  tmp <- withr::local_tempdir()
  writeLines(
    c("Package: mypkg", "Title: My Package"),
    file.path(tmp, "DESCRIPTION")
  )

  suppressMessages(
    use_multilanguage_readme(path = tmp, lang = "de")
  )

  expect_true(dir.exists(file.path(tmp, "inst", "translations")))
})

test_that("creates README file for each language code", {
  tmp <- withr::local_tempdir()
  writeLines(
    c("Package: mypkg", "Title: My Package"),
    file.path(tmp, "DESCRIPTION")
  )

  suppressMessages(
    use_multilanguage_readme(path = tmp, lang = c("de", "ja", "ko"))
  )

  trans_dir <- file.path(tmp, "inst", "translations")
  expect_true(file.exists(file.path(trans_dir, "README.de.md")))
  expect_true(file.exists(file.path(trans_dir, "README.ja.md")))
  expect_true(file.exists(file.path(trans_dir, "README.ko.md")))
})

test_that("README content includes package name and language display name", {
  tmp <- withr::local_tempdir()
  writeLines(
    c("Package: mypkg", "Title: My Package"),
    file.path(tmp, "DESCRIPTION")
  )

  suppressMessages(
    use_multilanguage_readme(path = tmp, lang = "de")
  )

  content <- readLines(
    file.path(tmp, "inst", "translations", "README.de.md"),
    warn = FALSE
  )
  expect_match(content[1L], "# mypkg")
  expect_match(content[1L], "Deutsch")
  expect_match(content[3L], "TODO: Translate")
})

test_that("skips existing file when overwrite = FALSE", {
  tmp <- withr::local_tempdir()
  writeLines(
    c("Package: mypkg", "Title: My Package"),
    file.path(tmp, "DESCRIPTION")
  )
  trans_dir <- file.path(tmp, "inst", "translations")
  dir.create(trans_dir, recursive = TRUE)
  writeLines("custom content", file.path(trans_dir, "README.de.md"))

  suppressMessages(
    use_multilanguage_readme(path = tmp, lang = "de", overwrite = FALSE)
  )

  # File should NOT be overwritten
  content <- readLines(file.path(trans_dir, "README.de.md"), warn = FALSE)
  expect_equal(content, "custom content")
})

test_that("overwrites existing file when overwrite = TRUE", {
  tmp <- withr::local_tempdir()
  writeLines(
    c("Package: mypkg", "Title: My Package"),
    file.path(tmp, "DESCRIPTION")
  )
  trans_dir <- file.path(tmp, "inst", "translations")
  dir.create(trans_dir, recursive = TRUE)
  writeLines("custom content", file.path(trans_dir, "README.de.md"))

  suppressMessages(
    use_multilanguage_readme(path = tmp, lang = "de", overwrite = TRUE)
  )

  content <- readLines(file.path(trans_dir, "README.de.md"), warn = FALSE)
  expect_match(content[1L], "# mypkg")
  expect_match(content[1L], "Deutsch")
})

test_that("returns invisible character vector of created file paths", {
  tmp <- withr::local_tempdir()
  writeLines(
    c("Package: mypkg", "Title: My Package"),
    file.path(tmp, "DESCRIPTION")
  )

  result <- suppressMessages(
    withVisible(use_multilanguage_readme(path = tmp, lang = c("de", "ja")))
  )

  expect_equal(length(result$value), 2L)
  expect_true(all(file.exists(result$value)))
  expect_false(result$visible)
})

test_that("unknown language codes use the code itself as display name", {
  tmp <- withr::local_tempdir()
  writeLines(
    c("Package: mypkg", "Title: My Package"),
    file.path(tmp, "DESCRIPTION")
  )

  suppressMessages(
    use_multilanguage_readme(path = tmp, lang = "xx")
  )

  content <- readLines(
    file.path(tmp, "inst", "translations", "README.xx.md"),
    warn = FALSE
  )
  expect_match(content[1L], "xx")
})

test_that("duplicate language codes are deduplicated", {
  tmp <- withr::local_tempdir()
  writeLines(
    c("Package: mypkg", "Title: My Package"),
    file.path(tmp, "DESCRIPTION")
  )

  suppressMessages(
    use_multilanguage_readme(path = tmp, lang = c("de", "de", "fr", "fr"))
  )

  trans_dir <- file.path(tmp, "inst", "translations")
  files <- list.files(trans_dir, pattern = "\\.md$")
  expect_length(files, 2L)
  expect_setequal(files, c("README.de.md", "README.fr.md"))
})

test_that("default languages create 5 files", {
  tmp <- withr::local_tempdir()
  writeLines(
    c("Package: mypkg", "Title: My Package"),
    file.path(tmp, "DESCRIPTION")
  )

  suppressMessages(
    use_multilanguage_readme(path = tmp)
  )

  trans_dir <- file.path(tmp, "inst", "translations")
  files <- list.files(trans_dir, pattern = "\\.md$")
  expect_length(files, 5L)
  expect_setequal(
    files,
    c(
      "README.zh-cn.md",
      "README.es.md",
      "README.fr.md",
      "README.ar.md",
      "README.ru.md"
    )
  )
})

test_that("badge output contains shields.io URL and correct color", {
  tmp <- withr::local_tempdir()
  writeLines(
    c("Package: mypkg", "Title: My Package"),
    file.path(tmp, "DESCRIPTION")
  )

  # Capture messages WITHOUT suppressing them
  msgs <- capture_messages(
    use_multilanguage_readme(path = tmp, lang = "de", color = "green")
  )

  expect_true(any(grepl("img\\.shields\\.io", msgs)))
  expect_true(any(grepl("green", msgs)))
})

# ---------------------------------------------------------------------------
# badge_translated_by_ai()
# ---------------------------------------------------------------------------

test_that("default lang = 'en' produces one entry", {
  result <- suppressMessages(
    badge_translated_by_ai()
  )

  expect_type(result, "list")
  expect_length(result, 1L)
  expect_named(result, "en")
})

test_that("multiple languages produce correct number of entries", {
  result <- suppressMessages(
    badge_translated_by_ai(c("de", "ja", "ko"))
  )

  expect_length(result, 3L)
  expect_named(result, c("de", "ja", "ko"))
})

test_that("returns invisible named list of badge + note pairs", {
  vis <- suppressMessages(
    withVisible(badge_translated_by_ai("fr"))
  )

  expect_type(vis$value, "list")
  expect_named(vis$value, "fr")
  expect_length(vis$value$fr, 2L)
  expect_match(vis$value$fr[1L], "img\\.shields\\.io")
  expect_match(vis$value$fr[2L], "^> ")
  expect_false(vis$visible)
})

test_that("unknown language codes are filtered out", {
  result <- suppressMessages(
    badge_translated_by_ai(c("de", "xx", "fr"))
  )

  expect_length(result, 2L)
  expect_named(result, c("de", "fr"))
})

test_that("NULL lang produces all available languages", {
  result <- suppressMessages(
    badge_translated_by_ai(lang = NULL)
  )

  # 19 languages in the internal map
  expect_length(result, 19L)
})

test_that("badge line contains AI label and custom color", {
  result <- suppressMessages(
    badge_translated_by_ai("de", color = "red")
  )

  expect_match(result$de[1L], "AI")
  expect_match(result$de[1L], "red")
})

test_that("blockquote note starts with > and contains disclaimer text", {
  result <- suppressMessages(
    badge_translated_by_ai("de")
  )

  expect_match(result$de[2L], "^> ")
  expect_match(result$de[2L], "KI")
})
