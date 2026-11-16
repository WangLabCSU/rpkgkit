# ---------------------------------------------------------------------------
# use_tidy_addin() and its internal helpers
# ---------------------------------------------------------------------------

# Build a minimal package that defines `fn` in R/fn.R and (optionally) exports
# it from NAMESPACE.
local_addin_pkg <- function(
  fn = "my_addin",
  body = "rstudioapi::getActiveDocumentContext()",
  namespace = NULL,
  write_namespace = TRUE,
  env = parent.frame()
) {
  pkg <- withr::local_tempdir(.local_envir = env)
  writeLines(
    c("Package: testpkg", "Version: 0.0.1"),
    file.path(pkg, "DESCRIPTION")
  )
  if (write_namespace) {
    if (is.null(namespace)) {
      namespace <- paste0("export(", fn, ")")
    }
    writeLines(namespace, file.path(pkg, "NAMESPACE"))
  }
  dir.create(file.path(pkg, "R"))
  writeLines(
    c(paste0(fn, " <- function(...) {"), paste0("  ", body), "}"),
    file.path(pkg, "R", "fn.R")
  )
  pkg
}

# `use_tidy_addin()` returns a path built on `normalizePath(path)`, which
# resolves symlinks on macOS (`/var` -> `/private/var`) and expands 8.3 short
# names on Windows (`RUNNER~1` -> `runneradmin`). Normalize both sides before
# comparing so the tests are portable.
norm_path <- function(path) {
  normalizePath(path, winslash = "/", mustWork = FALSE)
}

test_that("use_tidy_addin writes the addin registration", {
  skip_if_not_installed("desc")
  pkg <- local_addin_pkg()

  expect_message(
    use_tidy_addin("my_addin", "Open my gadget", path = pkg),
    "Wrote addin"
  )

  dcf <- file.path(pkg, "inst", "rstudio", "addins.dcf")
  expect_true(file.exists(dcf))
  expect_equal(
    readLines(dcf, warn = FALSE),
    c(
      "Name: my_addin",
      "Description: Open my gadget",
      "Binding: my_addin",
      "Interactive: false"
    )
  )
})

test_that("use_tidy_addin returns the dcf path invisibly", {
  skip_if_not_installed("desc")
  pkg <- local_addin_pkg()

  expect_invisible(
    suppressMessages(use_tidy_addin("my_addin", "gadget", path = pkg))
  )
  expect_equal(
    norm_path(suppressMessages(use_tidy_addin(
      "my_addin",
      "gadget",
      path = pkg
    ))),
    norm_path(file.path(pkg, "inst", "rstudio", "addins.dcf"))
  )
})

test_that("use_tidy_addin collapses newlines in the description", {
  skip_if_not_installed("desc")
  pkg <- local_addin_pkg()

  suppressMessages(
    use_tidy_addin("my_addin", "line one\n   line two", path = pkg)
  )

  lines <- readLines(file.path(pkg, "inst", "rstudio", "addins.dcf"))
  expect_equal(lines[2L], "Description: line one line two")
})

test_that("use_tidy_addin puts a new entry above existing ones", {
  skip_if_not_installed("desc")
  pkg <- local_addin_pkg()
  dcf <- file.path(pkg, "inst", "rstudio", "addins.dcf")
  dir.create(dirname(dcf), recursive = TRUE)
  writeLines(
    c(
      "Name: old_addin",
      "Description: Old",
      "Binding: old_addin",
      "Interactive: false"
    ),
    dcf
  )

  suppressMessages(use_tidy_addin("my_addin", "New", path = pkg))

  expect_equal(
    readLines(dcf, warn = FALSE),
    c(
      "Name: my_addin",
      "Description: New",
      "Binding: my_addin",
      "Interactive: false",
      "",
      "Name: old_addin",
      "Description: Old",
      "Binding: old_addin",
      "Interactive: false"
    )
  )
})

test_that("use_tidy_addin does not register the same addin twice", {
  skip_if_not_installed("desc")
  pkg <- local_addin_pkg()
  dcf <- file.path(pkg, "inst", "rstudio", "addins.dcf")
  dir.create(dirname(dcf), recursive = TRUE)
  writeLines(c("Name: my_addin", "Binding: my_addin"), dcf)

  expect_message(
    expect_equal(
      norm_path(use_tidy_addin("my_addin", "again", path = pkg)),
      norm_path(dcf)
    ),
    "already registered"
  )
  expect_equal(
    readLines(dcf, warn = FALSE),
    c("Name: my_addin", "Binding: my_addin")
  )
})

test_that("use_tidy_addin records Interactive = TRUE", {
  skip_if_not_installed("desc")
  pkg <- local_addin_pkg(body = "shiny::runApp()")

  suppressMessages(
    use_tidy_addin("my_addin", "gadget", Interactive = TRUE, path = pkg)
  )

  lines <- readLines(file.path(pkg, "inst", "rstudio", "addins.dcf"))
  expect_true("Interactive: true" %in% lines)
})

test_that("use_tidy_addin warns and continues when no rstudioapi call is found", {
  skip_if_not_installed("desc")
  pkg <- local_addin_pkg(body = "invisible(NULL)")
  local_mocked_bindings(
    .uta_confirm = function(msg, .envir = parent.frame()) TRUE,
    .package = "rpkgkit"
  )

  suppressMessages(use_tidy_addin("my_addin", "gadget", path = pkg))

  expect_true(
    file.exists(file.path(pkg, "inst", "rstudio", "addins.dcf"))
  )
})

test_that("use_tidy_addin writes nothing when the prompt is declined", {
  skip_if_not_installed("desc")
  pkg <- local_addin_pkg(body = "invisible(NULL)")
  local_mocked_bindings(
    .uta_confirm = function(msg, .envir = parent.frame()) FALSE,
    .package = "rpkgkit"
  )

  expect_message(
    expect_null(use_tidy_addin("my_addin", "gadget", path = pkg)),
    "Cancelled"
  )
  expect_false(
    file.exists(file.path(pkg, "inst", "rstudio", "addins.dcf"))
  )
})

test_that("use_tidy_addin cancels an Interactive addin without shiny", {
  skip_if_not_installed("desc")
  pkg <- local_addin_pkg()
  local_mocked_bindings(
    .uta_confirm = function(msg, .envir = parent.frame()) FALSE,
    .package = "rpkgkit"
  )

  expect_null(
    suppressMessages(
      use_tidy_addin("my_addin", "gadget", Interactive = TRUE, path = pkg)
    )
  )
  expect_false(
    file.exists(file.path(pkg, "inst", "rstudio", "addins.dcf"))
  )
})

test_that("use_tidy_addin accepts an Interactive addin that uses miniUI", {
  skip_if_not_installed("desc")
  pkg <- local_addin_pkg(body = "miniUI::miniPage()")

  suppressMessages(
    use_tidy_addin("my_addin", "gadget", Interactive = TRUE, path = pkg)
  )

  lines <- readLines(file.path(pkg, "inst", "rstudio", "addins.dcf"))
  expect_true("Interactive: true" %in% lines)
})

test_that("use_tidy_addin falls back to scanning R/ when not installed", {
  skip_if_not_installed("desc")
  pkg <- local_addin_pkg()
  # Documented package: roxygen header in NAMESPACE plus a man page, while
  # `testpkg` itself is (obviously) not installed
  writeLines(
    c(
      "# Generated by roxygen2: do not edit by hand",
      "export(my_addin)"
    ),
    file.path(pkg, "NAMESPACE")
  )
  dir.create(file.path(pkg, "man"))
  writeLines("\\name{my_addin}", file.path(pkg, "man", "my_addin.Rd"))

  expect_true(rpkgkit:::.uta_is_documented(pkg))
  suppressMessages(use_tidy_addin("my_addin", "gadget", path = pkg))
  expect_true(file.exists(file.path(pkg, "inst", "rstudio", "addins.dcf")))
})

test_that("use_tidy_addin aborts when path is not an R package", {
  non_pkg <- withr::local_tempdir()

  expect_error(
    use_tidy_addin("my_addin", "gadget", path = non_pkg),
    "is not an R package"
  )
})

test_that("use_tidy_addin aborts when NAMESPACE is missing", {
  skip_if_not_installed("desc")
  pkg <- local_addin_pkg(write_namespace = FALSE)

  expect_error(use_tidy_addin("my_addin", "gadget", path = pkg), "Cannot find")
})

test_that("use_tidy_addin aborts when the function is not exported", {
  skip_if_not_installed("desc")
  pkg <- local_addin_pkg(namespace = "export(other_addin)")

  expect_error(
    use_tidy_addin("my_addin", "gadget", path = pkg),
    "not exported"
  )
})

test_that("use_tidy_addin aborts when no definition can be found", {
  skip_if_not_installed("desc")
  pkg <- local_addin_pkg(namespace = "export(my_addin)")
  writeLines("other <- function() NULL", file.path(pkg, "R", "fn.R"))

  expect_error(
    use_tidy_addin("my_addin", "gadget", path = pkg),
    "Cannot find a definition"
  )
})

test_that("use_tidy_addin validates its arguments", {
  skip_if_not_installed("desc")
  pkg <- local_addin_pkg()

  expect_error(use_tidy_addin(1, "gadget", path = pkg), class = "rlang_error")
  expect_error(use_tidy_addin("my_addin", 1, path = pkg), class = "rlang_error")
  expect_error(
    use_tidy_addin("my_addin", "gadget", Interactive = "yes", path = pkg),
    class = "rlang_error"
  )
})

# ------------------------------- helpers -----------------------------------

test_that(".uta_parse_namespace reads exports, patterns and imports", {
  ns_file <- withr::local_tempfile(
    lines = c(
      "export(a, b)",
      'exportPattern("^foo")',
      "import(cli)",
      "importFrom(rlang, check_string, abort)"
    )
  )

  ns <- rpkgkit:::.uta_parse_namespace(ns_file)

  expect_setequal(ns$exports, c("a", "b"))
  expect_equal(ns$export_patterns, "^foo")
  expect_equal(ns$imports_all, "cli")
  expect_equal(ns$imports_from$pkg, c("rlang", "rlang"))
  expect_setequal(ns$imports_from$sym, c("check_string", "abort"))
})

test_that(".uta_parse_namespace returns empty results for an empty NAMESPACE", {
  ns_file <- withr::local_tempfile(lines = character())

  ns <- rpkgkit:::.uta_parse_namespace(ns_file)

  expect_length(ns$exports, 0L)
  expect_length(ns$export_patterns, 0L)
  expect_length(ns$imports_all, 0L)
  expect_equal(nrow(ns$imports_from), 0L)
})

test_that(".uta_is_documented requires both a roxygen header and a man page", {
  pkg <- local_addin_pkg()
  expect_false(rpkgkit:::.uta_is_documented(pkg))

  writeLines(
    c("# Generated by roxygen2: do not edit by hand", "export(my_addin)"),
    file.path(pkg, "NAMESPACE")
  )
  expect_false(rpkgkit:::.uta_is_documented(pkg))

  dir.create(file.path(pkg, "man"))
  writeLines("\\name{my_addin}", file.path(pkg, "man", "my_addin.Rd"))
  expect_true(rpkgkit:::.uta_is_documented(pkg))
})

test_that(".uta_find_fn_body finds bodies assigned with <-, = and <<-", {
  pkg <- withr::local_tempdir()
  dir.create(file.path(pkg, "R"))
  writeLines(
    c(
      "f_arrow <- function(a) {",
      "  a + 1",
      "}",
      "f_equal = function(b) b * 2",
      "f_super <<- function() NULL"
    ),
    file.path(pkg, "R", "fns.R")
  )

  expect_identical(
    rpkgkit:::.uta_find_fn_body("f_arrow", pkg)[[1L]],
    as.name("{")
  )
  expect_identical(rpkgkit:::.uta_find_fn_body("f_equal", pkg), quote(b * 2))
  expect_null(rpkgkit:::.uta_find_fn_body("f_super", pkg))
  expect_null(rpkgkit:::.uta_find_fn_body("missing_fn", pkg))
})

test_that(".uta_find_fn_body skips files that cannot be parsed", {
  pkg <- withr::local_tempdir()
  dir.create(file.path(pkg, "R"))
  writeLines("this is ( not R", file.path(pkg, "R", "broken.R"))
  writeLines("ok_fn <- function() 1", file.path(pkg, "R", "ok.R"))

  expect_identical(rpkgkit:::.uta_find_fn_body("ok_fn", pkg), 1)
})

test_that(".uta_find_fn_body returns NULL when R/ is absent", {
  pkg <- withr::local_tempdir()
  expect_null(rpkgkit:::.uta_find_fn_body("anything", pkg))
})

test_that(".uta_uses_pkg detects pkg::, library() and imported symbols", {
  ns <- list(
    exports = character(),
    export_patterns = character(),
    imports_all = character(),
    imports_from = data.frame(
      pkg = "rstudioapi",
      sym = "getActiveDocumentContext"
    )
  )
  body <- quote({
    rstudioapi::getActiveDocumentContext()
  })
  expect_true(rpkgkit:::.uta_uses_pkg(body, "rstudioapi", ns))

  body <- quote(library(rstudioapi))
  expect_true(rpkgkit:::.uta_uses_pkg(body, "rstudioapi", ns))

  # Symbol reached through importFrom()
  body <- quote(getActiveDocumentContext())
  expect_true(rpkgkit:::.uta_uses_pkg(body, "rstudioapi", ns))

  body <- quote(invisible(NULL))
  expect_false(rpkgkit:::.uta_uses_pkg(body, "rstudioapi", ns))
})

test_that(".uta_uses_pkg checks the whole namespace for import()", {
  ns <- list(
    exports = character(),
    export_patterns = character(),
    imports_all = "cli",
    imports_from = data.frame(pkg = character(), sym = character())
  )

  expect_true(rpkgkit:::.uta_uses_pkg(quote(cli_alert_info("hi")), "cli", ns))
})

test_that(".uta_confirm continues in a non-interactive session", {
  local_mocked_bindings(
    is_interactive = function() FALSE,
    .package = "rlang"
  )

  messages <- character()
  result <- withCallingHandlers(
    rpkgkit:::.uta_confirm("Continue?"),
    message = function(m) {
      messages <<- c(messages, conditionMessage(m))
      invokeRestart("muffleMessage")
    }
  )

  expect_true(result)
  expect_match(paste(messages, collapse = " "), "Non-interactive session")
})

test_that(".uta_read_bindings returns the registered bindings", {
  dcf <- withr::local_tempfile(
    lines = c(
      "Name: a",
      "Binding: fn_a",
      "",
      "Name: b",
      "Binding: fn_b"
    )
  )

  expect_equal(rpkgkit:::.uta_read_bindings(dcf), c("fn_a", "fn_b"))
})

test_that(".uta_read_bindings returns character() for an unreadable file", {
  dcf <- withr::local_tempfile(lines = "this is not a dcf file at all")

  expect_equal(rpkgkit:::.uta_read_bindings(dcf), character())
})
