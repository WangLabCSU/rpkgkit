test_that("aborts when path is not a package root", {
  tmp <- withr::local_tempdir(pattern = "not_pkg")

  expect_error(
    use_workflow_rust_compatible_check(path = tmp),
    "not an R package root"
  )
})

test_that("aborts when workflow file already exists and overwrite = FALSE", {
  tmp <- withr::local_tempdir(pattern = "pkg")
  file.create(file.path(tmp, "DESCRIPTION"))

  workflow_file <- file.path(
    tmp,
    ".github",
    "workflows",
    "R-CMD-check.yaml"
  )
  dir.create(dirname(workflow_file), recursive = TRUE)
  file.create(workflow_file)

  expect_error(
    use_workflow_rust_compatible_check(path = tmp, overwrite = FALSE),
    "already exists"
  )
})

test_that("creates workflow directory and copies the Rust template", {
  tmp <- withr::local_tempdir(pattern = "pkg")
  file.create(file.path(tmp, "DESCRIPTION"))

  expect_message(
    result <- use_workflow_rust_compatible_check(path = tmp),
    "Created workflow"
  )

  expected_path <- file.path(
    tmp,
    ".github",
    "workflows",
    "R-CMD-check.yaml"
  )
  expect_equal(result, expected_path)
  expect_true(file.exists(expected_path))

  lines <- readLines(expected_path, warn = FALSE)
  expect_match(lines[1L], "on:", fixed = TRUE)
  expect_true(any(grepl("name: R-CMD-check", lines, fixed = TRUE)))
  expect_true(any(grepl(
    "uses: dtolnay/rust-toolchain@master",
    lines,
    fixed = TRUE
  )))
  expect_true(any(grepl(
    "x86_64-pc-windows-gnu",
    lines,
    fixed = TRUE
  )))
  expect_true(any(grepl(
    "r-lib/actions/check-r-package@v2",
    lines,
    fixed = TRUE
  )))
})

test_that("overwrite = TRUE replaces existing workflow file", {
  tmp <- withr::local_tempdir(pattern = "pkg")
  file.create(file.path(tmp, "DESCRIPTION"))

  workflow_file <- file.path(
    tmp,
    ".github",
    "workflows",
    "R-CMD-check.yaml"
  )
  dir.create(dirname(workflow_file), recursive = TRUE)
  writeLines(c("# old content"), workflow_file)

  suppressMessages(
    result <- use_workflow_rust_compatible_check(path = tmp, overwrite = TRUE)
  )

  lines <- readLines(workflow_file, warn = FALSE)
  expect_false(identical(lines, "# old content"))
  expect_true(any(grepl(
    "uses: dtolnay/rust-toolchain@master",
    lines,
    fixed = TRUE
  )))
  expect_equal(result, workflow_file)
})

test_that("returns invisible file path", {
  tmp <- withr::local_tempdir(pattern = "pkg")
  file.create(file.path(tmp, "DESCRIPTION"))

  result <- withVisible(
    suppressMessages(use_workflow_rust_compatible_check(path = tmp))
  )

  expect_equal(
    result$value,
    file.path(tmp, ".github", "workflows", "R-CMD-check.yaml")
  )
  expect_false(result$visible)
})

test_that("copied file is identical to the bundled template", {
  tmp <- withr::local_tempdir(pattern = "pkg")
  file.create(file.path(tmp, "DESCRIPTION"))

  suppressMessages(use_workflow_rust_compatible_check(path = tmp))

  template <- system.file(
    "actions",
    "rust_compatible_check",
    "R-CMD-Check.yaml",
    package = "rpkgkit"
  )
  expect_equal(
    readLines(file.path(tmp, ".github", "workflows", "R-CMD-check.yaml")),
    readLines(template)
  )
})

test_that("path = NULL falls back to the current working directory", {
  tmp <- withr::local_tempdir(pattern = "pkg")
  file.create(file.path(tmp, "DESCRIPTION"))
  withr::local_dir(tmp)

  suppressMessages(use_workflow_rust_compatible_check())

  expect_true(file.exists(file.path(
    tmp,
    ".github",
    "workflows",
    "R-CMD-check.yaml"
  )))
})
