test_that("convert_knitr_chunk_header aborts when knitr is not installed", {
  skip_if_not_installed("testthat")
  local_mocked_bindings(
    check_installed = function(...) cli::cli_abort("not installed"),
    .package = "rlang"
  )
  expect_error(convert_knitr_chunk_header("file.Rmd"), "not installed")
})

test_that("convert_knitr_chunk_header converts a single Rmd file", {
  skip_if_not_installed("knitr")
  tmp <- withr::local_tempfile(fileext = ".Rmd")
  writeLines(c("```{r, echo=TRUE, fig.width=10}", "x <- 1", "```"), tmp)

  result <- convert_knitr_chunk_header(tmp)

  expect_equal(result, tmp)
  expect_true(any(grepl("^#\\| echo = TRUE,$", readLines(tmp, warn = FALSE))))
  expect_true(any(grepl("^#\\| fig.width = 10$", readLines(tmp, warn = FALSE))))
})

test_that("convert_knitr_chunk_header converts package vignettes and README.Rmd", {
  skip_if_not_installed("knitr")
  pkg <- withr::local_tempdir("pkg")
  dir.create(file.path(pkg, "vignettes", "sub"), recursive = TRUE)
  writeLines(
    c("Package: testpkg", "Title: Test", "Version: 0.0.1",
      "Description: A test package.", "License: MIT", "Encoding: UTF-8"),
    file.path(pkg, "DESCRIPTION")
  )
  v1 <- file.path(pkg, "vignettes", "a.Rmd")
  v2 <- file.path(pkg, "vignettes", "sub", "b.Rmd")
  readme <- file.path(pkg, "README.Rmd")
  writeLines(c("```{r, echo=TRUE, fig.width=10}", "x <- 1", "```"), v1)
  writeLines(c("```{r, echo=FALSE}", "x <- 2", "```"), v2)
  writeLines(c("```{r setup, include=FALSE}", "knitr::opts_chunk$set(echo = TRUE)", "```"), readme)

  result <- convert_knitr_chunk_header(pkg)

  expect_equal(result, c(v1, v2, readme))
  expect_true(any(grepl("^#\\| echo = TRUE,$", readLines(v1, warn = FALSE))))
  expect_true(any(grepl("^#\\| echo = FALSE$", readLines(v2, warn = FALSE))))
  expect_true(any(grepl('^#\\| label = "setup",$', readLines(readme, warn = FALSE))))
})

test_that("convert_knitr_chunk_header aborts when path is not a package and file does not exist", {
  local_mocked_bindings(
    check_installed = function(...) invisible(),
    .package = "rlang"
  )
  local_mocked_bindings(
    is_pkg = function(path) FALSE,
    .package = "rpkgkit"
  )
  bad <- tempfile(fileext = ".Rmd")
  expect_error(convert_knitr_chunk_header(bad), "does not exist")
})

test_that("convert_knitr_chunk_header returns empty when package has no Rmd files", {
  local_mocked_bindings(
    check_installed = function(...) invisible(),
    .package = "rlang"
  )
  pkg <- withr::local_tempdir("pkg")
  writeLines(
    c("Package: testpkg", "Title: Test", "Version: 0.0.1",
      "Description: A test package.", "License: MIT"),
    file.path(pkg, "DESCRIPTION")
  )

  expect_message(
    result <- convert_knitr_chunk_header(pkg),
    "files found"
  )
  expect_equal(result, character())
})
