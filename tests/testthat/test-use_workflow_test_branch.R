test_that("aborts when path is not a package root", {
  tmp <- withr::local_tempdir(pattern = "not_pkg")

  expect_error(
    use_workflow_test_branch(path = tmp),
    "not an R package root"
  )
})

test_that("aborts when workflow file already exists and overwrite = FALSE", {
  tmp <- withr::local_tempdir(pattern = "pkg")
  file.create(file.path(tmp, "DESCRIPTION"))

  workflow_file <- file.path(tmp, ".github", "workflows", "sync_test_branch.yml")
  dir.create(dirname(workflow_file), recursive = TRUE)
  file.create(workflow_file)

  expect_error(
    use_workflow_test_branch(path = tmp, overwrite = FALSE),
    "already exists"
  )
})

test_that("aborts when action file already exists and overwrite = FALSE", {
  tmp <- withr::local_tempdir(pattern = "pkg")
  file.create(file.path(tmp, "DESCRIPTION"))

  action_file <- file.path(tmp, ".github", "actions", "sync-test-branch", "action.yml")
  dir.create(dirname(action_file), recursive = TRUE)
  file.create(action_file)

  expect_error(
    use_workflow_test_branch(path = tmp, overwrite = FALSE),
    "already exists"
  )
})

test_that("creates workflow directory and copies template", {
  tmp <- withr::local_tempdir(pattern = "pkg")
  file.create(file.path(tmp, "DESCRIPTION"))

  result <- use_workflow_test_branch(path = tmp)

  expected_path <- file.path(tmp, ".github", "workflows", "sync_test_branch.yml")
  expect_equal(result, expected_path)
  expect_true(file.exists(expected_path))

  lines <- readLines(expected_path, warn = FALSE)
  expect_match(lines[1L], "name: Sync Main to Test Branch", fixed = TRUE)
})

test_that("copies action files to .github/actions/sync-test-branch/", {
  tmp <- withr::local_tempdir(pattern = "pkg")
  file.create(file.path(tmp, "DESCRIPTION"))

  use_workflow_test_branch(path = tmp)

  action_dir <- file.path(tmp, ".github", "actions", "sync-test-branch")
  expect_true(file.exists(file.path(action_dir, "action.yml")))
  expect_true(file.exists(file.path(action_dir, "dist", "index.js")))
  expect_true(file.exists(file.path(action_dir, "dist", "licenses.txt")))

  action_lines <- readLines(file.path(action_dir, "action.yml"), warn = FALSE)
  expect_match(action_lines[1L], 'name: "Sync Test Branch"', fixed = TRUE)
})

test_that("overwrite = TRUE replaces existing workflow file", {
  tmp <- withr::local_tempdir(pattern = "pkg")
  file.create(file.path(tmp, "DESCRIPTION"))

  workflow_file <- file.path(tmp, ".github", "workflows", "sync_test_branch.yml")
  dir.create(dirname(workflow_file), recursive = TRUE)
  writeLines(c("# old content"), workflow_file)

  result <- use_workflow_test_branch(path = tmp, overwrite = TRUE)

  lines <- readLines(workflow_file, warn = FALSE)
  expect_match(lines[1L], "name: Sync Main to Test Branch", fixed = TRUE)
  expect_equal(result, workflow_file)
})

test_that("returns invisible file path", {
  tmp <- withr::local_tempdir(pattern = "pkg")
  file.create(file.path(tmp, "DESCRIPTION"))

  result <- withVisible(use_workflow_test_branch(path = tmp))

  expect_equal(
    result$value,
    file.path(tmp, ".github", "workflows", "sync_test_branch.yml")
  )
  expect_false(result$visible)
})

test_that("uses get_wd() when path is NULL", {
  tmp <- withr::local_tempdir(pattern = "pkg")
  file.create(file.path(tmp, "DESCRIPTION"))

  local_mocked_bindings(
    get_wd = function() tmp,
    .package = "rpkgkit"
  )

  expect_error(use_workflow_test_branch(path = NULL))
})
