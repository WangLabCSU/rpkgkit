# ---------------------------------------------------------------------------
# package_fn_arg_path() -- package-wide wrapper around scan_fn_arg_path()
# ---------------------------------------------------------------------------

# Build a minimal package on disk. `files` maps package-relative paths to the
# lines written there, e.g. list("R/read.R" = 'read_it <- function(path="x")').
local_path_pkg <- function(
  files = list(),
  namespace = character(),
  env = parent.frame()
) {
  pkg <- withr::local_tempdir(.local_envir = env)
  writeLines(
    c("Package: testpkg", "Version: 0.0.1"),
    file.path(pkg, "DESCRIPTION")
  )
  writeLines(namespace, file.path(pkg, "NAMESPACE"))
  for (rel_path in names(files)) {
    target <- file.path(pkg, rel_path)
    dir.create(dirname(target), recursive = TRUE, showWarnings = FALSE)
    writeLines(files[[rel_path]], target)
  }
  pkg
}

test_that("package_fn_arg_path aborts when path is not a package", {
  # A dedicated directory: `tempdir()` may already contain a DESCRIPTION
  # written by another test
  non_pkg <- withr::local_tempdir()

  expect_error(package_fn_arg_path(non_pkg), "is not an R package")
})

test_that("package_fn_arg_path aborts when path is an empty string", {
  expect_error(package_fn_arg_path(""), "required")
})

test_that("package_fn_arg_path informs and returns TRUE with no exports", {
  pkg <- local_path_pkg(
    files = list("R/read.R" = 'read_it <- function(path = "~/x") NULL'),
    namespace = character()
  )

  expect_message(
    expect_true(package_fn_arg_path(pkg)),
    "No exported functions found"
  )
})

test_that("package_fn_arg_path informs and returns TRUE when no files match", {
  pkg <- local_path_pkg(
    files = list("src/read.R" = 'read_it <- function(path = "~/x") NULL'),
    namespace = "export(read_it)"
  )

  expect_message(
    expect_true(package_fn_arg_path(pkg)),
    "files found to scan"
  )
})

test_that("package_fn_arg_path returns TRUE for a clean package", {
  pkg <- local_path_pkg(
    files = list(
      "R/read.R" = 'read_it <- function(path = NULL, n = 1) NULL',
      "R/write.R" = 'write_it <- function(file, x) NULL'
    ),
    namespace = c("export(read_it)", "export(write_it)")
  )

  expect_message(
    expect_true(package_fn_arg_path(pkg, verbose = FALSE)),
    "No exported function has a default path"
  )
})

test_that("package_fn_arg_path detects a default path and returns FALSE", {
  pkg <- local_path_pkg(
    files = list("R/read.R" = 'read_it <- function(path = "~/x.csv") NULL'),
    namespace = "export(read_it)"
  )

  expect_message(
    expect_false(package_fn_arg_path(pkg, verbose = FALSE)),
    "Found 1 argument"
  )
})

test_that("package_fn_arg_path counts hits and offending files", {
  pkg <- local_path_pkg(
    files = list(
      "R/a.R" = c(
        'read_a <- function(path = "~/a") NULL',
        'read_b <- function(file = "~/b") NULL'
      ),
      "R/b.R" = 'read_c <- function(filename = "~/c") NULL',
      "R/clean.R" = 'read_d <- function(path = NULL) NULL'
    ),
    namespace = c(
      "export(read_a)",
      "export(read_b)",
      "export(read_c)",
      "export(read_d)"
    )
  )

  expect_message(
    expect_false(package_fn_arg_path(pkg, verbose = FALSE)),
    "Found 3 arguments with a default path in 2 of 3 files"
  )
})

test_that("package_fn_arg_path ignores functions that are not exported", {
  pkg <- local_path_pkg(
    files = list(
      "R/read.R" = c(
        'read_exported <- function(path = NULL) NULL',
        'read_internal <- function(path = "~/x") NULL'
      )
    ),
    namespace = "export(read_exported)"
  )

  expect_true(package_fn_arg_path(pkg, verbose = FALSE))
})

test_that("package_fn_arg_path resolves exports declared by exportPattern", {
  pkg <- local_path_pkg(
    files = list(
      "R/read.R" = c(
        'read_data <- function(path = "~/x") NULL',
        'internal_data <- function(path = "~/y") NULL'
      )
    ),
    namespace = 'exportPattern("^read_")'
  )

  expect_message(
    expect_false(package_fn_arg_path(pkg, verbose = FALSE)),
    "Found 1 argument"
  )
})

test_that("package_fn_arg_path honours a custom dirs argument", {
  pkg <- local_path_pkg(
    files = list(
      "R2/nested/read.R" = 'read_it <- function(path = "~/x") NULL'
    ),
    namespace = "export(read_it)"
  )

  expect_true(package_fn_arg_path(pkg, dirs = "R", verbose = FALSE))
  expect_false(package_fn_arg_path(pkg, dirs = "R2", verbose = FALSE))
})

test_that("package_fn_arg_path honours the allow list", {
  pkg <- local_path_pkg(
    files = list("R/read.R" = 'read_it <- function(path = ".") NULL'),
    namespace = "export(read_it)"
  )

  expect_false(package_fn_arg_path(pkg, verbose = FALSE))
  expect_true(package_fn_arg_path(
    pkg,
    allow = c("NULL", '"."'),
    verbose = FALSE
  ))
})

test_that("package_fn_arg_path honours a custom arg_pattern", {
  pkg <- local_path_pkg(
    files = list(
      "R/read.R" = 'read_it <- function(path = NULL) NULL',
      "R/save.R" = 'save_it <- function(out_dir = "~/y") NULL'
    ),
    namespace = c("export(read_it)", "export(save_it)")
  )

  # The default pattern does not cover `out_dir`
  expect_true(suppressMessages(package_fn_arg_path(pkg, verbose = FALSE)))
  expect_false(
    suppressMessages(
      package_fn_arg_path(pkg, arg_pattern = "out_dir", verbose = FALSE)
    )
  )
})

test_that("package_fn_arg_path only suppresses the per-hit report", {
  # `verbose` controls the detailed report; the closing summary is always shown
  pkg <- local_path_pkg(
    files = list("R/read.R" = 'read_it <- function(path = "~/x") NULL'),
    namespace = "export(read_it)"
  )

  expect_message(
    expect_false(package_fn_arg_path(pkg, verbose = FALSE)),
    "Found 1 argument"
  )
})

test_that("package_fn_arg_path returns invisibly", {
  pkg <- local_path_pkg(
    files = list("R/read.R" = 'read_it <- function(path = NULL) NULL'),
    namespace = "export(read_it)"
  )

  expect_invisible(suppressMessages(package_fn_arg_path(pkg, verbose = FALSE)))
})

test_that("package_fn_arg_path errors on non-empty dots", {
  pkg <- local_path_pkg(
    files = list("R/read.R" = 'read_it <- function(path = NULL) NULL'),
    namespace = "export(read_it)"
  )

  expect_error(package_fn_arg_path(pkg, unused = 1), class = "rlang_error")
})
