test_that("aborts when ... is not empty", {
  tmp <- withr::local_tempdir()

  expect_error(
    use_jarl(path = tmp, extra = "x"),
    "must be empty"
  )
})

test_that("aborts when overwrite is not a flag", {
  tmp <- withr::local_tempdir()

  expect_error(use_jarl(path = tmp, overwrite = "yes"))
})

test_that("aborts when path points to a file", {
  tmp <- withr::local_tempdir()
  file_path <- file.path(tmp, "jarl.toml")
  file.create(file_path)

  expect_error(
    use_jarl(path = file_path),
    "must be a directory"
  )
})

test_that("creates jarl.toml in a non-package directory", {
  tmp <- withr::local_tempdir()

  result <- use_jarl(path = tmp)

  expect_equal(result, file.path(tmp, "jarl.toml"))
  expect_true(file.exists(result))
  # Non-package directories are left untouched.
  expect_false(file.exists(file.path(tmp, ".Rbuildignore")))
})

test_that("jarl.toml exposes the documented options", {
  tmp <- withr::local_tempdir()

  lines <- readLines(use_jarl(path = tmp), warn = FALSE)

  expect_true("[lint]" %in% lines)
  expect_true(any(grepl("^extend-select = ", lines)))
  expect_true(any(grepl("^exclude = ", lines)))
  expect_true(any(grepl("^check-roxygen = true$", lines)))

  # Commented-out options must stay commented, and the per-file table is
  # deliberately absent: everything written after it would be parsed as a glob.
  expect_true(any(grepl("^# fixable = ", lines)))
  expect_true(any(grepl("^# unfixable = ", lines)))
  expect_false(any(grepl("^\\[lint\\.per-file-ignores\\]", lines)))
})

test_that("aborts when jarl.toml already exists and overwrite = FALSE", {
  tmp <- withr::local_tempdir()
  writeLines("old content", file.path(tmp, "jarl.toml"))

  expect_error(use_jarl(path = tmp), "already exists")
})

test_that("overwrite = TRUE replaces an existing jarl.toml", {
  tmp <- withr::local_tempdir()
  writeLines("old content", file.path(tmp, "jarl.toml"))

  expect_message(
    result <- use_jarl(path = tmp, overwrite = TRUE),
    "Overwriting"
  )
  expect_message(use_jarl(path = tmp, overwrite = TRUE), "Created")

  lines <- readLines(result, warn = FALSE)
  expect_false(any(grepl("old content", lines, fixed = TRUE)))
  expect_true("[lint]" %in% lines)
})

test_that("creates parent directories if missing", {
  tmp <- withr::local_tempdir()
  deep_path <- file.path(tmp, "deep", "nested", "project")

  result <- use_jarl(path = deep_path)

  expect_true(dir.exists(deep_path))
  expect_true(file.exists(result))
})

test_that("package root also adds jarl.toml to .Rbuildignore", {
  tmp <- withr::local_tempdir()
  # A DESCRIPTION without a `Package:` field is not recognised as a project
  # root by usethis, but it is still an R package root for this function.
  file.create(file.path(tmp, "DESCRIPTION"))

  suppressMessages(use_jarl(path = tmp))

  rbuildignore <- file.path(tmp, ".Rbuildignore")
  expect_true(file.exists(rbuildignore))
  expect_true("^jarl\\.toml$" %in% readLines(rbuildignore, warn = FALSE))
})

test_that("returns the path invisibly", {
  tmp <- withr::local_tempdir()

  expect_invisible(suppressMessages(use_jarl(path = tmp)))
})

test_that("path defaults to the current working directory", {
  tmp <- withr::local_tempdir()
  old_wd <- setwd(tmp)
  on.exit(setwd(old_wd), add = TRUE)

  result <- suppressMessages(use_jarl())

  # `use_jarl()` resolves the default path via `getwd()`, which returns the
  # canonical form of the directory (`/var` -> `/private/var` on macOS; forward
  # slashes on Windows), whereas `withr::local_tempdir()` returns the raw
  # `tempdir()` form. Normalize both sides so the comparison is portable.
  expect_equal(
    normalizePath(result, winslash = "/"),
    normalizePath(file.path(tmp, "jarl.toml"), winslash = "/")
  )
  expect_true(file.exists(result))
})

test_that(".jarl_config_lines() starts with a comment and one [lint] table", {
  lines <- rpkgkit:::.jarl_config_lines()

  expect_match(lines[1L], "^# jarl configuration file$")
  expect_true("[lint]" %in% lines)
  expect_length(grep("^\\[", lines), 1L)
})
