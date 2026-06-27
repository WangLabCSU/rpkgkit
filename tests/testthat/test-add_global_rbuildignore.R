test_that("aborts when path is not a package root", {
  tmp <- tempfile("not_pkg")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE))

  expect_error(
    add_global_rbuildignore(path = tmp),
    "not an R package root"
  )
})

test_that("creates .Rbuildignore with default patterns when file does not exist", {
  tmp <- tempfile("pkg")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE))

  writeLines(
    "Package: testpkg\nTitle: Test\nDescription: Testing.\nLicense: MIT",
    file.path(tmp, "DESCRIPTION")
  )

  result <- add_global_rbuildignore(path = tmp)

  expect_equal(result, file.path(tmp, ".Rbuildignore"))
  expect_true(file.exists(file.path(tmp, ".Rbuildignore")))

  lines <- readLines(file.path(tmp, ".Rbuildignore"), warn = FALSE)
  expect_true("^\\.Rhistory$" %in% lines)
  expect_true("^\\.git$" %in% lines)
  expect_true("^\\.codebuddy$" %in% lines)
  expect_true("^codecov\\.yml$" %in% lines)
  expect_true("^docs$" %in% lines)
  expect_true(any(grepl("Global rbuildignore patterns", lines, fixed = TRUE)))
})

test_that("appends only new patterns when some already exist", {
  tmp <- tempfile("pkg")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE))

  writeLines(
    "Package: testpkg\nTitle: Test\nDescription: Testing.\nLicense: MIT",
    file.path(tmp, "DESCRIPTION")
  )

  writeLines(c("^\\.Rhistory$", "^\\.git$"), file.path(tmp, ".Rbuildignore"))

  suppressMessages(add_global_rbuildignore(path = tmp))

  lines <- readLines(file.path(tmp, ".Rbuildignore"), warn = FALSE)
  expect_true("^\\.Rhistory$" %in% lines)
  expect_true("^\\.git$" %in% lines)
  expect_true("^\\.Rdata$" %in% lines)
  expect_true("^\\.gitattributes$" %in% lines)
})

test_that("silently skips when all patterns already exist", {
  tmp <- tempfile("pkg")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE))

  writeLines(
    "Package: testpkg\nTitle: Test\nDescription: Testing.\nLicense: MIT",
    file.path(tmp, "DESCRIPTION")
  )

  suppressMessages(add_global_rbuildignore(path = tmp))
  first_content <- readLines(file.path(tmp, ".Rbuildignore"), warn = FALSE)
  first_len <- length(first_content)

  expect_message(
    add_global_rbuildignore(path = tmp),
    "All patterns already present"
  )

  second_content <- readLines(file.path(tmp, ".Rbuildignore"), warn = FALSE)
  expect_equal(length(second_content), first_len)
})

test_that("additional patterns via dots are added", {
  tmp <- tempfile("pkg")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE))

  writeLines(
    "Package: testpkg\nTitle: Test\nDescription: Testing.\nLicense: MIT",
    file.path(tmp, "DESCRIPTION")
  )

  suppressMessages(
    add_global_rbuildignore("^\\.myconfig$", "^data-raw$", path = tmp)
  )

  lines <- readLines(file.path(tmp, ".Rbuildignore"), warn = FALSE)
  expect_true("^\\.myconfig$" %in% lines)
  expect_true("^data-raw$" %in% lines)
  expect_true("^\\.Rhistory$" %in% lines)
})

test_that("additional patterns that already exist are not duplicated", {
  tmp <- tempfile("pkg")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE))

  writeLines(
    "Package: testpkg\nTitle: Test\nDescription: Testing.\nLicense: MIT",
    file.path(tmp, "DESCRIPTION")
  )

  suppressMessages(add_global_rbuildignore(path = tmp))
  count_before <- sum(
    "^\\.Rhistory$" == readLines(file.path(tmp, ".Rbuildignore"), warn = FALSE)
  )

  suppressMessages(
    add_global_rbuildignore("^\\.Rhistory$", path = tmp)
  )

  count_after <- sum(
    "^\\.Rhistory$" == readLines(file.path(tmp, ".Rbuildignore"), warn = FALSE)
  )

  expect_equal(count_after, count_before)
})

test_that("returns invisible file path", {
  tmp <- tempfile("pkg")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE))

  writeLines(
    "Package: testpkg\nTitle: Test\nDescription: Testing.\nLicense: MIT",
    file.path(tmp, "DESCRIPTION")
  )

  result <- withVisible(suppressMessages(add_global_rbuildignore(path = tmp)))

  expect_equal(result$value, file.path(tmp, ".Rbuildignore"))
  expect_false(result$visible)
})

test_that("creates .Rbuildignore when it is empty", {
  tmp <- tempfile("pkg")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE))

  writeLines(
    "Package: testpkg\nTitle: Test\nDescription: Testing.\nLicense: MIT",
    file.path(tmp, "DESCRIPTION")
  )

  writeLines(character(0), file.path(tmp, ".Rbuildignore"))

  suppressMessages(add_global_rbuildignore(path = tmp))

  lines <- readLines(file.path(tmp, ".Rbuildignore"), warn = FALSE)
  expect_true("^\\.git$" %in% lines)
  expect_true(any(grepl("Global rbuildignore patterns", lines, fixed = TRUE)))
})
