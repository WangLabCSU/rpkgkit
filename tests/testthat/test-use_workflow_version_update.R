test_that("aborts when path is not a package root", {
  tmp <- tempfile("not_pkg")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE))

  expect_error(
    use_workflow_version_update(path = tmp),
    "not an R package root"
  )
})

test_that("aborts when workflow file already exists and overwrite = FALSE", {
  tmp <- tempfile("pkg")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE))
  file.create(file.path(tmp, "DESCRIPTION"))

  workflow_file <- file.path(tmp, ".github", "workflows", "version_update.yml")
  dir.create(dirname(workflow_file), recursive = TRUE)
  file.create(workflow_file)

  expect_error(
    use_workflow_version_update(path = tmp, overwrite = FALSE),
    "already exists"
  )
})

test_that("creates workflow directory and copies template", {
  tmp <- tempfile("pkg")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE))
  file.create(file.path(tmp, "DESCRIPTION"))

  result <- use_workflow_version_update(path = tmp)

  expected_path <- file.path(tmp, ".github", "workflows", "version_update.yml")
  expect_equal(result, expected_path)
  expect_true(file.exists(expected_path))

  lines <- readLines(expected_path, warn = FALSE)
  expect_match(lines[1L], "name: Update R Package Version", fixed = TRUE)
})

test_that("returns invisible file path", {
  tmp <- tempfile("pkg")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE))
  file.create(file.path(tmp, "DESCRIPTION"))

  result <- withVisible(use_workflow_version_update(path = tmp))

  expect_true(
    result$value == file.path(tmp, ".github", "workflows", "version_update.yml")
  )
  expect_false(result$visible)
})

test_that("overwrite = TRUE replaces existing workflow file", {
  tmp <- tempfile("pkg")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE))
  file.create(file.path(tmp, "DESCRIPTION"))

  workflow_file <- file.path(tmp, ".github", "workflows", "version_update.yml")
  dir.create(dirname(workflow_file), recursive = TRUE)
  writeLines(c("# old content"), workflow_file)

  result <- use_workflow_version_update(path = tmp, overwrite = TRUE)

  lines <- readLines(workflow_file, warn = FALSE)
  expect_match(lines[1L], "name: Update R Package Version", fixed = TRUE)
  expect_equal(result, workflow_file)
})

test_that("uses get_wd() when path is NULL", {
  tmp <- tempfile("pkg")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE))
  file.create(file.path(tmp, "DESCRIPTION"))

  local_mocked_bindings(
    get_wd = function() tmp,
    .package = "rpkgkit"
  )

  expect_error(use_workflow_version_update(path = NULL))
})
