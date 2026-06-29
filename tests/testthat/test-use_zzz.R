test_that("aborts when path is not a package root", {
  tmp <- withr::local_tempdir()

  expect_error(
    use_zzz(path = tmp),
    "not an R package root"
  )
})

test_that("aborts when zzz.R already exists and overwrite = FALSE", {
  tmp <- withr::local_tempdir()
  local_mocked_bindings(
    proj_set = function(...) NULL,
    use_package = function(...) NULL,
    .package = "usethis"
  )

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
  tmp <- withr::local_tempdir()
  local_mocked_bindings(
    proj_set = function(...) NULL,
    use_package = function(...) NULL,
    .package = "usethis"
  )

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
  expect_match(lines[3L], "#' @title My Test Package", fixed = TRUE)
  expect_match(lines[11L], "^#' @name testpkg-package$", perl = TRUE)
  expect_match(lines[12L], "^#' @aliases testpkg$", perl = TRUE)
})

test_that("creates zzz.R with correct TITLE replacement", {
  tmp <- withr::local_tempdir()
  local_mocked_bindings(
    proj_set = function(...) NULL,
    use_package = function(...) NULL,
    .package = "usethis"
  )

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
  expect_match(lines[3L], "#' @title Custom Title Here", fixed = TRUE)
})

test_that("creates zzz.R with DESCRIPTION replacement (including multiline)", {
  tmp <- withr::local_tempdir()
  local_mocked_bindings(
    proj_set = function(...) NULL,
    use_package = function(...) NULL,
    .package = "usethis"
  )

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
  expect_match(
    lines[5L],
    "#' @description A package for testing.",
    fixed = TRUE
  )
  expect_match(lines[6L], "#' It has multiple lines.", fixed = TRUE)
})

test_that("creates zzz.R with correct LICENSE replacement", {
  tmp <- withr::local_tempdir()
  local_mocked_bindings(
    proj_set = function(...) NULL,
    use_package = function(...) NULL,
    .package = "usethis"
  )

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
  expect_match(lines[8L], "^#' GPL-3$", perl = TRUE)
})

test_that("overwrite = TRUE replaces existing zzz.R file", {
  tmp <- withr::local_tempdir()
  local_mocked_bindings(
    proj_set = function(...) NULL,
    use_package = function(...) NULL,
    .package = "usethis"
  )

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
  expect_match(lines[3L], "#' @title My Package", fixed = TRUE)
})

test_that("custom file_name is respected", {
  tmp <- withr::local_tempdir()
  local_mocked_bindings(
    proj_set = function(...) NULL,
    use_package = function(...) NULL,
    .package = "usethis"
  )

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
  tmp <- withr::local_tempdir()
  local_mocked_bindings(
    proj_set = function(...) NULL,
    use_package = function(...) NULL,
    .package = "usethis"
  )

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
  tmp <- withr::local_tempdir()
  local_mocked_bindings(
    proj_set = function(...) NULL,
    use_package = function(...) NULL,
    .package = "usethis"
  )

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
