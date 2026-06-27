# Tests for use_vendor() and its internal helpers (R/43_use_vendor.R)

# ---------------------------------------------------------------------------
# repo_spec_parse()
# ---------------------------------------------------------------------------

test_that("repo_spec_parse parses owner/repo form", {
  spec <- rpkgkit:::repo_spec_parse("wurli/pedant")
  expect_equal(spec$owner, "wurli")
  expect_equal(spec$repo, "pedant")
  expect_equal(spec$repo_url, "https://github.com/wurli/pedant")
  expect_equal(
    spec$desc_url,
    "https://raw.githubusercontent.com/wurli/pedant/main/DESCRIPTION"
  )
})

test_that("repo_spec_parse parses full GitHub URL", {
  spec <- rpkgkit:::repo_spec_parse("https://github.com/dieghernan/pkgdev", branch = "dev")
  expect_equal(spec$owner, "dieghernan")
  expect_equal(spec$repo, "pkgdev")
  expect_equal(spec$repo_url, "https://github.com/dieghernan/pkgdev")
  expect_equal(
    spec$desc_url,
    "https://raw.githubusercontent.com/dieghernan/pkgdev/dev/DESCRIPTION"
  )
})

test_that("repo_spec_parse aborts without a slash", {
  expect_error(
    rpkgkit:::repo_spec_parse("invalid"),
    class = "rlang_error"
  )
})

# ---------------------------------------------------------------------------
# vendor_desc_license()
# ---------------------------------------------------------------------------

test_that("vendor_desc_license accepts MIT", {
  desc <- desc::description$new(text = "Package: x\nLicense: MIT\n")
  expect_identical(suppressMessages(rpkgkit:::vendor_desc_license(desc)), "MIT")
})

test_that("vendor_desc_license accepts BSD-2-Clause", {
  desc <- desc::description$new(text = "Package: x\nLicense: BSD-2-Clause\n")
  expect_identical(suppressMessages(rpkgkit:::vendor_desc_license(desc)), "BSD-2-Clause")
})

test_that("vendor_desc_license aborts on GPL-3", {
  desc <- desc::description$new(text = "Package: x\nLicense: GPL-3\n")
  expect_error(
    suppressMessages(rpkgkit:::vendor_desc_license(desc)),
    class = "rlang_error"
  )
})

# ---------------------------------------------------------------------------
# vendor_desc_authors()
# ---------------------------------------------------------------------------

test_that("vendor_desc_authors handles single author", {
  desc <- desc::description$new(
    text = sprintf(
      "Package: x\nAuthors@R: c(person(\"Alice\", \"Smith\", role = \"aut\"))\n"
    )
  )
  result <- rpkgkit:::vendor_desc_authors(desc)
  expect_equal(result$author_str, "Alice Smith")
})

test_that("vendor_desc_authors handles multiple authors", {
  desc <- desc::description$new(
    text = sprintf(
      "Package: x\nAuthors@R: c(person(\"Alice\", \"Smith\", role = \"aut\"), person(\"Bob\", \"Jones\", role = \"aut\"), person(\"Carol\", \"Lee\", role = \"aut\"))\n"
    )
  )
  result <- rpkgkit:::vendor_desc_authors(desc)
  expect_equal(result$author_str, "Alice Smith, Bob Jones and Carol Lee")
})

test_that("vendor_desc_authors uses given name when family is missing", {
  desc <- desc::description$new(
    text = sprintf(
      "Package: x\nAuthors@R: c(person(given = \"Alice\", role = \"aut\"))\n"
    )
  )
  result <- rpkgkit:::vendor_desc_authors(desc)
  expect_equal(result$author_str, "Alice")
})

test_that("vendor_desc_authors uses family name when given is missing", {
  desc <- desc::description$new(
    text = sprintf(
      "Package: x\nAuthors@R: c(person(family = \"Smith\", role = \"aut\"))\n"
    )
  )
  result <- rpkgkit:::vendor_desc_authors(desc)
  expect_equal(result$author_str, "Smith")
})

# ---------------------------------------------------------------------------
# vendor_download_file()
# ---------------------------------------------------------------------------

test_that("vendor_download_file returns lines on success", {
  local_mocked_bindings(
    request  = function(url) list(url = url),
    req_perform = function(req) list(req = req),
    resp_body_string = function(resp) "line1\nline2\nline3",
    .package = "httr2"
  )

  result <- rpkgkit:::vendor_download_file(
    owner = "wurli", repo = "pedant", branch = "main",
    path = "R/utils.R"
  )
  expect_equal(result, c("line1", "line2", "line3"))
})

test_that("vendor_download_file warns on HTTP error", {
  local_mocked_bindings(
    request  = function(url) list(url = url),
    req_perform = function(req) stop("HTTP 404"),
    .package = "httr2"
  )

  # Warnings inside tryCatch error handlers need expect_error to propagate
  expect_warning(
    expect_error(
      rpkgkit:::vendor_download_file(
        owner = "wurli", repo = "pedant", branch = "main",
        path = "R/missing.R"
      )
    ),
    "HTTP 404"
  )
})

# ---------------------------------------------------------------------------
# vendor_declare_source_license()
# ---------------------------------------------------------------------------

test_that("vendor_declare_source_license creates vendor directory and README", {
  tmp <- withr::local_tempdir()
  dir.create(file.path(tmp, "inst"), recursive = TRUE)

  local_mocked_bindings(
    request  = function(url) list(url = url, .called = TRUE),
    req_error = function(req, ...) req,
    req_perform = function(req) list(status = 200L, req = req),
    resp_status = function(resp) 200L,
    resp_body_string = function(resp) "MIT license text",
    .package = "httr2"
  )

  suppressMessages(
    rpkgkit:::vendor_declare_source_license(
      path = tmp, owner = "wurli", repo = "pedant",
      branch = "main", repo_url = "https://github.com/wurli/pedant"
    )
  )

  vendor_dir <- file.path(tmp, "inst", "vendor", "pedant")
  expect_true(dir.exists(vendor_dir))
  expect_true(file.exists(file.path(vendor_dir, "LICENSE")))
  expect_true(file.exists(file.path(vendor_dir, "README.md")))

  readme <- readLines(file.path(vendor_dir, "README.md"), warn = FALSE)
  expect_match(readme, "pedant", fixed = TRUE)
  expect_match(readme, "https://github.com/wurli/pedant", fixed = TRUE)
})

test_that("vendor_declare_source_license warns when no LICENSE found", {
  tmp <- withr::local_tempdir()
  dir.create(file.path(tmp, "inst"), recursive = TRUE)

  local_mocked_bindings(
    request  = function(url) list(url = url),
    req_error = function(req, ...) req,
    req_perform = function(req) stop("HTTP 404"),
    resp_status = function(resp) 404L,
    .package = "httr2"
  )

  suppressMessages(
    expect_warning(
      rpkgkit:::vendor_declare_source_license(
        path = tmp, owner = "wurli", repo = "pedant",
        branch = "main", repo_url = "https://github.com/wurli/pedant"
      ),
      "No LICENSE files found"
    )
  )
})

# ---------------------------------------------------------------------------
# vendor_create_r_file()
# ---------------------------------------------------------------------------

test_that("vendor_create_r_file creates header with attribution", {
  tmp <- withr::local_tempdir()
  dir.create(file.path(tmp, "R"))

  rpkgkit:::vendor_create_r_file(
    path = tmp, repo = "pedant",
    repo_url = "https://github.com/wurli/pedant",
    author_str = "Jacob Scott",
    license = "MIT",
    owner = "wurli",
    branch = "main",
    dots = list()
  )

  r_path <- file.path(tmp, "R", "vendor-pedant.R")
  expect_true(file.exists(r_path))

  lines <- readLines(r_path, warn = FALSE)
  expect_match(lines[2L], "pedant", fixed = TRUE)
  expect_match(lines[3L], "https://github.com/wurli/pedant", fixed = TRUE)
  expect_match(lines[4L], "Jacob Scott", fixed = TRUE)
  expect_match(lines[5L], "MIT", fixed = TRUE)
  expect_true(any(grepl("nocov start", lines)))
  expect_true(any(grepl("nocov end", lines)))
})

test_that("vendor_create_r_file appends downloaded file content", {
  tmp <- withr::local_tempdir()
  dir.create(file.path(tmp, "R"))

  local_mocked_bindings(
    vendor_download_file = function(...) c("fun1 <- function(x) x", "fun2 <- function(x) x + 1")
  )

  rpkgkit:::vendor_create_r_file(
    path = tmp, repo = "pedant",
    repo_url = "https://github.com/wurli/pedant",
    author_str = "Jacob Scott",
    license = "MIT",
    owner = "wurli",
    branch = "main",
    dots = list("R/utils.R")
  )

  lines <- readLines(file.path(tmp, "R", "vendor-pedant.R"), warn = FALSE)
  expect_true(any(grepl("fun1 <- function", lines)))
  expect_true(any(grepl("fun2 <- function", lines)))
  expect_true(any(grepl("File: R/utils\\.R", lines)))
})

test_that("vendor_create_r_file handles empty dots with only header and nocov markers", {
  tmp <- withr::local_tempdir()
  dir.create(file.path(tmp, "R"))

  rpkgkit:::vendor_create_r_file(
    path = tmp, repo = "pedant",
    repo_url = "https://github.com/wurli/pedant",
    author_str = "Jacob Scott",
    license = "MIT",
    owner = "wurli",
    branch = "main",
    dots = list()
  )

  lines <- readLines(file.path(tmp, "R", "vendor-pedant.R"), warn = FALSE)
  # nocov markers should exist and no file sections between them
  start_idx <- grep("nocov start", lines)
  end_idx <- grep("nocov end", lines)
  expect_equal(length(start_idx), 1L)
  expect_equal(length(end_idx), 1L)
  # With empty dots, no "File:" annotation lines exist
  expect_false(any(grepl("^# File:", lines)))
})

# ---------------------------------------------------------------------------
# vendor_update_desc()
# ---------------------------------------------------------------------------

test_that("vendor_update_desc adds authors to DESCRIPTION", {
  tmp <- withr::local_tempdir()
  writeLines(c(
    "Package: mypkg",
    "Title: My Package",
    "Version: 1.0.0",
    "Authors@R: c(person(given = \"Original\", family = \"Author\", role = c(\"aut\", \"cre\")))"
  ), file.path(tmp, "DESCRIPTION"))

  author_info <- rpkgkit:::vendor_desc_authors(
    desc::description$new(
      text = "Package: x\nAuthors@R: c(person(\"Alice\", \"Smith\", role = \"aut\"))\n"
    )
  )

  suppressMessages(
    rpkgkit:::vendor_update_desc(
      path = tmp,
      author_info = author_info,
      repo = "pedant",
      repo_url = "https://github.com/wurli/pedant"
    )
  )

  desc <- desc::desc(file = file.path(tmp, "DESCRIPTION"))
  authors <- desc$get_authors()
  expect_true(any(vapply(authors, function(p) {
    "aut" %in% (p$role %||% character(0L)) &&
      "cph" %in% (p$role %||% character(0L)) &&
      grepl("pedant", p$comment %||% "", fixed = TRUE)
  }, logical(1L))))
})

test_that("vendor_update_desc skips already-present authors", {
  tmp <- withr::local_tempdir()
  writeLines(c(
    "Package: mypkg",
    "Title: My Package",
    "Version: 1.0.0",
    "Authors@R: c(person(given = \"Original\", family = \"Author\", role = c(\"aut\", \"cre\")))"
  ), file.path(tmp, "DESCRIPTION"))

  author_info <- rpkgkit:::vendor_desc_authors(
    desc::description$new(
      text = "Package: x\nAuthors@R: c(person(\"Alice\", \"Smith\", role = \"aut\"))\n"
    )
  )

  # Add once
  suppressMessages(
    rpkgkit:::vendor_update_desc(
      path = tmp,
      author_info = author_info,
      repo = "pedant",
      repo_url = "https://github.com/wurli/pedant"
    )
  )

  desc <- desc::desc(file = file.path(tmp, "DESCRIPTION"))
  count_before <- length(desc$get_authors())

  # Add again — should be skipped
  suppressMessages(
    rpkgkit:::vendor_update_desc(
      path = tmp,
      author_info = author_info,
      repo = "pedant",
      repo_url = "https://github.com/wurli/pedant"
    )
  )

  desc <- desc::desc(file = file.path(tmp, "DESCRIPTION"))
  expect_equal(length(desc$get_authors()), count_before)
})

test_that("vendor_update_desc sets Copyright field", {
  tmp <- withr::local_tempdir()
  writeLines(c(
    "Package: mypkg",
    "Title: My Package",
    "Version: 1.0.0",
    "Authors@R: c(person(given = \"Original\", family = \"Author\", role = c(\"aut\", \"cre\")))"
  ), file.path(tmp, "DESCRIPTION"))

  author_info <- rpkgkit:::vendor_desc_authors(
    desc::description$new(
      text = "Package: x\nAuthors@R: c(person(\"Alice\", \"Smith\", role = \"aut\"))\n"
    )
  )

  suppressMessages(
    rpkgkit:::vendor_update_desc(
      path = tmp,
      author_info = author_info,
      repo = "pedant",
      repo_url = "https://github.com/wurli/pedant"
    )
  )

  desc <- desc::desc(file = file.path(tmp, "DESCRIPTION"))
  copyright <- desc$get("Copyright")
  expect_match(copyright, "Alice Smith", fixed = TRUE)
  expect_match(copyright, "pedant", fixed = TRUE)
})

test_that("vendor_update_desc appends to existing Copyright field", {
  tmp <- withr::local_tempdir()
  writeLines(c(
    "Package: mypkg",
    "Title: My Package",
    "Version: 1.0.0",
    "Authors@R: c(person(given = \"Original\", family = \"Author\", role = c(\"aut\", \"cre\")))",
    "Copyright: Original author"
  ), file.path(tmp, "DESCRIPTION"))

  author_info <- rpkgkit:::vendor_desc_authors(
    desc::description$new(
      text = "Package: x\nAuthors@R: c(person(\"Bob\", \"Jones\", role = \"aut\"))\n"
    )
  )

  suppressMessages(
    rpkgkit:::vendor_update_desc(
      path = tmp,
      author_info = author_info,
      repo = "pedant",
      repo_url = "https://github.com/wurli/pedant"
    )
  )

  desc <- desc::desc(file = file.path(tmp, "DESCRIPTION"))
  copyright <- desc$get("Copyright")
  expect_match(copyright, "Original author", fixed = TRUE)
  expect_match(copyright, "Bob Jones", fixed = TRUE)
})

# ---------------------------------------------------------------------------
# use_vendor()
# ---------------------------------------------------------------------------

test_that("use_vendor aborts when path is not an R package", {
  tmp <- withr::local_tempdir()

  expect_error(
    use_vendor("wurli/pedant", path = tmp),
    "not an R package"
  )
})
