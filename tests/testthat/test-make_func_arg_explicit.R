# ---------------------------------------------------------------------------
# .mfae_capture_inline_comments -- unit tests
# ---------------------------------------------------------------------------

test_that("capture_inline_comments extracts trailing inline comment", {
  lines <- c("x <- 1  # a comment", "y <- 2")
  res <- .mfae_capture_inline_comments(lines)
  expect_length(res, 1)
  expect_equal(res[["1"]], "# a comment")
})

test_that("capture_inline_comments ignores full-line comments", {
  lines <- c("# full line comment", "x <- 1")
  res <- .mfae_capture_inline_comments(lines)
  expect_length(res, 0)
})

test_that("capture_inline_comments returns empty for comment-free lines", {
  lines <- c("x <- 1", "y <- 2")
  res <- .mfae_capture_inline_comments(lines)
  expect_length(res, 0)
})

test_that("capture_inline_comments captures only lines with code before hash", {
  lines <- c("  # indented comment", "z <- 3  # inline")
  res <- .mfae_capture_inline_comments(lines)
  expect_length(res, 1)
  expect_equal(res[["2"]], "# inline")
})

# ---------------------------------------------------------------------------
# .mfae_walk_expr -- unit tests
# ---------------------------------------------------------------------------

test_that("mfae_walk_expr returns expression of walked children", {
  expr <- parse(text = "mean(1:10)")
  res <- .mfae_walk_expr(expr)
  expect_type(res, "expression")
  expect_length(res, 1)
})

test_that("mfae_walk_expr passes non-expression to .mfae_walk", {
  cl <- quote(mean(1:10))
  res <- .mfae_walk_expr(cl)
  expect_true(is.call(res))
})

# ---------------------------------------------------------------------------
# .mfae_walk -- unit tests
# ---------------------------------------------------------------------------

test_that("mfae_walk returns symbols as-is", {
  res <- .mfae_walk(quote(x))
  expect_equal(res, quote(x))
})

test_that("mfae_walk returns atomic values as-is", {
  res <- .mfae_walk(42L)
  expect_equal(res, 42L)
  res <- .mfae_walk("hello")
  expect_equal(res, "hello")
})

test_that("mfae_walk returns pairlist as-is", {
  res <- .mfae_walk(pairlist(a = 1, b = 2))
  expect_equal(res, pairlist(a = 1, b = 2))
})

test_that("mfae_walk does not transform operator +", {
  expr <- quote(a + b)
  res <- .mfae_walk(expr)
  expect_equal(res, expr)
})

test_that("mfae_walk does not transform $ operator", {
  expr <- quote(x$y)
  res <- .mfae_walk(expr)
  expect_equal(res, expr)
})

test_that("mfae_walk does not transform subset [", {
  expr <- quote(x[1])
  res <- .mfae_walk(expr)
  expect_equal(res, expr)
})

test_that("mfae_walk does not transform if", {
  expr <- quote(if (x) y else z)
  res <- .mfae_walk(expr)
  expect_equal(res, expr)
})

test_that("mfae_walk does not transform for loop", {
  expr <- quote(
    for (i in 1:10) {
      print(i)
    }
  )
  res <- .mfae_walk(expr)
  expect_equal(res[[1L]], quote(`for`))
})

test_that("mfae_walk does not transform infix operators", {
  expr <- quote(a %in% b)
  res <- .mfae_walk(expr)
  expect_equal(res, expr)
})

test_that("mfae_walk transforms a normal call", {
  expr <- quote(mean(1:10))
  res <- .mfae_walk(expr)
  expect_equal(res, quote(mean(x = 1:10)))
})

test_that("mfae_walk respects skip_functions", {
  expr <- quote(mean(1:10))
  res <- .mfae_walk(expr, skip_fns = "mean")
  expect_equal(res, expr)
})

test_that("mfae_walk transforms nested calls", {
  expr <- quote(vapply(1:9, function(x) x * 2, numeric(1)))
  res <- .mfae_walk(expr)
  # vapply formals: X, FUN, FUN.VALUE, ..., USE.NAMES
  # numeric(1) formals: length = 1
  expect_equal(
    res,
    quote(vapply(
      X = 1:9,
      FUN = function(x) x * 2,
      FUN.VALUE = numeric(length = 1)
    ))
  )
})

# ---------------------------------------------------------------------------
# .mfae_operators -- constant verification
# ---------------------------------------------------------------------------

test_that("mfae_operators contains core operators (not control flow)", {
  expect_true("+" %in% .mfae_operators)
  expect_true("[" %in% .mfae_operators)
  expect_true("$" %in% .mfae_operators)
  expect_true("<-" %in% .mfae_operators)
  expect_true("::" %in% .mfae_operators)
  # Control flow constructs are NOT in .mfae_operators — they have dedicated handlers
  expect_false("if" %in% .mfae_operators)
  expect_false("for" %in% .mfae_operators)
  expect_false("while" %in% .mfae_operators)
  expect_false("repeat" %in% .mfae_operators)
  expect_false("function" %in% .mfae_operators)
  expect_false("{" %in% .mfae_operators)
  expect_false("(" %in% .mfae_operators)
})

# ---------------------------------------------------------------------------
# .mfae_resolve_function -- unit tests
# ---------------------------------------------------------------------------

test_that("mfae_resolve_function resolves base::mean", {
  fn <- .mfae_resolve_function(quote(base::mean))
  expect_false(is.null(fn))
  expect_true(is.function(fn))
})

test_that("mfae_resolve_function returns NULL for unknown namespace", {
  fn <- .mfae_resolve_function(call("::", quote(unknown_pkg_xyz), quote(fun)))
  expect_null(fn)
})

test_that("mfae_resolve_function returns NULL for unknown function", {
  fn <- .mfae_resolve_function(call(
    ":::",
    quote(base),
    quote(nonexistent_fun_xyz)
  ))
  expect_null(fn)
})

test_that("mfae_resolve_function resolves simple symbol from base", {
  fn <- .mfae_resolve_function(quote(mean))
  expect_false(is.null(fn))
  expect_true(is.function(fn))
})

test_that("mfae_resolve_function returns NULL for unknown symbol", {
  fn <- .mfae_resolve_function(quote(does_not_exist_xyzzy))
  expect_null(fn)
})

test_that("mfae_resolve_function returns NULL for complex non-symbol call", {
  fn <- .mfae_resolve_function(quote(foo(bar)))
  expect_null(fn)
})

# ---------------------------------------------------------------------------
# .mfae_match_args -- unit tests
# ---------------------------------------------------------------------------

test_that("mfae_match_args converts positional args to named", {
  expr <- quote(seq(1, 10))
  fmls <- formals(seq.default)
  res <- .mfae_match_args(expr, fmls)
  expect_equal(res[[2L]], 1)
  expect_equal(names(res)[2L], "from")
  expect_equal(res[[3L]], 10)
  expect_equal(names(res)[3L], "to")
})

test_that("mfae_match_args preserves order of explicitly named args", {
  expr <- quote(seq(to = 10, from = 1))
  fmls <- formals(seq.default)
  res <- .mfae_match_args(expr, fmls)
  # Original order in the call is: to, from
  expect_equal(res[[2L]], 10)
  expect_equal(names(res)[2L], "to")
  expect_equal(res[[3L]], 1)
  expect_equal(names(res)[3L], "from")
})

test_that("mfae_match_args handles dots - unmatched args unnamed", {
  expr <- quote(c(1, 2, 3))
  fmls <- formals(c)
  res <- .mfae_match_args(expr, fmls)
  # c() only has dots, so all args remain unnamed → names are dropped (NULL)
  expect_null(names(res))
})

test_that("mfae_match_args handles primitive without dots", {
  expr <- quote(`+`(1, 2))
  fmls <- pairlist(e1 = NULL, e2 = NULL)
  res <- .mfae_match_args(expr, fmls)
  expect_equal(names(res), c("", "e1", "e2"))
})

test_that("mfae_match_args does not name positional args when dots exist", {
  # any() has formals (..., na.rm = FALSE)
  # any(is.na(df)) — is.na(df) is a ... arg, NOT na.rm
  expr <- quote(any(is.na(df)))
  fmls <- formals(any)
  res <- .mfae_match_args(expr, fmls)
  # Positional arg is.na(df) must NOT be named "na.rm"
  nm <- names(res) # NULL when all names are empty (correct)
  expect_false(isTRUE(nm[2L] == "na.rm"))
})

test_that("mfae_match_args names non-dots only when there are no dots", {
  # `+` has formals (e1, e2) — no dots, so positional args get named
  expr <- quote(`+`(1, 2))
  fmls <- pairlist(e1 = NULL, e2 = NULL)
  res <- .mfae_match_args(expr, fmls)
  expect_equal(names(res), c("", "e1", "e2"))
})

# ---------------------------------------------------------------------------
# make_func_arg_explicit -- integration tests with temp files
# ---------------------------------------------------------------------------

test_that("make_func_arg_explicit resolves path from rstudioapi when NULL", {
  local_mocked_bindings(
    getActiveDocumentContext = function() list(path = "/mock/file.R"),
    .package = "rstudioapi"
  )
  local_mocked_bindings(
    readLines = function(con, ...) {
      expect_equal(con, "/mock/file.R")
      character(0)
    },
    .package = "base"
  )
  local_mocked_bindings(
    writeLines = function(text, con) {
      expect_equal(con, "/mock/file.R")
    },
    .package = "base"
  )
  expect_invisible(make_func_arg_explicit())
})

test_that("basic transformation: vapply", {
  tf <- withr::local_tempfile(fileext = ".R")
  writeLines("vapply(1:9, function(x) x*2, numeric(1))", tf)
  make_func_arg_explicit(tf)
  result <- readLines(tf, warn = FALSE)
  expected <- "vapply(X = 1:9, FUN = function(x) x * 2, FUN.VALUE = numeric(length = 1))"
  expect_match(result, expected, fixed = TRUE)
})

test_that("basic transformation: mean with two args", {
  tf <- withr::local_tempfile(fileext = ".R")
  writeLines("mean(1:10, TRUE)", tf)
  make_func_arg_explicit(tf)
  result <- readLines(tf, warn = FALSE)
  # mean is an S3 generic with formals (x, ...) — TRUE matches ...
  expect_match(result, "mean(x = 1:10, TRUE)", fixed = TRUE)
})

test_that("already explicit call leaves file unchanged", {
  tf <- withr::local_tempfile(fileext = ".R")
  input <- "mean(x = 1:10)"
  writeLines(input, tf)
  make_func_arg_explicit(tf)
  expect_equal(readLines(tf, warn = FALSE), input)
})

test_that("empty file produces info message", {
  tf <- withr::local_tempfile(fileext = ".R")
  writeLines(character(0), tf)
  expect_message(make_func_arg_explicit(tf), "No R expressions found")
})

test_that("operators are not transformed", {
  tf <- withr::local_tempfile(fileext = ".R")
  input_lines <- c(
    "x + y",
    "a - b",
    "x$y",
    "lst[1]",
    "lst[[i]]",
    "x %% y"
  )
  writeLines(input_lines, tf)
  make_func_arg_explicit(tf)
  expect_equal(readLines(tf, warn = FALSE), input_lines)
})

test_that("infix operators like %>% are not transformed", {
  tf <- withr::local_tempfile(fileext = ".R")
  input <- "x %>% filter(y > 1)"
  writeLines(input, tf)
  make_func_arg_explicit(tf)
  result <- readLines(tf, warn = FALSE)
  # %>% is not transformed, but filter(y > 1) IS transformed because
  # stats::filter is available (x -> filter(x = y > 1))
  expect_true(grepl("x %>%", result, fixed = TRUE))
  expect_true(grepl("filter\\(x = y > 1\\)", result))
})

test_that("if/for/while constructs are not transformed", {
  tf <- withr::local_tempfile(fileext = ".R")
  # if/for/while themselves are not transformed, but inner calls like
  # print(i) ARE transformed because print has formals (x, ...)
  input_lines <- c(
    "if (x > 1) y else z",
    "for (i in 1:10) print(i)",
    "while (TRUE) break"
  )
  expected_lines <- c(
    "if (x > 1) y else z",
    "for (i in 1:10) print(x = i)",
    "while (TRUE) break"
  )
  writeLines(input_lines, tf)
  make_func_arg_explicit(tf)
  expect_equal(readLines(tf, warn = FALSE), expected_lines)
})

test_that("complex if condition with primitive dots is handled correctly", {
  tf <- withr::local_tempfile(fileext = ".R")
  # any(is.na(df)) — is.na(df) is a ... arg, must NOT get name "na.rm"
  input_lines <- c(
    "if (any(is.na(df))) {",
    "  mean(x, TRUE)",
    "}"
  )
  writeLines(input_lines, tf)
  make_func_arg_explicit(tf)
  result <- readLines(tf, warn = FALSE)
  # The condition any(is.na(df)) should keep is.na(df) unnamed (goes to ...)
  expect_true(grepl("any\\(is\\.na\\(df\\)\\)", result[[1L]]))
  # The body mean(x, TRUE) should be transformed (mean has ...)
  expect_true(grepl("mean\\(x = x, TRUE\\)", result[[2L]]))
})

test_that("skip_functions parameter prevents transformation", {
  tf <- withr::local_tempfile(fileext = ".R")
  input <- "mean(1:10, TRUE)"
  writeLines(input, tf)
  make_func_arg_explicit(tf, skip_functions = "mean")
  expect_equal(readLines(tf, warn = FALSE), input)
})

test_that("inline comments on transformed line are preserved", {
  tf <- withr::local_tempfile(fileext = ".R")
  writeLines("mean(1:10, TRUE)  # my comment", tf)
  make_func_arg_explicit(tf)
  result <- readLines(tf, warn = FALSE)
  expect_match(result, "# my comment", fixed = TRUE)
  expect_match(result, "mean(x = 1:10, TRUE)", fixed = TRUE)
})

test_that("non-expression content (roxygen docs) is preserved", {
  tf <- withr::local_tempfile(fileext = ".R")
  input_lines <- c(
    "#' My function",
    "#' @param x a vector",
    "my_fun <- function(x) {",
    "  mean(x, TRUE)",
    "}"
  )
  writeLines(input_lines, tf)
  make_func_arg_explicit(tf)
  result <- readLines(tf, warn = FALSE)
  expect_true(any(grepl("#' My function", result, fixed = TRUE)))
  expect_true(any(grepl("mean\\(x = x, TRUE\\)", result)))
})

test_that("returns invisibly", {
  tf <- withr::local_tempfile(fileext = ".R")
  writeLines("mean(1:10)", tf)
  expect_invisible(make_func_arg_explicit(tf))
})

# ---------------------------------------------------------------------------
# package_func_arg_explicit -- integration tests
# ---------------------------------------------------------------------------

test_that("package_func_arg_explicit aborts when path is not a package", {
  expect_error(
    package_func_arg_explicit(tempdir()),
    "is not an R package"
  )
})

test_that("package_func_arg_explicit aborts when no R/ directory", {
  pkg <- withr::local_tempdir()
  writeLines(
    c("Package: testpkg", "Version: 0.0.1"),
    file.path(pkg, "DESCRIPTION")
  )
  expect_error(
    package_func_arg_explicit(pkg),
    "No .*R/.* directory found"
  )
})

test_that("package_func_arg_explicit shows info when R/ is empty", {
  pkg <- withr::local_tempdir()
  dir.create(file.path(pkg, "R"), recursive = TRUE)
  writeLines(
    c("Package: testpkg", "Version: 0.0.1"),
    file.path(pkg, "DESCRIPTION")
  )
  expect_message(
    package_func_arg_explicit(pkg),
    "No.*\\.R.*files found"
  )
})

test_that("package_func_arg_explicit processes R files with transformation", {
  pkg <- withr::local_tempdir()
  dir.create(file.path(pkg, "R"), recursive = TRUE)
  writeLines("mean(1:10)", file.path(pkg, "R", "foo.R"))
  writeLines(
    c("Package: testpkg", "Version: 0.0.1"),
    file.path(pkg, "DESCRIPTION")
  )
  expect_message(
    package_func_arg_explicit(pkg),
    "Successfully processed.*1 file"
  )
  expect_match(
    readLines(file.path(pkg, "R", "foo.R"), warn = FALSE),
    "mean\\(x = 1:10\\)"
  )
})

test_that("package_func_arg_explicit handles multiple files", {
  pkg <- withr::local_tempdir()
  dir.create(file.path(pkg, "R"), recursive = TRUE)
  writeLines("mean(1:10)", file.path(pkg, "R", "foo.R"))
  writeLines("sum(1:5)", file.path(pkg, "R", "bar.R"))
  writeLines(
    c("Package: testpkg", "Version: 0.0.1"),
    file.path(pkg, "DESCRIPTION")
  )
  expect_message(
    package_func_arg_explicit(pkg),
    "Successfully processed.*2 files"
  )
})

test_that("package_func_arg_explicit returns invisibly", {
  pkg <- withr::local_tempdir()
  dir.create(file.path(pkg, "R"), recursive = TRUE)
  writeLines("mean(1:10)", file.path(pkg, "R", "foo.R"))
  writeLines(
    c("Package: testpkg", "Version: 0.0.1"),
    file.path(pkg, "DESCRIPTION")
  )
  expect_invisible(package_func_arg_explicit(pkg))
})
