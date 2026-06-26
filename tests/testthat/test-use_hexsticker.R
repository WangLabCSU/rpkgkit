test_that("use_hexsticker aborts when README.md does not exist", {
  tmp <- tempfile("hexsticker")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE))

  expect_error(
    use_hexsticker("logo.png", path = tmp),
    "README.md not found"
  )
})

test_that("use_hexsticker aborts when README.md is empty", {
  tmp <- tempfile("hexsticker")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE))
  writeLines(character(), file.path(tmp, "README.md"))

  expect_error(
    use_hexsticker("logo.png", path = tmp),
    "README.md is empty"
  )
})

test_that("use_hexsticker aborts when README.md has no top-level heading", {
  tmp <- tempfile("hexsticker")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE))
  writeLines(c("Some content.", "## Section"), file.path(tmp, "README.md"))

  expect_error(
    use_hexsticker("logo.png", path = tmp),
    "No top-level heading found"
  )
})

test_that("use_hexsticker appends img tag to heading when no URL", {
  tmp <- tempfile("hexsticker")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE))
  writeLines(c("# My Package", "", "Description."), file.path(tmp, "README.md"))

  use_hexsticker("man/figures/logo.png", path = tmp)

  lines <- readLines(file.path(tmp, "README.md"), warn = FALSE)
  expected_img <- '<img src="man/figures/logo.png" alt="package logo" align="right" height="139"/>'
  expect_match(lines[1L], expected_img, fixed = TRUE)
})

test_that("use_hexsticker wraps img in anchor when URL is provided", {
  tmp <- tempfile("hexsticker")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE))
  writeLines(c("# My Package", "", "Description."), file.path(tmp, "README.md"))

  use_hexsticker(
    "man/figures/logo.png",
    url = "https://example.com",
    path = tmp
  )

  lines <- readLines(file.path(tmp, "README.md"), warn = FALSE)
  expected_html <- '<a href="https://example.com"><img src="man/figures/logo.png" alt="package logo" align="right" height="139"/></a>'
  expect_match(lines[1L], expected_html, fixed = TRUE)
})

test_that("use_hexsticker includes extra HTML attributes via ...", {
  tmp <- tempfile("hexsticker")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE))
  writeLines(c("# My Package"), file.path(tmp, "README.md"))

  use_hexsticker("logo.png", path = tmp, width = "200", loading = "lazy")

  lines <- readLines(file.path(tmp, "README.md"), warn = FALSE)
  expect_match(lines[1L], 'width="200"', fixed = TRUE)
  expect_match(lines[1L], 'loading="lazy"', fixed = TRUE)
})

test_that("use_hexsticker uses custom alt_text, height, and align", {
  tmp <- tempfile("hexsticker")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE))
  writeLines(c("# My Package"), file.path(tmp, "README.md"))

  use_hexsticker(
    "logo.png",
    alt_text = "My Logo",
    height = 200,
    align = "left",
    path = tmp
  )

  lines <- readLines(file.path(tmp, "README.md"), warn = FALSE)
  expect_match(lines[1L], 'alt="My Logo"', fixed = TRUE)
  expect_match(lines[1L], 'height="200"', fixed = TRUE)
  expect_match(lines[1L], 'align="left"', fixed = TRUE)
})

test_that("use_hexsticker works with explicit path", {
  tmp <- tempfile("hexsticker")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE))
  writeLines(c("# My Package"), file.path(tmp, "README.md"))

  use_hexsticker("logo.png", path = tmp)

  lines <- readLines(file.path(tmp, "README.md"), warn = FALSE)
  expect_match(lines[1L], '<img src="logo.png"', fixed = TRUE)
})

test_that("use_hexsticker returns invisible TRUE", {
  tmp <- tempfile("hexsticker")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE))
  writeLines(c("# My Package"), file.path(tmp, "README.md"))

  result <- use_hexsticker("logo.png", path = tmp)
  expect_true(result)
})
