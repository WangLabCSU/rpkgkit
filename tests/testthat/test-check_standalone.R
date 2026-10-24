# Test: check_standalone -------------------------------------------------------

# --- Helpers ------------------------------------------------------------------

# Build a standalone header from named slots, e.g.
# cs_header_lines(repo = "owner/repo", file = "standalone-foo.R")
cs_header_lines <- function(...) {
  slots <- list(...)
  values <- vapply(slots, as.character, character(1L))
  c("# ---", paste0("# ", names(slots), ": ", values), "# ---")
}

# A minimal, fully conforming header (no `path`, so the file name is not checked)
cs_valid_header <- function() {
  cs_header_lines(
    repo = "owner/repo",
    file = "standalone-foo.R",
    `last-updated` = "2020-01-01",
    license = "https://unlicense.org"
  )
}

# Evaluate `expr` while swallowing the console output of the checks
cs_quiet <- function(expr) {
  res <- NULL
  utils::capture.output(res <- suppressMessages(expr))
  res
}

# ==============================================================================
# .cs_new_result
# ==============================================================================

test_that(".cs_new_result returns zeroed counts", {
  res <- rpkgkit:::.cs_new_result()
  expect_named(res, c("error", "warning", "note"))
  expect_identical(res, list(error = 0L, warning = 0L, note = 0L))
})

# ==============================================================================
# check_standalone: input validation
# ==============================================================================

test_that("check_standalone aborts when no path can be resolved", {
  local_mocked_bindings(
    isAvailable = function() FALSE,
    .package = "rstudioapi"
  )

  expect_error(check_standalone(), "is required")
})

test_that("check_standalone aborts when path is an empty string", {
  expect_error(check_standalone(""), "is required")
})

test_that("check_standalone aborts when path does not exist", {
  expect_error(check_standalone(tempfile("no-such-file")), "is not a file")
})

test_that("check_standalone aborts when path is a directory", {
  tmp <- withr::local_tempdir()
  expect_error(check_standalone(tmp), "is not a file")
})

test_that("check_standalone rejects unused dots", {
  expect_error(
    check_standalone("whatever.R", unused = 1),
    "must be empty"
  )
})

# ==============================================================================
# check_standalone: integration
# ==============================================================================

test_that("check_standalone reports no problems for a conforming file", {
  path <- withr::local_tempfile(fileext = ".R")
  writeLines(
    c(
      cs_header_lines(
        repo = "owner/repo",
        file = basename(path),
        `last-updated` = "2020-01-01",
        license = "https://unlicense.org"
      ),
      "",
      "# nocov start",
      "",
      "#' Foo",
      "#' @noRd",
      "foo <- function() 1",
      "# nocov end"
    ),
    path
  )

  res <- cs_quiet(check_standalone(path))

  expect_named(res, c("error", "warning", "note"))
  expect_identical(res, list(error = 0L, warning = 0L, note = 0L))
})

test_that("check_standalone aggregates problems from several check points", {
  path <- withr::local_tempfile(fileext = ".R")
  writeLines(
    c(
      cs_header_lines(
        repo = "owner/repo",
        file = basename(path),
        `last-updated` = "2020-01-01",
        license = "https://unlicense.org"
      ),
      "",
      "#' Foo",
      "foo <- function() 1"
    ),
    path
  )

  res <- cs_quiet(check_standalone(path))

  # One error for the missing `@noRd`, one for the missing `# nocov start`
  expect_equal(res$error, 2L)
  expect_equal(res$warning, 0L)
  expect_equal(res$note, 0L)
})

test_that("check_standalone counts warnings and notes from the header", {
  path <- withr::local_tempfile(fileext = ".R")
  writeLines(
    c(
      cs_header_lines(
        repo = "owner", # warning: not `owner/repo`
        file = basename(path),
        `last-updated` = "2020-01-01",
        license = "MIT", # note: not a URL
        imports = "" # note: empty slot
      ),
      "",
      "# nocov start",
      "",
      "foo <- function() 1"
    ),
    path
  )

  res <- cs_quiet(check_standalone(path))

  expect_equal(res$error, 0L)
  expect_equal(res$warning, 1L)
  expect_equal(res$note, 2L)
})

test_that("check_standalone prints a duration and a summary", {
  path <- withr::local_tempfile(fileext = ".R")
  writeLines(
    c(
      cs_header_lines(
        repo = "owner/repo",
        file = basename(path),
        `last-updated` = "2020-01-01",
        license = "https://unlicense.org"
      ),
      "",
      "# nocov start",
      "",
      "foo <- function() 1"
    ),
    path
  )

  out <- utils::capture.output(res <- suppressMessages(check_standalone(path)))

  expect_true(any(grepl("standalone check results", out)))
  expect_true(any(grepl("Duration:", out)))
  expect_named(res, c("error", "warning", "note"))
})

test_that("check_standalone returns its result invisibly", {
  path <- withr::local_tempfile(fileext = ".R")
  writeLines(cs_valid_header(), path)

  vis <- NULL
  utils::capture.output(
    vis <- withVisible(suppressMessages(check_standalone(path)))
  )

  expect_false(vis$visible)
  expect_named(vis$value, c("error", "warning", "note"))
})

# ==============================================================================
# .cs_header: header markers
# ==============================================================================

test_that(".cs_header errors on an empty file", {
  res <- cs_quiet(rpkgkit:::.cs_header(character()))
  expect_equal(res$error, 1L)
})

test_that(".cs_header errors when line 1 is not the opening marker", {
  res <- cs_quiet(rpkgkit:::.cs_header(c("# not a marker", "# ---")))
  expect_equal(res$error, 1L)
})

test_that(".cs_header errors when the closing marker is missing", {
  res <- cs_quiet(rpkgkit:::.cs_header(c("# ---", "# repo: owner/repo")))
  expect_equal(res$error, 1L)
})

test_that(".cs_header passes a well-formed header", {
  res <- cs_quiet(rpkgkit:::.cs_header(cs_valid_header()))
  expect_identical(res, list(error = 0L, warning = 0L, note = 0L))
})

test_that(".cs_header ignores comment-only lines inside the header", {
  lines <- c(
    "# ---",
    "#",
    "# repo: owner/repo",
    "#",
    "# file: standalone-foo.R",
    "# last-updated: 2020-01-01",
    "# license: https://unlicense.org",
    "# ---"
  )
  res <- cs_quiet(rpkgkit:::.cs_header(lines))
  expect_identical(res, list(error = 0L, warning = 0L, note = 0L))
})

# ==============================================================================
# .cs_header: slot presence and values
# ==============================================================================

test_that(".cs_header errors on missing required slots", {
  res <- cs_quiet(rpkgkit:::.cs_header(c("# ---", "# repo: owner/repo", "# ---")))
  expect_equal(res$error, 3L)
})

test_that(".cs_header errors on a required slot without a value", {
  lines <- c(
    "# ---",
    "# repo: ",
    "# file: standalone-foo.R",
    "# last-updated: 2020-01-01",
    "# license: https://unlicense.org",
    "# ---"
  )
  res <- cs_quiet(rpkgkit:::.cs_header(lines))
  expect_equal(res$error, 1L)
})

test_that(".cs_header warns on a malformed slot line", {
  lines <- c(
    "# ---",
    "# repo: owner/repo",
    "# this line has no key",
    "# file: standalone-foo.R",
    "# last-updated: 2020-01-01",
    "# license: https://unlicense.org",
    "# ---"
  )
  res <- cs_quiet(rpkgkit:::.cs_header(lines))
  expect_equal(res$warning, 1L)
  expect_equal(res$error, 0L)
})

test_that(".cs_header warns on a duplicated slot", {
  lines <- c(
    "# ---",
    "# repo: owner/repo",
    "# repo: owner/other",
    "# file: standalone-foo.R",
    "# last-updated: 2020-01-01",
    "# license: https://unlicense.org",
    "# ---"
  )
  res <- cs_quiet(rpkgkit:::.cs_header(lines))
  expect_equal(res$warning, 1L)
  expect_equal(res$error, 0L)
})

test_that(".cs_header notes an empty `imports` slot", {
  lines <- cs_header_lines(
    repo = "owner/repo",
    file = "standalone-foo.R",
    `last-updated` = "2020-01-01",
    license = "https://unlicense.org",
    imports = ""
  )
  res <- cs_quiet(rpkgkit:::.cs_header(lines))
  expect_equal(res$note, 1L)
  expect_equal(res$error, 0L)
})

test_that(".cs_header accepts a populated `imports` slot", {
  lines <- cs_header_lines(
    repo = "owner/repo",
    file = "standalone-foo.R",
    `last-updated` = "2020-01-01",
    license = "https://unlicense.org",
    imports = "rlang, cli"
  )
  res <- cs_quiet(rpkgkit:::.cs_header(lines))
  expect_identical(res, list(error = 0L, warning = 0L, note = 0L))
})

test_that(".cs_header notes non-standard slots", {
  lines <- cs_header_lines(
    repo = "owner/repo",
    file = "standalone-foo.R",
    `last-updated` = "2020-01-01",
    license = "https://unlicense.org",
    dependency = "dplyr"
  )
  res <- cs_quiet(rpkgkit:::.cs_header(lines))
  expect_equal(res$note, 1L)
})

test_that(".cs_header warns on a `repo` that is not `owner/repo`", {
  lines <- cs_header_lines(
    repo = "owner",
    file = "standalone-foo.R",
    `last-updated` = "2020-01-01",
    license = "https://unlicense.org"
  )
  res <- cs_quiet(rpkgkit:::.cs_header(lines))
  expect_equal(res$warning, 1L)
})

test_that(".cs_header warns on a `file` that does not end in .R", {
  lines <- cs_header_lines(
    repo = "owner/repo",
    file = "standalone-foo.txt",
    `last-updated` = "2020-01-01",
    license = "https://unlicense.org"
  )
  res <- cs_quiet(rpkgkit:::.cs_header(lines))
  expect_equal(res$warning, 1L)
})

test_that(".cs_header notes a `file` that differs from the actual file name", {
  lines <- cs_header_lines(
    repo = "owner/repo",
    file = "standalone-foo.R",
    `last-updated` = "2020-01-01",
    license = "https://unlicense.org"
  )
  res <- cs_quiet(rpkgkit:::.cs_header(
    lines,
    path = file.path(tempdir(), "standalone-bar.R")
  ))
  expect_equal(res$note, 1L)
})

test_that(".cs_header accepts a `file` matching the actual file name", {
  lines <- cs_header_lines(
    repo = "owner/repo",
    file = "standalone-foo.R",
    `last-updated` = "2020-01-01",
    license = "https://unlicense.org"
  )
  res <- cs_quiet(rpkgkit:::.cs_header(
    lines,
    path = file.path(tempdir(), "standalone-foo.R")
  ))
  expect_equal(res$note, 0L)
})

test_that(".cs_header accepts the `import-` prefixed file name", {
  lines <- cs_header_lines(
    repo = "owner/repo",
    file = "standalone-foo.R",
    `last-updated` = "2020-01-01",
    license = "https://unlicense.org"
  )
  res <- cs_quiet(rpkgkit:::.cs_header(
    lines,
    path = file.path(tempdir(), "import-standalone-foo.R")
  ))
  expect_equal(res$note, 0L)
})

test_that(".cs_header errors on an invalid `last-updated` date", {
  lines <- cs_header_lines(
    repo = "owner/repo",
    file = "standalone-foo.R",
    `last-updated` = "2020-13-01",
    license = "https://unlicense.org"
  )
  res <- cs_quiet(rpkgkit:::.cs_header(lines))
  expect_equal(res$error, 1L)
})

test_that(".cs_header warns on a `last-updated` date in the future", {
  lines <- cs_header_lines(
    repo = "owner/repo",
    file = "standalone-foo.R",
    `last-updated` = format(Sys.Date() + 365, "%Y-%m-%d"),
    license = "https://unlicense.org"
  )
  res <- cs_quiet(rpkgkit:::.cs_header(lines))
  expect_equal(res$warning, 1L)
  expect_equal(res$error, 0L)
})

test_that(".cs_header notes a `license` that is not a URL", {
  lines <- cs_header_lines(
    repo = "owner/repo",
    file = "standalone-foo.R",
    `last-updated` = "2020-01-01",
    license = "MIT"
  )
  res <- cs_quiet(rpkgkit:::.cs_header(lines))
  expect_equal(res$note, 1L)
})

# ==============================================================================
# .cs_noRd
# ==============================================================================

test_that(".cs_noRd errors on a documented function without @noRd", {
  lines <- c(
    "#' Foo",
    "#' @export",
    "foo <- function() 1"
  )
  res <- cs_quiet(rpkgkit:::.cs_noRd(lines))
  expect_equal(res$error, 1L)
})

test_that(".cs_noRd accepts a documented function with @noRd", {
  lines <- c(
    "#' Foo",
    "#' @noRd",
    "foo <- function() 1"
  )
  res <- cs_quiet(rpkgkit:::.cs_noRd(lines))
  expect_identical(res, list(error = 0L, warning = 0L, note = 0L))
})

test_that(".cs_noRd skips undocumented functions", {
  lines <- c(
    "foo <- function() 1",
    "bar <- \\(x) x"
  )
  res <- cs_quiet(rpkgkit:::.cs_noRd(lines))
  expect_equal(res$error, 0L)
})

test_that(".cs_noRd notes a file without function definitions", {
  lines <- c("# just a comment", "x <- 1")
  res <- cs_quiet(rpkgkit:::.cs_noRd(lines))
  expect_equal(res$note, 1L)
  expect_equal(res$error, 0L)
})

test_that(".cs_noRd reports a parse error", {
  res <- cs_quiet(rpkgkit:::.cs_noRd("foo <- function("))
  expect_equal(res$error, 1L)
})

# ==============================================================================
# .cs_nocov
# ==============================================================================

test_that(".cs_nocov passes when the marker precedes all functions", {
  lines <- c(
    "# nocov start",
    "",
    "foo <- function() 1",
    "# nocov end"
  )
  res <- cs_quiet(rpkgkit:::.cs_nocov(lines))
  expect_identical(res, list(error = 0L, warning = 0L, note = 0L))
})

test_that(".cs_nocov accepts a file without `# nocov end`", {
  lines <- c(
    "# nocov start",
    "",
    "foo <- function() 1"
  )
  res <- cs_quiet(rpkgkit:::.cs_nocov(lines))
  expect_equal(res$error, 0L)
})

test_that(".cs_nocov errors when the marker is missing", {
  res <- cs_quiet(rpkgkit:::.cs_nocov("foo <- function() 1"))
  expect_equal(res$error, 1L)
})

test_that(".cs_nocov errors when functions precede the marker", {
  lines <- c(
    "foo <- function() 1",
    "",
    "# nocov start"
  )
  res <- cs_quiet(rpkgkit:::.cs_nocov(lines))
  expect_equal(res$error, 1L)
})

test_that(".cs_nocov reports a parse error", {
  res <- cs_quiet(rpkgkit:::.cs_nocov("foo <- function("))
  expect_equal(res$error, 1L)
})

# ==============================================================================
# .cs_find_functions
# ==============================================================================

test_that(".cs_find_functions finds top-level function definitions", {
  lines <- c(
    "foo <- function() 1",
    "bar = function(x) x",
    "baz <<- function() 2",
    "qux <- \\(x) x",
    "x <- 1",
    "y <- list(a = 1)"
  )
  res <- rpkgkit:::.cs_find_functions(lines)

  expect_equal(res$name, c("foo", "bar", "baz", "qux"))
  expect_equal(res$line, 1:4)
})

test_that(".cs_find_functions ignores nested definitions", {
  lines <- c(
    "foo <- function() {",
    "  bar <- function() 1",
    "  bar()",
    "}"
  )
  res <- rpkgkit:::.cs_find_functions(lines)
  expect_equal(res$name, "foo")
  expect_equal(res$line, 1L)
})

test_that(".cs_find_functions returns an empty result when there are no functions", {
  res <- rpkgkit:::.cs_find_functions(c("x <- 1", "y <- 2"))
  expect_length(res$name, 0L)
  expect_length(res$line, 0L)
})

test_that(".cs_find_functions returns the parse error", {
  res <- rpkgkit:::.cs_find_functions("foo <- function(")
  expect_s3_class(res, "error")
})

# ==============================================================================
# .cs_get_doc
# ==============================================================================

test_that(".cs_get_doc returns the roxygen block above a function", {
  lines <- c("#' Foo", "#' @noRd", "foo <- function() 1")
  expect_equal(rpkgkit:::.cs_get_doc(lines, 3L), c("#' Foo", "#' @noRd"))
})

test_that(".cs_get_doc returns nothing when the function is undocumented", {
  lines <- c("x <- 1", "foo <- function() 1")
  expect_length(rpkgkit:::.cs_get_doc(lines, 2L), 0L)
})

test_that(".cs_get_doc stops at a blank line", {
  lines <- c("#' Foo", "", "foo <- function() 1")
  expect_length(rpkgkit:::.cs_get_doc(lines, 3L), 0L)
})

test_that(".cs_get_doc handles a function on the first line", {
  expect_length(rpkgkit:::.cs_get_doc("foo <- function() 1", 1L), 0L)
})
