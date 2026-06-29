test_that("aborts when path is not a package root", {
  tmp <- tempfile("not_pkg")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE))

  expect_error(
    use_zzz(path = tmp),
    "not an R package root"
  )
})

test_that("aborts when zzz.R already exists and overwrite = FALSE", {
  tmp <- tempfile("pkg")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE))

  writeLines(
    c(
      "Package: testpkg",
      "Title: My Package",
      "Description: A package for testing.",
      "License: MIT + file LICENSE"
    ),
    file.path(tmp, "DESCRIPTION")
  )
  dir.create(file.path(tmp, "R"))
  file.create(file.path(tmp, "R", "testpkg-package.R"))

  expect_error(
    use_zzz(path = tmp, overwrite = FALSE),
    "already exists"
  )
})

test_that("creates zzz.R with PKG replaced in template", {
  tmp <- tempfile("pkg")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE))

  writeLines(
    c(
      "Package: testpkg",
      "Title: My Test Package",
      "Description: A package for testing.",
      "License: MIT + file LICENSE"
    ),
    file.path(tmp, "DESCRIPTION")
  )

  result <- use_zzz(path = tmp)

  expected_path <- file.path(tmp, "R", "testpkg-package.R")
  expect_equal(result, expected_path)
  expect_true(file.exists(expected_path))

  lines <- readLines(expected_path, warn = FALSE)
  expect_match(lines[1L], "#' @title My Test Package", fixed = TRUE)
  expect_match(lines[9L], "^#' @name testpkg-package$", perl = TRUE)
  expect_match(lines[10L], "^#' @aliases testpkg$", perl = TRUE)
})

test_that("creates zzz.R with correct TITLE replacement", {
  tmp <- tempfile("pkg")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE))

  writeLines(
    c(
      "Package: testpkg",
      "Title: Custom Title Here",
      "Description: A package for testing.",
      "License: MIT + file LICENSE"
    ),
    file.path(tmp, "DESCRIPTION")
  )

  use_zzz(path = tmp)

  lines <- readLines(file.path(tmp, "R", "testpkg-package.R"), warn = FALSE)
  expect_match(lines[1L], "#' @title Custom Title Here", fixed = TRUE)
})

test_that("creates zzz.R with DESCRIPTION replacement (including multiline)", {
  tmp <- tempfile("pkg")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE))

  writeLines(
    c(
      "Package: testpkg",
      "Title: My Package",
      "Description: A package for testing.",
      "  It has multiple lines.",
      "License: MIT + file LICENSE"
    ),
    file.path(tmp, "DESCRIPTION")
  )

  use_zzz(path = tmp)

  lines <- readLines(file.path(tmp, "R", "testpkg-package.R"), warn = FALSE)
  # Description spans lines 3-4: "#' @description A package for testing."
  # then "#' It has multiple lines."
  expect_match(
    lines[3L],
    "#' @description A package for testing.",
    fixed = TRUE
  )
  expect_match(lines[4L], "#' It has multiple lines.", fixed = TRUE)
})

test_that("creates zzz.R with correct LICENSE replacement", {
  tmp <- tempfile("pkg")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE))

  writeLines(
    c(
      "Package: testpkg",
      "Title: My Package",
      "Description: A package for testing.",
      "License: GPL-3"
    ),
    file.path(tmp, "DESCRIPTION")
  )

  use_zzz(path = tmp)

  lines <- readLines(file.path(tmp, "R", "testpkg-package.R"), warn = FALSE)
  expect_match(lines[6L], "^#' GPL-3$", perl = TRUE)
})

test_that("overwrite = TRUE replaces existing zzz.R file", {
  tmp <- tempfile("pkg")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE))

  writeLines(
    c(
      "Package: testpkg",
      "Title: My Package",
      "Description: A package for testing.",
      "License: MIT + file LICENSE"
    ),
    file.path(tmp, "DESCRIPTION")
  )

  dir.create(file.path(tmp, "R"))
  writeLines("# old content", file.path(tmp, "R", "testpkg-package.R"))

  result <- use_zzz(path = tmp, overwrite = TRUE)

  lines <- readLines(result, warn = FALSE)
  expect_match(lines[1L], "#' @title My Package", fixed = TRUE)
})

test_that("custom file_name is respected", {
  tmp <- tempfile("pkg")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE))

  writeLines(
    c(
      "Package: testpkg",
      "Title: My Package",
      "Description: A package for testing.",
      "License: MIT + file LICENSE"
    ),
    file.path(tmp, "DESCRIPTION")
  )

  result <- use_zzz(path = tmp, file_name = "internal.R")

  expected_path <- file.path(tmp, "R", "internal.R")
  expect_equal(result, expected_path)
  expect_true(file.exists(expected_path))
})

test_that("returns invisible file path", {
  tmp <- tempfile("pkg")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE))

  writeLines(
    c(
      "Package: testpkg",
      "Title: My Package",
      "Description: A package for testing.",
      "License: MIT + file LICENSE"
    ),
    file.path(tmp, "DESCRIPTION")
  )

  result <- withVisible(use_zzz(path = tmp))

  expected <- file.path(tmp, "R", "testpkg-package.R")
  expect_equal(result$value, expected)
  expect_false(result$visible)
})

test_that("creates R/ directory if missing", {
  tmp <- tempfile("pkg")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE))

  writeLines(
    c(
      "Package: testpkg",
      "Title: My Package",
      "Description: A package for testing.",
      "License: MIT + file LICENSE"
    ),
    file.path(tmp, "DESCRIPTION")
  )

  result <- use_zzz(path = tmp)

  expect_true(dir.exists(file.path(tmp, "R")))
  expect_true(file.exists(result))
})
