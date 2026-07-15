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
  spec <- rpkgkit:::repo_spec_parse(
    "https://github.com/dieghernan/pkgdev",
    branch = "dev"
  )
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
  expect_identical(
    suppressMessages(rpkgkit:::vendor_desc_license(desc)),
    "BSD-2-Clause"
  )
})

test_that("vendor_desc_license accepts Apache-2.0", {
  desc <- desc::description$new(text = "Package: x\nLicense: Apache-2.0\n")
  expect_identical(
    suppressMessages(rpkgkit:::vendor_desc_license(desc)),
    "Apache-2.0"
  )
})

test_that("vendor_desc_license accepts Unlicense", {
  desc <- desc::description$new(text = "Package: x\nLicense: Unlicense\n")
  expect_identical(
    suppressMessages(rpkgkit:::vendor_desc_license(desc)),
    "Unlicense"
  )
})

test_that("vendor_desc_license accepts CC0", {
  desc <- desc::description$new(text = "Package: x\nLicense: CC0\n")
  expect_identical(suppressMessages(rpkgkit:::vendor_desc_license(desc)), "CC0")
})

test_that("vendor_desc_license aborts on GPL-3", {
  desc <- desc::description$new(text = "Package: x\nLicense: GPL-3\n")
  expect_error(
    suppressMessages(rpkgkit:::vendor_desc_license(desc)),
    class = "rlang_error"
  )
})

test_that("vendor_desc_license aborts on AGPL-3", {
  desc <- desc::description$new(text = "Package: x\nLicense: AGPL-3\n")
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

test_that("vendor_desc_authors handles author with cre role", {
  desc <- desc::description$new(
    text = sprintf(
      "Package: x\nAuthors@R: c(person(\"Alice\", \"Smith\", role = c(\"aut\", \"cre\")))\n"
    )
  )
  result <- rpkgkit:::vendor_desc_authors(desc)
  expect_equal(result$author_str, "Alice Smith")
})

test_that("vendor_desc_authors skips author with neither given nor family", {
  desc <- desc::description$new(
    text = sprintf(
      "Package: x\nAuthors@R: c(person(role = \"aut\"))\n"
    )
  )
  result <- rpkgkit:::vendor_desc_authors(desc)
  # No given or family → empty string gets trimmed to ""
  expect_equal(result$author_str, "")
})

test_that("vendor_desc_authors returns author_field and author_names components", {
  desc <- desc::description$new(
    text = sprintf(
      "Package: x\nAuthors@R: c(person(\"Alice\", \"Smith\", role = \"aut\"))\n"
    )
  )
  result <- rpkgkit:::vendor_desc_authors(desc)
  expect_named(result, c("author_field", "author_names", "author_str"))
  expect_type(result$author_field, "list")
  expect_type(result$author_names, "character")
})

# ---------------------------------------------------------------------------
# vendor_download_file()
# ---------------------------------------------------------------------------

test_that("vendor_download_file returns lines on success", {
  local_mocked_bindings(
    request = function(url) list(url = url),
    req_perform = function(req) list(req = req),
    resp_body_string = function(resp) "line1\nline2\nline3",
    .package = "httr2"
  )

  result <- rpkgkit:::vendor_download_file(
    owner = "wurli",
    repo = "pedant",
    branch = "main",
    path = "R/utils.R"
  )
  expect_equal(result, c("line1", "line2", "line3"))
})

test_that("vendor_download_file warns on HTTP error", {
  local_mocked_bindings(
    request = function(url) list(url = url),
    req_perform = function(req) stop("HTTP 404"),
    .package = "httr2"
  )

  # Warnings inside tryCatch error handlers need expect_error to propagate
  expect_warning(
    expect_error(
      rpkgkit:::vendor_download_file(
        owner = "wurli",
        repo = "pedant",
        branch = "main",
        path = "R/missing.R"
      )
    ),
    "HTTP 404"
  )
})

test_that("vendor_download_file error returns NULL which triggers error downstream", {
  local_mocked_bindings(
    request = function(url) list(url = url),
    req_perform = function(req) stop("HTTP 500"),
    .package = "httr2"
  )

  expect_warning(
    expect_error(
      rpkgkit:::vendor_download_file(
        owner = "wurli",
        repo = "pedant",
        branch = "main",
        path = "R/bad.R"
      )
    ),
    "HTTP 500"
  )
})

# ---------------------------------------------------------------------------
# vendor_declare_source_license()
# ---------------------------------------------------------------------------

test_that("vendor_declare_source_license creates vendor directory and README", {
  tmp <- withr::local_tempdir()
  dir.create(file.path(tmp, "inst"), recursive = TRUE)

  local_mocked_bindings(
    request = function(url) list(url = url, .called = TRUE),
    req_error = function(req, ...) req,
    req_perform = function(req) list(status = 200L, req = req),
    resp_status = function(resp) 200L,
    resp_body_string = function(resp) "MIT license text",
    .package = "httr2"
  )

  suppressMessages(
    rpkgkit:::vendor_declare_source_license(
      path = tmp,
      owner = "wurli",
      repo = "pedant",
      branch = "main",
      repo_url = "https://github.com/wurli/pedant"
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
    request = function(url) list(url = url),
    req_error = function(req, ...) req,
    req_perform = function(req) stop("HTTP 404"),
    resp_status = function(resp) 404L,
    .package = "httr2"
  )

  suppressMessages(
    expect_warning(
      rpkgkit:::vendor_declare_source_license(
        path = tmp,
        owner = "wurli",
        repo = "pedant",
        branch = "main",
        repo_url = "https://github.com/wurli/pedant"
      ),
      "No LICENSE files found"
    )
  )
})

# ---------------------------------------------------------------------------
# .vendor_extract_imports()
# ---------------------------------------------------------------------------

test_that(".vendor_extract_imports returns empty for empty input", {
  expect_identical(
    rpkgkit:::.vendor_extract_imports(character(0L)),
    character(0L)
  )
})

test_that(".vendor_extract_imports extracts @import tags", {
  lines <- c(
    "#' @import cli",
    "#' @importFrom rlang abort",
    "fun <- function(x) x"
  )
  pkgs <- rpkgkit:::.vendor_extract_imports(lines)
  expect_in("cli", pkgs)
  expect_in("rlang", pkgs)
})

test_that(".vendor_extract_imports splits multi-package @import lines", {
  lines <- c(
    "#' @import methods stats",
    "#' @import cli"
  )
  pkgs <- rpkgkit:::.vendor_extract_imports(lines)
  expect_in("methods", pkgs)
  expect_in("stats", pkgs)
  expect_in("cli", pkgs)
})

test_that(".vendor_extract_imports extracts pkg:: calls from code", {
  lines <- c(
    "usethis::use_git_ignore('.Rproj.user')",
    "devtools::as.package(pkg)$package"
  )
  pkgs <- rpkgkit:::.vendor_extract_imports(lines)
  expect_in("usethis", pkgs)
  expect_in("devtools", pkgs)
})

test_that(".vendor_extract_imports extracts both roxygen and :: patterns", {
  lines <- c(
    "#' @importFrom glue glue",
    "cli::cli_abort('nope')",
    "rlang::check_installed('httr2')"
  )
  pkgs <- rpkgkit:::.vendor_extract_imports(lines)
  expect_in("glue", pkgs)
  expect_in("cli", pkgs)
  expect_in("rlang", pkgs)
})

test_that(".vendor_extract_imports filters out base", {
  lines <- c("base::identity(x)", "cli::cli_inform('ok')")
  pkgs <- rpkgkit:::.vendor_extract_imports(lines)
  expect_false("base" %in% pkgs)
  expect_in("cli", pkgs)
})

test_that(".vendor_extract_imports ignores roxygen comments for :: extraction", {
  lines <- c(
    "#' @seealso [usethis::use_git_ignore()]",
    "usethis::use_build_ignore('foo')"
  )
  pkgs <- rpkgkit:::.vendor_extract_imports(lines)
  # "usethis" should only appear once (from code line, not roxygen)
  expect_in("usethis", pkgs)
  expect_length(pkgs, 1L)
})

test_that(".vendor_extract_imports returns sorted unique packages", {
  lines <- c(
    "cli::cli_abort('x')",
    "rlang::abort('y')",
    "cli::cli_inform('z')"
  )
  pkgs <- rpkgkit:::.vendor_extract_imports(lines)
  expect_equal(pkgs, c("cli", "rlang"))
})

test_that(".vendor_extract_imports handles @import with dot in package name", {
  lines <- c("#' @import data.table")
  pkgs <- rpkgkit:::.vendor_extract_imports(lines)
  expect_in("data.table", pkgs)
})

test_that(".vendor_extract_imports does not extract :: inside string literals", {
  lines <- c("msg <- 'use_package(\"pkg\")'", "cli::cli_inform(msg)")
  pkgs <- rpkgkit:::.vendor_extract_imports(lines)
  # The string literal "pkg::" should not be extracted; only cli:: should match
  expect_setequal(pkgs, "cli")
})

# ---------------------------------------------------------------------------
# vendor_create_r_file()
# ---------------------------------------------------------------------------

test_that("vendor_create_r_file creates header with attribution and metadata", {
  tmp <- withr::local_tempdir()
  dir.create(file.path(tmp, "R"))

  desc_vendor <- desc::description$new(
    text = "Package: pedant\nVersion: 0.3.1\n"
  )

  rpkgkit:::vendor_create_r_file(
    path = tmp,
    repo = "pedant",
    repo_url = "https://github.com/wurli/pedant",
    author_str = "Jacob Scott",
    license = "MIT",
    owner = "wurli",
    branch = "main",
    dots = list(),
    desc_vendor = desc_vendor
  )

  r_path <- file.path(tmp, "R", "vendor-pedant.R")
  expect_true(file.exists(r_path))

  lines <- readLines(r_path, warn = FALSE)

  # Existing attribution fields
  expect_match(lines[2L], "pedant", fixed = TRUE)
  expect_match(lines[3L], "https://github.com/wurli/pedant", fixed = TRUE)
  expect_match(lines[4L], "Jacob Scott", fixed = TRUE)
  expect_match(lines[5L], "MIT", fixed = TRUE)

  # New metadata fields
  expect_match(lines[7L], "Last-updated: ", fixed = TRUE)
  expect_match(lines[8L], "Vendor version: 0.3.1", fixed = TRUE)
  expect_match(lines[9L], "Imports: [none]", fixed = TRUE)

  expect_true(any(grepl("nocov start", lines)))
  expect_true(any(grepl("nocov end", lines)))
})

test_that("vendor_create_r_file appends downloaded file content and extracts imports", {
  tmp <- withr::local_tempdir()
  dir.create(file.path(tmp, "R"))

  local_mocked_bindings(
    vendor_download_file = function(...) {
      c(
        "fun1 <- function(x) x",
        "cli::cli_inform('hello')",
        "fun2 <- function(x) x + 1"
      )
    }
  )

  desc_vendor <- desc::description$new(
    text = "Package: pedant\nVersion: 0.3.1\n"
  )

  rpkgkit:::vendor_create_r_file(
    path = tmp,
    repo = "pedant",
    repo_url = "https://github.com/wurli/pedant",
    author_str = "Jacob Scott",
    license = "MIT",
    owner = "wurli",
    branch = "main",
    dots = list("R/utils.R"),
    desc_vendor = desc_vendor
  )

  lines <- readLines(file.path(tmp, "R", "vendor-pedant.R"), warn = FALSE)
  expect_match(lines, "fun1 <- function", fixed = TRUE, all = FALSE)
  expect_match(lines, "fun2 <- function", fixed = TRUE, all = FALSE)
  expect_match(lines, "File: R/utils\\.R", all = FALSE)
  expect_match(lines, "Vendor version: 0.3.1", fixed = TRUE, all = FALSE)
  expect_match(lines, "Imports: [cli]", fixed = TRUE, all = FALSE)
})

test_that("vendor_create_r_file handles empty dots with only header and nocov markers", {
  tmp <- withr::local_tempdir()
  dir.create(file.path(tmp, "R"))

  rpkgkit:::vendor_create_r_file(
    path = tmp,
    repo = "pedant",
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

test_that("vendor_create_r_file falls back to 'unknown' when no desc_vendor given", {
  tmp <- withr::local_tempdir()
  dir.create(file.path(tmp, "R"))

  rpkgkit:::vendor_create_r_file(
    path = tmp,
    repo = "pedant",
    repo_url = "https://github.com/wurli/pedant",
    author_str = "Jacob Scott",
    license = "MIT",
    owner = "wurli",
    branch = "main",
    dots = list()
  )

  lines <- readLines(file.path(tmp, "R", "vendor-pedant.R"), warn = FALSE)
  expect_match(lines[8L], "Vendor version: unknown", fixed = TRUE)
})

# ---------------------------------------------------------------------------
# vendor_update_desc()
# ---------------------------------------------------------------------------

test_that("vendor_update_desc adds authors to DESCRIPTION", {
  tmp <- withr::local_tempdir()
  writeLines(
    c(
      "Package: mypkg",
      "Title: My Package",
      "Version: 1.0.0",
      "Authors@R: c(person(given = \"Original\", family = \"Author\", role = c(\"aut\", \"cre\")))"
    ),
    file.path(tmp, "DESCRIPTION")
  )

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
  expect_true(any(vapply(
    authors,
    function(p) {
      "aut" %in%
        (p$role %||% character(0L)) &&
        "cph" %in% (p$role %||% character(0L)) &&
        grepl("pedant", p$comment %||% "", fixed = TRUE)
    },
    logical(1L)
  )))
})

test_that("vendor_update_desc assigns ctb (not aut) for non-cre/non-aut vendors", {
  tmp <- withr::local_tempdir()
  writeLines(
    c(
      "Package: mypkg",
      "Title: My Package",
      "Version: 1.0.0",
      "Authors@R: c(person(given = \"Original\", family = \"Author\", role = c(\"aut\", \"cre\")))"
    ),
    file.path(tmp, "DESCRIPTION")
  )

  # Vendor author with only "ctb" role
  author_info <- rpkgkit:::vendor_desc_authors(
    desc::description$new(
      text = "Package: x\nAuthors@R: c(person(\"Bob\", \"Jones\", role = \"ctb\"))\n"
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
  # New author should have ctb and cph, not aut
  new_authors <- Filter(
    function(p) {
      grepl("pedant", p$comment %||% "", fixed = TRUE)
    },
    authors
  )
  expect_true(all(vapply(
    new_authors,
    function(p) {
      "ctb" %in% (p$role %||% character(0L))
    },
    logical(1L)
  )))
  expect_false(any(vapply(
    new_authors,
    function(p) {
      "aut" %in% (p$role %||% character(0L))
    },
    logical(1L)
  )))
})

test_that("vendor_update_desc skips already-present authors", {
  tmp <- withr::local_tempdir()
  writeLines(
    c(
      "Package: mypkg",
      "Title: My Package",
      "Version: 1.0.0",
      "Authors@R: c(person(given = \"Original\", family = \"Author\", role = c(\"aut\", \"cre\")))"
    ),
    file.path(tmp, "DESCRIPTION")
  )

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
  writeLines(
    c(
      "Package: mypkg",
      "Title: My Package",
      "Version: 1.0.0",
      "Authors@R: c(person(given = \"Original\", family = \"Author\", role = c(\"aut\", \"cre\")))"
    ),
    file.path(tmp, "DESCRIPTION")
  )

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
  writeLines(
    c(
      "Package: mypkg",
      "Title: My Package",
      "Version: 1.0.0",
      "Authors@R: c(person(given = \"Original\", family = \"Author\", role = c(\"aut\", \"cre\")))",
      "Copyright: Original author"
    ),
    file.path(tmp, "DESCRIPTION")
  )

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
