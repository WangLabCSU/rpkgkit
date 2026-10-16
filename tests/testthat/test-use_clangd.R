test_that("aborts when ... is not empty", {
  tmp <- withr::local_tempdir()

  expect_error(
    use_clangd(path = tmp, extra = "x"),
    "must be empty"
  )
})

test_that("creates .clangd in non-package directory with default include paths", {
  tmp <- withr::local_tempdir()

  local_mocked_bindings(
    R.home = function(component) {
      if (identical(component, "include")) "/fake/R/include" else "/fake/R"
    },
    .package = "base"
  )
  local_mocked_bindings(
    system.file = function(...) "/fake/pkg/include",
    .package = "base"
  )

  result <- use_clangd(path = tmp)

  cfg_path <- file.path(tmp, ".clangd")
  expect_equal(result, cfg_path)
  expect_true(file.exists(cfg_path))

  lines <- readLines(cfg_path, warn = FALSE)
  expect_match(lines[1L], "^CompileFlags:$")
  expect_match(lines[2L], "^  Add:$")
  expect_true(any(grepl("    - -I/fake/R/include", lines, fixed = TRUE)))
  expect_true(any(grepl("    - -I/fake/pkg/include", lines, fixed = TRUE)))
  expect_true(any(grepl("^Diagnostics:$", lines)))
  expect_true(any(grepl("^  UnusedIncludes: Ignore$", lines)))
  expect_true(any(grepl("^Index:$", lines)))
  expect_true(any(grepl("^  Background: Build$", lines)))
  # No If: block for non-package directories
  expect_false(any(grepl("^If:$", lines)))
  expect_false(any(grepl("^---$", lines)))
})

test_that("appends If: ignore block when path is an R package root", {
  tmp <- withr::local_tempdir()
  file.create(file.path(tmp, "DESCRIPTION"))

  local_mocked_bindings(
    R.home = function(component) "/fake/R/include",
    .package = "base"
  )
  local_mocked_bindings(
    system.file = function(...) "/fake/pkg/include",
    .package = "base"
  )

  result <- use_clangd(path = tmp)

  lines <- readLines(result, warn = FALSE)
  sep_idx <- which(lines == "---")
  expect_length(sep_idx, 1L)

  tail <- lines[(sep_idx + 1L):length(lines)]
  expect_match(tail[1L], "^If:$")
  expect_match(tail[2L], "^  PathMatch: R/\\.\\*$")
  expect_match(tail[3L], "^Index:$")
  expect_match(tail[4L], "^  Background: None$")
})

test_that("package root also adds .clangd to .Rbuildignore", {
  tmp <- withr::local_tempdir()
  # A DESCRIPTION without a `Package:` field is not recognised as a project
  # root by usethis, but it is still an R package root for this function.
  file.create(file.path(tmp, "DESCRIPTION"))

  local_mocked_bindings(
    R.home = function(component) "/fake/R/include",
    .package = "base"
  )
  local_mocked_bindings(
    system.file = function(...) "/fake/pkg/include",
    .package = "base"
  )

  suppressMessages(use_clangd(path = tmp))

  rbuildignore <- file.path(tmp, ".Rbuildignore")
  expect_true(file.exists(rbuildignore))
  expect_true("^\\.clangd$" %in% readLines(rbuildignore, warn = FALSE))
})

test_that("does not append If: ignore block when path is not an R package", {
  tmp <- withr::local_tempdir()

  local_mocked_bindings(
    R.home = function(component) "/fake/R/include",
    .package = "base"
  )
  local_mocked_bindings(
    system.file = function(...) "/fake/pkg/include",
    .package = "base"
  )

  result <- use_clangd(path = tmp)

  lines <- readLines(result, warn = FALSE)
  expect_false(any(grepl("^---$", lines)))
  expect_false(any(grepl("^If:$", lines)))
})

test_that("accepts custom include package names", {
  tmp <- withr::local_tempdir()

  local_mocked_bindings(
    R.home = function(component) "/fake/R/include",
    .package = "base"
  )
  local_mocked_bindings(
    system.file = function(...) {
      args <- list(...)
      if (identical(args[["package"]], "Rcpp")) {
        "/fake/Rcpp/include"
      } else if (identical(args[["package"]], "BH")) {
        "/fake/BH/include"
      } else {
        ""
      }
    },
    .package = "base"
  )

  result <- use_clangd(
    path = tmp,
    include = c("Rcpp", "BH")
  )

  lines <- readLines(result, warn = FALSE)
  expect_true(any(grepl("/fake/Rcpp/include", lines, fixed = TRUE)))
  expect_true(any(grepl("/fake/BH/include", lines, fixed = TRUE)))
  expect_false(any(grepl("RcppEigen", lines, fixed = TRUE)))
  expect_false(any(grepl("RcppArmadillo", lines, fixed = TRUE)))
})

test_that("include = character(0) adds only the system R include path", {
  tmp <- withr::local_tempdir()

  local_mocked_bindings(
    R.home = function(component) "/fake/R/include",
    .package = "base"
  )

  result <- use_clangd(path = tmp, include = character(0))

  lines <- readLines(result, warn = FALSE)
  add_lines <- grep("^    - -I", lines, value = TRUE)
  expect_length(add_lines, 1L)
  expect_equal(add_lines, "    - -I/fake/R/include")
})

test_that("skips packages that are not installed with a warning", {
  tmp <- withr::local_tempdir()

  local_mocked_bindings(
    R.home = function(component) "/fake/R/include",
    .package = "base"
  )
  local_mocked_bindings(
    system.file = function(...) {
      args <- list(...)
      pkg <- args[["package"]]
      if (identical(pkg, "Rcpp")) "/fake/Rcpp/include" else ""
    },
    .package = "base"
  )

  expect_warning(
    result <- use_clangd(
      path = tmp,
      include = c("Rcpp", "NotInstalledPkg")
    ),
    "NotInstalledPkg"
  )

  lines <- readLines(result, warn = FALSE)
  expect_true(any(grepl("/fake/Rcpp/include", lines, fixed = TRUE)))
  expect_false(any(grepl("NotInstalledPkg", lines, fixed = TRUE)))
})

test_that("aborts when .clangd already exists and overwrite = FALSE", {
  tmp <- withr::local_tempdir()
  file.create(file.path(tmp, ".clangd"))

  expect_error(use_clangd(path = tmp), "already exists")
})

test_that("overwrite = TRUE replaces existing .clangd file", {
  tmp <- withr::local_tempdir()
  writeLines(c("# old content", "CompileFlags:"), file.path(tmp, ".clangd"))

  local_mocked_bindings(
    R.home = function(component) "/fake/R/include",
    .package = "base"
  )
  local_mocked_bindings(
    system.file = function(...) "",
    .package = "base"
  )

  expect_message(suppressWarnings(
    result <- use_clangd(path = tmp, overwrite = TRUE)
  ))

  lines <- readLines(result, warn = FALSE)
  expect_false(any(grepl("old content", lines, fixed = TRUE)))
  expect_match(lines[1L], "^CompileFlags:$")
})

test_that("creates parent directory if missing", {
  tmp <- withr::local_tempdir()
  deep_path <- file.path(tmp, "deep", "nested", "project")

  local_mocked_bindings(
    R.home = function(component) "/fake/R/include",
    .package = "base"
  )
  local_mocked_bindings(
    system.file = function(...) "",
    .package = "base"
  )

  result <- suppressWarnings(use_clangd(path = deep_path))

  expect_true(dir.exists(deep_path))
  expect_true(file.exists(result))
})

test_that("returns invisibly", {
  tmp <- withr::local_tempdir()

  local_mocked_bindings(
    R.home = function(component) "/fake/R/include",
    .package = "base"
  )
  local_mocked_bindings(
    system.file = function(...) "",
    .package = "base"
  )

  expect_invisible(suppressWarnings(use_clangd(path = tmp)))
})

test_that("path defaults to current working directory", {
  tmp <- withr::local_tempdir()
  old_wd <- setwd(tmp)
  on.exit(setwd(old_wd), add = TRUE)

  local_mocked_bindings(
    R.home = function(component) "/fake/R/include",
    .package = "base"
  )
  local_mocked_bindings(
    system.file = function(...) "",
    .package = "base"
  )

  result <- suppressWarnings(use_clangd())

  expect_equal(result, file.path(tmp, ".clangd"))
  expect_true(file.exists(result))
})

test_that(".clangd_collect_includes returns R include and package includes", {
  local_mocked_bindings(
    R.home = function(component) "/fake/R/include",
    .package = "base"
  )
  local_mocked_bindings(
    system.file = function(...) {
      args <- list(...)
      if (identical(args[["package"]], "Rcpp")) "/fake/Rcpp/include" else ""
    },
    .package = "base"
  )

  paths <- rpkgkit:::.clangd_collect_includes(c("Rcpp"))
  expect_equal(paths, c("/fake/R/include", "/fake/Rcpp/include"))
})

test_that(".clangd_collect_includes returns only R include when no packages", {
  local_mocked_bindings(
    R.home = function(component) "/fake/R/include",
    .package = "base"
  )

  paths <- rpkgkit:::.clangd_collect_includes(character(0))
  expect_equal(paths, "/fake/R/include")
})

test_that(".clangd_build_config emits main block without If: block", {
  lines <- rpkgkit:::.clangd_build_config(
    include_paths = c("/r", "/rcpp"),
    is_pkg_root = FALSE
  )

  expect_match(lines[1L], "^CompileFlags:$")
  expect_match(lines[2L], "^  Add:$")
  expect_match(lines[3L], "    - -I/r$")
  expect_match(lines[4L], "    - -I/rcpp$")
  expect_false(any(grepl("^---$", lines)))
  expect_false(any(grepl("^If:$", lines)))
})

test_that(".clangd_build_config appends If: ignore block for R package root", {
  lines <- rpkgkit:::.clangd_build_config(
    include_paths = "/r",
    is_pkg_root = TRUE
  )

  sep_idx <- which(lines == "---")
  expect_length(sep_idx, 1L)
  expect_match(lines[sep_idx + 1L], "^If:$")
})
