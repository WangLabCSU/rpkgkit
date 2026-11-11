# A synthetic lookup keeps these tests independent of which packages happen to
# be installed: only the tokenizer/rewriter behaviour is under test.
mfce_test_context <- function(
  fun_exports = c("filter", "select", "mutate"),
  fun_packages = rep("dplyr", length(fun_exports)),
  data_exports = "mtcars",
  data_packages = rep("datasets", length(data_exports)),
  use_packages = unique(c(fun_packages, data_packages)),
  ignore_functions = character()
) {
  list(
    use_packages = use_packages,
    ignore_functions = ignore_functions,
    fun_exports = fun_exports,
    fun_packages = fun_packages,
    data_exports = data_exports,
    data_packages = data_packages
  )
}

rewrite <- function(code, context = mfce_test_context()) {
  mfce_rewrite(code, context)
}

test_that("qualifies calls from the requested packages", {
  result <- rewrite("filter(x)")
  expect_true(result$changed)
  expect_equal(result$text, "dplyr::filter(x)")
  expect_length(result$not_found, 0L)
})

test_that("leaves already namespaced calls alone", {
  for (code in c("dplyr::filter(x)", "dplyr:::filter(x)", "stats::filter(x)")) {
    result <- rewrite(code)
    expect_false(result$changed)
    expect_equal(result$text, code)
  }
})

# Regression test: `l$select` is a list element, not `dplyr::select()`.
test_that("does not qualify members accessed with $ or @", {
  code <- paste(
    "l <- list(select = 1)",
    "l2 <- l$select + 1",
    "l3 <- l$select(1)",
    "l4 <- l@select",
    "l5 <- l$mtcars",
    sep = "\n"
  )
  result <- rewrite(code)
  expect_false(result$changed)
  expect_equal(result$text, code)
  # `select` and `mtcars` are only reached through `$`/`@`, never as calls.
  expect_false(any(grepl("select|mtcars", result$not_found)))
})

test_that("does not qualify formal arguments", {
  code <- "f <- function(mtcars, select) select"
  result <- rewrite(code)
  expect_false(result$changed)
  expect_equal(result$text, code)
})

test_that("does not qualify the dataset names passed to data()", {
  code <- "data(mtcars)"
  result <- rewrite(code)
  expect_false(result$changed)
  expect_equal(result$text, code)

  code <- "utils::data(mtcars)"
  result <- rewrite(code)
  expect_false(result$changed)
  expect_equal(result$text, code)
})

test_that("does not qualify assignment targets", {
  code <- "filter <- 1"
  result <- rewrite(code)
  expect_false(result$changed)
  expect_equal(result$text, code)
})

test_that("qualifies exported datasets", {
  result <- rewrite("head(mtcars)")
  expect_true(result$changed)
  expect_equal(result$text, "head(datasets::mtcars)")
})

test_that("ignores identifiers inside strings and comments", {
  code <- c(
    "# filter(x)",
    "x <- \"filter(x)\"",
    "y <- 'select(1)'"
  )
  code <- paste(code, collapse = "\n")
  result <- rewrite(code)
  expect_false(result$changed)
  expect_equal(result$text, code)
})

test_that("honours ignore_functions", {
  result <- rewrite(
    "filter(x)",
    mfce_test_context(ignore_functions = "filter")
  )
  expect_false(result$changed)
  expect_equal(result$text, "filter(x)")
})

test_that("does not qualify functions of the base package", {
  context <- mfce_test_context(
    fun_exports = "mean",
    fun_packages = "base",
    data_exports = character(),
    data_packages = character(),
    use_packages = "base"
  )
  result <- rewrite("mean(x)", context)
  expect_false(result$changed)
  expect_equal(result$text, "mean(x)")
})

test_that("qualifies backticked calls and keeps the backticks", {
  context <- mfce_test_context(
    fun_exports = "my fun",
    fun_packages = "dplyr",
    data_exports = character(),
    data_packages = character(),
    use_packages = "dplyr"
  )
  result <- rewrite("`my fun`(1)", context)
  expect_true(result$changed)
  expect_equal(result$text, "dplyr::`my fun`(1)")
})

test_that("reports functions that no package exports", {
  result <- rewrite("unknown_fun(1)")
  expect_false(result$changed)
  expect_equal(result$text, "unknown_fun(1)")
  expect_equal(result$not_found, "unknown_fun")
})

test_that("resolves a name to the first package that exports it", {
  context <- mfce_test_context(
    fun_exports = c("filter", "filter"),
    fun_packages = c("dplyr", "stats"),
    data_exports = character(),
    data_packages = character(),
    use_packages = c("dplyr", "stats")
  )
  result <- rewrite("filter(x)", context)
  expect_equal(result$text, "dplyr::filter(x)")
})

test_that("make_func_call_explicit rewrites the file in place", {
  path <- withr::local_tempfile(fileext = ".R", lines = "filter(1)")

  expect_invisible(
    make_func_call_explicit(path = path, use_packages = "stats")
  )
  expect_equal(readLines(path), "stats::filter(1)")
})

test_that("make_func_call_explicit keeps the final-newline state", {
  with_newline <- withr::local_tempfile(fileext = ".R", lines = "filter(1)")
  make_func_call_explicit(path = with_newline, use_packages = "stats")
  expect_equal(readChar(with_newline, nchars = 100L), "stats::filter(1)\n")

  without_newline <- withr::local_tempfile(fileext = ".R")
  cat("filter(1)", file = without_newline, sep = "")
  make_func_call_explicit(path = without_newline, use_packages = "stats")
  expect_equal(readChar(without_newline, nchars = 100L), "stats::filter(1)")
})

test_that("make_func_call_explicit leaves unchanged files untouched", {
  path <- withr::local_tempfile(fileext = ".R", lines = "stats::median(1)")
  before <- file.mtime(path)
  Sys.setFileTime(path, before - 60)
  make_func_call_explicit(path = path, use_packages = "stats")
  expect_equal(readLines(path), "stats::median(1)")
  expect_true(file.mtime(path) < before)
})

test_that("make_func_call_explicit warns about unknown functions", {
  path <- withr::local_tempfile(fileext = ".R", lines = "unknown_fun(1)")
  expect_warning(
    make_func_call_explicit(path = path, use_packages = "stats"),
    "Couldn't find packages exporting"
  )
})

test_that("make_func_call_explicit aborts without a path", {
  local_mocked_bindings(
    isAvailable = function() FALSE,
    .package = "rstudioapi"
  )
  expect_error(
    make_func_call_explicit(use_packages = "stats"),
    "is required"
  )
})

# ---------------------------------------------------------------------------
# get_defined_fn(): package root -> all R/ functions; otherwise -> one file
# ---------------------------------------------------------------------------

test_that("get_defined_fn returns every function defined under R/ of a package", {
  pkg <- withr::local_tempdir()
  dir.create(file.path(pkg, "R"), recursive = TRUE)
  writeLines("Package: testpkg", file.path(pkg, "DESCRIPTION"))
  writeLines(
    c(
      "foo <- function(x) x",
      "bar = function(x) x",
      "`qux` <- function(x) x",
      "not_a_fn <- 1",
      "print.foo <- function(x) x"
    ),
    file.path(pkg, "R", "defs.R")
  )
  writeLines("baz <- function(x) x", file.path(pkg, "R", "other.R"))
  writeLines("this is ( not valid R", file.path(pkg, "R", "broken.R"))

  got <- get_defined_fn(pkg)
  expect_true(is.character(got))
  expect_setequal(got, c("foo", "bar", "qux", "print.foo", "baz"))
})

test_that("get_defined_fn reads only the given file outside a package", {
  f <- withr::local_tempfile(
    fileext = ".R",
    lines = c("foo <- function(x) x", "bar <- 1", "baz <- function(y) y")
  )
  expect_setequal(get_defined_fn(f), c("foo", "baz"))
})

test_that("get_defined_fn does not walk up to parent directories", {
  pkg <- withr::local_tempdir()
  dir.create(file.path(pkg, "R"), recursive = TRUE)
  writeLines("Package: testpkg", file.path(pkg, "DESCRIPTION"))
  writeLines("outer_fn <- function(x) x", file.path(pkg, "R", "defs.R"))
  inner <- file.path(pkg, "R", "nested")
  dir.create(inner)

  expect_identical(get_defined_fn(inner), character())
  expect_identical(get_defined_fn(file.path(pkg, "missing.R")), character())
})

test_that("get_defined_fn() defaults to the current path", {
  tmp <- withr::local_tempdir()
  withr::local_dir(tmp)
  expect_identical(get_defined_fn(), character())
})

test_that("default ignore set protects functions defined in the target file", {
  f <- withr::local_tempfile(
    fileext = ".R",
    lines = c("filter <- function(x) x", "filter(mpg > 20)")
  )
  make_func_call_explicit(path = f, use_packages = "stats")
  expect_equal(readLines(f), c("filter <- function(x) x", "filter(mpg > 20)"))

  make_func_call_explicit(
    path = f,
    use_packages = "stats",
    ignore_functions = character()
  )
  expect_equal(
    readLines(f),
    c("filter <- function(x) x", "stats::filter(mpg > 20)")
  )
})

test_that("package_func_call_explicit ignores functions defined in the package", {
  pkg <- withr::local_tempdir()
  dir.create(file.path(pkg, "R"), recursive = TRUE)
  writeLines("Package: testpkg", file.path(pkg, "DESCRIPTION"))
  writeLines("filter <- function(x) x", file.path(pkg, "R", "defs.R"))
  target <- file.path(pkg, "R", "use.R")
  writeLines("filter(mpg > 20)", target)

  package_func_call_explicit(pkg, use_packages = "stats")
  expect_equal(readLines(target), "filter(mpg > 20)")
})

test_that("default ignore set also includes imported_functions()", {
  pkg <- withr::local_tempdir()
  dir.create(file.path(pkg, "R"), recursive = TRUE)
  writeLines("Package: testpkg", file.path(pkg, "DESCRIPTION"))
  writeLines("importFrom(stats, median)", file.path(pkg, "NAMESPACE"))
  target <- file.path(pkg, "R", "use.R")
  writeLines("median(x)", target)

  withr::local_dir(pkg)
  package_func_call_explicit(pkg, use_packages = "stats")
  expect_equal(readLines(target), "median(x)")
})
