make_pkg <- function(dir) {
  writeLines(
    c(
      "Package: testpkg",
      "Title: Test Package",
      "Version: 0.0.1",
      "Description: A package for testing.",
      "License: MIT + file LICENSE",
      "Encoding: UTF-8"
    ),
    file.path(dir, "DESCRIPTION")
  )
  dir.create(file.path(dir, "R"), showWarnings = FALSE)
  invisible(dir)
}

test_that("use_r() aborts when path is not a package root", {
  tmp <- withr::local_tempdir()

  expect_error(use_r(path = tmp), "not an R package root")
})

test_that("use_r() aborts on non-empty dots", {
  tmp <- withr::local_tempdir()
  make_pkg(tmp)

  expect_error(use_r(path = tmp, bogus = TRUE))
})

test_that("use_r() passes the highest detected version to usethis", {
  tmp <- withr::local_tempdir()
  make_pkg(tmp)
  seen <- new.env(parent = emptyenv())
  local_mocked_bindings(
    proj_set = function(...) NULL,
    use_package = function(package, type = NULL, min_version = NULL) {
      seen$package <- package
      seen$type <- type
      seen$min_version <- min_version
      invisible(NULL)
    },
    .package = "usethis"
  )
  writeLines(
    c("f <- function(x) x |> as.numeric()", "g <- function(x) x %||% 1"),
    file.path(tmp, "R", "f.R")
  )

  expect_equal(use_r(path = tmp), "4.4.0")
  expect_equal(seen$package, "R")
  expect_equal(seen$type, "Depends")
  expect_equal(seen$min_version, "4.4.0")
})

test_that("use_r() writes the detected version into DESCRIPTION", {
  tmp <- withr::local_tempdir()
  make_pkg(tmp)
  writeLines("f <- function(x) x %||% 1", file.path(tmp, "R", "f.R"))

  expect_equal(use_r(path = tmp), "4.4.0")
  depends <- read.dcf(file.path(tmp, "DESCRIPTION"))[, "Depends"]
  expect_match(depends, "R \\(>= 4\\.4\\.0\\)")
})

test_that("use_r() leaves DESCRIPTION alone when nothing is detected", {
  tmp <- withr::local_tempdir()
  make_pkg(tmp)
  writeLines("f <- function(x) x + 1", file.path(tmp, "R", "f.R"))
  before <- readLines(file.path(tmp, "DESCRIPTION"))

  expect_null(use_r(path = tmp))
  expect_equal(readLines(file.path(tmp, "DESCRIPTION")), before)
})

test_that("use_r() ignores features the package defines itself", {
  tmp <- withr::local_tempdir()
  make_pkg(tmp)
  writeLines(
    "%||% <- function(x, y) if (is.null(x)) y else x",
    file.path(tmp, "R", "utils.R")
  )
  writeLines("f <- function(x) x %||% 1", file.path(tmp, "R", "f.R"))
  before <- readLines(file.path(tmp, "DESCRIPTION"))

  expect_null(use_r(path = tmp))
  expect_equal(readLines(file.path(tmp, "DESCRIPTION")), before)
})

test_that("use_r() honours dirs", {
  tmp <- withr::local_tempdir()
  make_pkg(tmp)
  dir.create(file.path(tmp, "tests", "testthat"), recursive = TRUE)
  writeLines("f <- function(x) x + 1", file.path(tmp, "R", "f.R"))
  writeLines(
    "g <- function(x) x %||% 1",
    file.path(tmp, "tests", "testthat", "test-g.R")
  )

  expect_equal(use_r(path = tmp, dirs = "tests/testthat"), "4.4.0")
})

test_that("ur_scan_text_rs() reports syntax features", {
  res <- ur_scan_text_rs("x <- 1\ny <- x |> f()\n")
  expect_equal(res$feature, "|>")
  expect_equal(res$version, "4.1.0")
  expect_equal(res$line, 2L)
  expect_equal(res$count, 1L)
  expect_false(as.logical(res$local))
  expect_equal(res$min_version, "4.1.0")
  expect_equal(
    ur_scan_text_rs("x |> lm(y ~ x, data = _)\n")$min_version,
    "4.2.0"
  )

  expect_equal(ur_scan_text_rs("f <- \\(x) x\n")$min_version, "4.1.0")
  expect_equal(
    ur_scan_text_rs("x |> lm(y ~ x, data = _)\n")$min_version,
    "4.2.0"
  )
  expect_equal(ur_scan_text_rs("x |> _$coef[[1]]\n")$min_version, "4.3.0")
})

test_that("ur_scan_text_rs() reports named features", {
  expect_equal(ur_scan_text_rs("if (isa(x, 'a')) 1\n")$min_version, "4.1.0")
  expect_equal(ur_scan_text_rs("Sys.setLanguage('fr')\n")$min_version, "4.2.0")
  expect_equal(ur_scan_text_rs("s <- sort_by(df, x, y)\n")$min_version, "4.4.0")
  expect_equal(
    ur_scan_text_rs("Tailcall(f())\nExec(f())\n")$min_version,
    "4.4.0"
  )
  expect_equal(ur_scan_text_rs("use(foo, bar)\n")$min_version, "4.5.0")
  expect_equal(ur_scan_text_rs("grepv('a', x)\n")$min_version, "4.5.0")
  expect_equal(ur_scan_text_rs("penguins\n")$min_version, "4.5.0")
  expect_equal(ur_scan_text_rs("if (x %notin% y) 1\n")$min_version, "4.6.0")
  expect_equal(ur_scan_text_rs("messageCondition('m')\n")$min_version, "4.6.0")
})

test_that("ur_scan_text_rs() reports argument-level features", {
  res <- ur_scan_text_rs("match.arg(x, c('a', 'b'), several.ok = 'all')\n")
  expect_equal(res$feature, "match.arg")
  expect_equal(res$min_version, "4.6.0")

  expect_equal(
    ur_scan_text_rs("barplot(m, orderH = TRUE)\n")$min_version,
    "4.6.0"
  )
  expect_equal(ur_scan_text_rs("barplot(m, beside = TRUE)\n")$min_version, "")
  expect_equal(
    ur_scan_text_rs("match.arg(x, several.ok = FALSE)\n")$min_version,
    ""
  )
})

test_that("ur_scan_text_rs() ignores code that is not a call to the base function", {
  expect_equal(ur_scan_text_rs("'%||%'\n#' |> and \\(x)\n")$min_version, "")
  expect_equal(ur_scan_text_rs("x$use\ny@isa\n")$min_version, "")
  expect_equal(ur_scan_text_rs("foo(use = TRUE, isa = 1)\n")$min_version, "")
  expect_equal(
    ur_scan_text_rs("other::use(x)\nother::%||%(a, b)\n")$min_version,
    ""
  )
})

test_that("ur_scan_text_rs() ignores names defined by the package", {
  res <- ur_scan_text_rs("%||% <- function(x, y) x\nNULL %||% 1\n")
  expect_true(all(as.logical(res$local)))
  expect_equal(res$min_version, "")

  res <- ur_scan_text_rs(
    "`%notin%` <- function(x, table) !(x %in% table)\nx %notin% y\n"
  )
  expect_equal(res$min_version, "")

  res <- ur_scan_text_rs("assign('%||%', function(x, y) x)\nNULL %||% 1\n")
  expect_equal(res$min_version, "")

  # The definition itself may still use newer syntax.
  res <- ur_scan_text_rs("%||% <- \\(x, y) x\nNULL %||% 1\n")
  expect_equal(res$min_version, "4.1.0")
})

test_that("ur_scan_rs() walks .R files below the requested directories", {
  root <- withr::local_tempdir()
  dir.create(file.path(root, "R"))
  dir.create(file.path(root, "tests", "testthat"), recursive = TRUE)
  writeLines("f <- function(x) x %||% 1", file.path(root, "R", "a.R"))
  writeLines("g <- function(x) x + 1", file.path(root, "R", "b.R"))
  writeLines("h <- function(x) grepv('a', x)", file.path(root, "notes.txt"))
  writeLines(
    "k <- function(x) grepv('a', x)",
    file.path(root, "tests", "testthat", "test-k.R")
  )

  res <- ur_scan_rs(root, c("R", "tests/testthat", "missing"))
  expect_equal(res$files, c("R/a.R", "R/b.R", "tests/testthat/test-k.R"))
  expect_equal(res$min_version, "4.5.0")

  res_r <- ur_scan_rs(root, "R")
  expect_equal(res_r$files, c("R/a.R", "R/b.R"))
  expect_equal(res_r$min_version, "4.4.0")
})

test_that("ur_scan_rs() collects local definitions across files", {
  root <- withr::local_tempdir()
  dir.create(file.path(root, "R"))
  writeLines(
    "%||% <- function(x, y) if (is.null(x)) y else x",
    file.path(root, "R", "utils.R")
  )
  writeLines("f <- function(x) x %||% 1", file.path(root, "R", "f.R"))

  res <- ur_scan_rs(root, "R")
  expect_true(all(as.logical(res$local)))
  expect_equal(res$min_version, "")
})
