test_that("create_standalone creates a file with correct header in non-pkg directory", {
  tmp <- tempfile("standalone_test")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE))

  local_mocked_bindings(
    is_pkg = function(path) FALSE,
    .package = "rpkgkit"
  )

  local_mocked_bindings(
    system2 = function(...) "owner/repo",
    .package = "base"
  )

  # Capture the content passed to writeLines
  writeLines_calls <- list()
  local_mocked_bindings(
    writeLines = function(text, con) {
      writeLines_calls <<- append(
        writeLines_calls,
        list(list(text = text, con = con))
      )
    },
    .package = "base"
  )

  local_mocked_bindings(
    file.exists = function(x) FALSE,
    .package = "base"
  )

  result <- create_standalone(
    standalone_name = "my_utils",
    path = tmp,
    open = FALSE
  )

  expected_path <- file.path(tmp, "standalone-my_utils.R")
  expect_equal(result, expected_path)
  expect_length(writeLines_calls, 1L)
  expect_equal(writeLines_calls[[1L]]$con, expected_path)

  header <- writeLines_calls[[1L]]$text
  expect_match(header[1L], "# ---")
  expect_match(header[2L], "^# repo: ")
  expect_match(header[3L], "^# file: standalone-my_utils\\.R")
  expect_match(header[4L], "^# last-updated: \\d{4}-\\d{2}-\\d{2}")
  expect_match(header[5L], "^# license: https://unlicense\\.org")
  expect_match(header[6L], "^# imports: \\[\\]")
  expect_match(header[7L], "# ---")
})

test_that("create_standalone uses custom license and imports", {
  tmp <- tempfile("standalone_test")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE))

  local_mocked_bindings(
    is_pkg = function(path) FALSE,
    .package = "rpkgkit"
  )

  local_mocked_bindings(
    system2 = function(...) "owner/repo",
    .package = "base"
  )

  writeLines_calls <- list()
  local_mocked_bindings(
    writeLines = function(text, con) {
      writeLines_calls <<- append(
        writeLines_calls,
        list(list(text = text, con = con))
      )
    },
    .package = "base"
  )

  local_mocked_bindings(
    file.exists = function(x) FALSE,
    .package = "base"
  )

  create_standalone(
    standalone_name = "my_utils",
    path = tmp,
    standalone_head = list(
      license = "MIT",
      imports = c("cli", "rlang")
    ),
    open = FALSE
  )

  header <- writeLines_calls[[1L]]$text
  expect_match(header[5L], "^# license: MIT")
  expect_match(header[6L], "^# imports: \\[cli, rlang\\]")
})

test_that("create_standalone places file in R/ subdirectory when path is a package", {
  tmp <- tempfile("pkg_test")
  dir.create(file.path(tmp, "R"), recursive = TRUE)
  file.create(file.path(tmp, "DESCRIPTION"))
  on.exit(unlink(tmp, recursive = TRUE))

  local_mocked_bindings(
    is_pkg = function(path) TRUE,
    .package = "rpkgkit"
  )

  local_mocked_bindings(
    system2 = function(...) "owner/repo",
    .package = "base"
  )

  writeLines_calls <- list()
  local_mocked_bindings(
    writeLines = function(text, con) {
      writeLines_calls <<- append(
        writeLines_calls,
        list(list(text = text, con = con))
      )
    },
    .package = "base"
  )

  local_mocked_bindings(
    file.exists = function(x) FALSE,
    .package = "base"
  )

  result <- create_standalone(
    standalone_name = "helper",
    path = tmp,
    open = FALSE
  )

  expect_equal(result, file.path(tmp, "R", "standalone-helper.R"))
})

test_that("create_standalone aborts when target file already exists", {
  tmp <- tempfile("standalone_test")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE))

  existing_file <- file.path(tmp, "standalone-existing.R")
  file.create(existing_file)

  expect_error(
    create_standalone("existing", path = tmp, open = FALSE),
    "already exists"
  )
})

test_that("create_standalone handles git error gracefully", {
  tmp <- tempfile("standalone_test")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE))

  local_mocked_bindings(
    is_pkg = function(path) TRUE,
    .package = "rpkgkit"
  )

  # Simulate git command failure
  local_mocked_bindings(
    system2 = function(...) {
      stop("git not available")
    },
    .package = "base"
  )

  writeLines_calls <- list()
  local_mocked_bindings(
    writeLines = function(text, con) {
      writeLines_calls <<- append(
        writeLines_calls,
        list(list(text = text, con = con))
      )
    },
    .package = "base"
  )

  local_mocked_bindings(
    file.exists = function(x) FALSE,
    .package = "base"
  )

  create_standalone(
    standalone_name = "my_utils",
    path = tmp,
    open = FALSE
  )

  # On error, repo_info should be basename(path)
  header <- writeLines_calls[[1L]]$text
  expect_match(header[2L], "^# repo: standalone_test")
})

test_that("create_standalone uses default path when path is NULL and rstudioapi unavailable", {
  local_mocked_bindings(
    is_installed = function(pkg) FALSE,
    .package = "rlang"
  )

  local_mocked_bindings(
    is_pkg = function(path) FALSE,
    .package = "rpkgkit"
  )

  local_mocked_bindings(
    system2 = function(...) "owner/repo",
    .package = "base"
  )

  writeLines_calls <- list()
  local_mocked_bindings(
    writeLines = function(text, con) {
      writeLines_calls <<- append(
        writeLines_calls,
        list(list(text = text, con = con))
      )
    },
    .package = "base"
  )

  local_mocked_bindings(
    file.exists = function(x) FALSE,
    .package = "base"
  )

  create_standalone("test", path = NULL, open = FALSE)

  header <- writeLines_calls[[1L]]$text
  expect_match(header[2L], "^# repo: ")
  expect_match(header[3L], "^# file: standalone-test\\.R")
})

test_that("create_standalone determines git repo from package path", {
  tmp <- tempfile("standalone_test")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE))

  local_mocked_bindings(
    is_pkg = function(path) TRUE,
    .package = "rpkgkit"
  )

  system2_calls <- list()
  local_mocked_bindings(
    system2 = function(command, args, ...) {
      system2_calls <<- append(
        system2_calls,
        list(list(command = command, args = args))
      )
      "https://github.com/owner/myrepo.git"
    },
    .package = "base"
  )

  writeLines_calls <- list()
  local_mocked_bindings(
    writeLines = function(text, con) {
      writeLines_calls <<- append(
        writeLines_calls,
        list(list(text = text, con = con))
      )
    },
    .package = "base"
  )

  local_mocked_bindings(
    file.exists = function(x) FALSE,
    .package = "base"
  )

  create_standalone("my_utils", path = tmp, open = FALSE)

  expect_length(system2_calls, 1L)
  expect_equal(system2_calls[[1L]]$command, "git")
  expect_equal(
    system2_calls[[1L]]$args,
    c("-C", tmp, "remote", "get-url", "origin")
  )

  expect_match(writeLines_calls[[1L]]$text[2L], "^# repo: owner/myrepo")
})

test_that("create_standalone handles path as R/ subdirectory of a package", {
  tmp <- tempfile("standalone_test")
  dir.create(file.path(tmp, "R"), recursive = TRUE)
  file.create(file.path(tmp, "DESCRIPTION"))
  on.exit(unlink(tmp, recursive = TRUE))

  local_mocked_bindings(
    is_pkg = function(path) FALSE,
    .package = "rpkgkit"
  )

  # For is_pkg(dirname(path)) when path is "R"
  local_mocked_bindings(
    system2 = function(...) "owner/myrepo",
    .package = "base"
  )

  writeLines_calls <- list()
  local_mocked_bindings(
    writeLines = function(text, con) {
      writeLines_calls <<- append(
        writeLines_calls,
        list(list(text = text, con = con))
      )
    },
    .package = "base"
  )

  local_mocked_bindings(
    file.exists = function(x) FALSE,
    .package = "base"
  )

  result <- create_standalone(
    "helper",
    path = file.path(tmp, "R"),
    open = FALSE
  )

  expect_match(writeLines_calls[[1L]]$text[2L], "^# repo: ")
  expect_equal(result, file.path(tmp, "R", "standalone-helper.R"))
})
