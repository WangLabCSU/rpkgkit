# ---------------------------------------------------------------------------
# .mfae_assign_arg_names -- unit tests
# ---------------------------------------------------------------------------

test_that("assign_arg_names fills positional args from the formals", {
  res <- .mfae_assign_arg_names(c("", ""), c("from", "to", "by", "..."))
  expect_equal(res, c("from", "to"))
})

test_that("assign_arg_names keeps explicitly named args in source order", {
  res <- .mfae_assign_arg_names(c("to", "from"), c("from", "to", "..."))
  expect_equal(res, c("to", "from"))
})

test_that("assign_arg_names skips formals already claimed by name", {
  # `to` is claimed by name, so the positional arg picks up `from`
  res <- .mfae_assign_arg_names(c("to", ""), c("from", "to"))
  expect_equal(res, c("to", "from"))
})

test_that("assign_arg_names leaves args for `...` unnamed when dots come first", {
  # any(..., na.rm) — positional args fall into `...`
  res <- .mfae_assign_arg_names(c(""), c("...", "na.rm"))
  expect_equal(res, "")
})

test_that("assign_arg_names stops at dots in the middle", {
  # f(a, ..., b): after `a`, positional args go to `...` and never reach `b`
  res <- .mfae_assign_arg_names(c("", "", ""), c("a", "...", "b"))
  expect_equal(res, c("a", "", ""))
})

test_that("assign_arg_names leaves args unnamed when there are only dots", {
  res <- .mfae_assign_arg_names(c("", "", ""), c("..."))
  expect_equal(res, c("", "", ""))
})

test_that("assign_arg_names handles the no-dots case", {
  res <- .mfae_assign_arg_names(c("", ""), c("e1", "e2"))
  expect_equal(res, c("e1", "e2"))
})

test_that("assign_arg_names matches partial names", {
  # `na.r` partially matches `na.rm`, so the positional arg gets `x`
  res <- .mfae_assign_arg_names(c("na.r", ""), c("x", "...", "na.rm"))
  expect_equal(res, c("na.r", "x"))
})

test_that("assign_arg_names ignores ambiguous partial names", {
  # `a` prefixes both `alpha` and `amount`, so neither is claimed
  res <- .mfae_assign_arg_names(c("a", ""), c("alpha", "amount", "zzz"))
  expect_equal(res, c("a", "alpha"))
})

test_that("assign_arg_names leaves overflow args unnamed", {
  res <- .mfae_assign_arg_names(c("", "", ""), c("x"))
  expect_equal(res, c("x", "", ""))
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
  # Control flow is excluded structurally (it never parses as a `name(...)`
  # call node), so it must not appear in the operator list
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
  expr <- quote(seq(1L, 10L))
  fmls <- formals(seq.default)
  res <- .mfae_match_args(expr, fmls)
  expect_equal(res[[2L]], 1L)
  expect_equal(names(res)[2L], "from")
  expect_equal(res[[3L]], 10L)
  expect_equal(names(res)[3L], "to")
})

test_that("mfae_match_args preserves order of explicitly named args", {
  expr <- quote(seq(to = 10L, from = 1L))
  fmls <- formals(seq.default)
  res <- .mfae_match_args(expr, fmls)
  # Original order in the call is: to, from
  expect_equal(res[[2L]], 10L)
  expect_equal(names(res)[2L], "to")
  expect_equal(res[[3L]], 1L)
  expect_equal(names(res)[3L], "from")
})

test_that("mfae_match_args handles dots - unmatched args unnamed", {
  expr <- quote(c(1L, 2L, 3L))
  fmls <- formals(c)
  res <- .mfae_match_args(expr, fmls)
  # c() only has dots, so all args remain unnamed → names are dropped (NULL)
  expect_null(names(res))
})

test_that("mfae_match_args handles primitive without dots", {
  expr <- quote(`+`(1L, 2L))
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
  expr <- quote(`+`(1L, 2L))
  fmls <- pairlist(e1 = NULL, e2 = NULL)
  res <- .mfae_match_args(expr, fmls)
  expect_equal(names(res), c("", "e1", "e2"))
})

# ---------------------------------------------------------------------------
# parse-data helpers -- unit tests
# ---------------------------------------------------------------------------

pd_of <- function(code) {
  .mfae_parse_data(utils::getParseData(parse(text = code, keep.source = TRUE)))
}

# Row of the outermost expression, i.e. the one whose parent is the root.
top_row_of <- function(pd) {
  which(pd$parent == 0L)[[1L]]
}

# Children of the outermost expression, i.e. the call node's own children.
call_kids_of <- function(pd) {
  .mfae_children(pd, pd$id[[top_row_of(pd)]])
}

plan_of <- function(code, skip_fns = NULL) {
  .mfae_plan_edits(parse(text = code, keep.source = TRUE), skip_fns = skip_fns)
}

test_that("children returns the direct children of a node", {
  pd <- pd_of("mean(1L)")
  top_id <- pd$id[[top_row_of(pd)]]
  kids <- .mfae_children(pd, top_id)
  expect_gt(length(kids), 0L)
  expect_true(all(pd$parent[kids] == top_id))
})

test_that("children returns nothing for an unknown node id", {
  pd <- pd_of("mean(1L)")
  expect_length(.mfae_children(pd, 999999L), 0L)
})

test_that("callee resolves simple and namespace-qualified heads", {
  pd <- pd_of("mean(1L)")
  head_row <- call_kids_of(pd)[[1L]]
  expect_equal(.mfae_callee(pd, head_row)$name, "mean")

  pd2 <- pd_of("stats::filter(1L)")
  head2 <- call_kids_of(pd2)[[1L]]
  callee <- .mfae_callee(pd2, head2)
  expect_equal(callee$name, "filter")
  expect_true(is.call(callee$expr))
})

test_that("callee returns NULL for anonymous and grouped heads", {
  # `(f)(1)` — head is a parenthesis, not a function name
  pd <- pd_of("(f)(1L)")
  head_row <- call_kids_of(pd)[[1L]]
  expect_null(.mfae_callee(pd, head_row))
})

test_that("arg_slots records names and positions in source order", {
  pd <- pd_of("f(a, b = 2, c)")
  slots <- .mfae_arg_slots(pd, call_kids_of(pd))

  expect_length(slots, 3L)
  expect_equal(vapply(slots, function(s) s$name, character(1L)), c("", "b", ""))
  expect_equal(slots[[1L]]$col, 3) # start of `a`
  expect_equal(slots[[3L]]$col, 13) # start of `c`
})

test_that("arg_slots keeps empty arguments as unnamed slots", {
  # `f(a, , b)` — the empty argument emits no token, only an extra comma
  pd <- pd_of("f(a, , b)")
  slots <- .mfae_arg_slots(pd, call_kids_of(pd))

  expect_length(slots, 3L)
  expect_equal(vapply(slots, function(s) s$name, character(1L)), c("", "", ""))
  expect_true(is.na(slots[[2L]]$line)) # nothing to insert before
  expect_false(is.na(slots[[3L]]$line))
})

test_that("arg_slots returns no slot for an empty call", {
  pd <- pd_of("f()")
  expect_length(.mfae_arg_slots(pd, call_kids_of(pd)), 0L)
})

test_that("is_dots detects a literal ...", {
  pd <- pd_of("f(x, ...)")
  slots <- .mfae_arg_slots(pd, call_kids_of(pd))
  expect_false(isTRUE(slots[[1L]]$dots))
  expect_true(isTRUE(slots[[2L]]$dots))
})

test_that("plan_edits reports the insertion position and text", {
  edits <- plan_of("mean(1L:10L)")
  expect_length(edits, 1L)
  expect_equal(edits[[1L]]$line, 1)
  expect_equal(edits[[1L]]$col, 6) # `1L:10L` starts at column 6
  expect_equal(edits[[1L]]$text, "x = ")
})

test_that("plan_edits returns nothing for already explicit calls", {
  expect_length(plan_of("mean(x = 1L:10L)"), 0L)
})

test_that("plan_edits skips named arguments", {
  # Only the first and third arguments are positional; `FUN = identity` keeps
  # its name. The nested `numeric(1L)` is a call of its own and gains `length`.
  edits <- plan_of("vapply(1L:9L, FUN = identity, numeric(1L))")
  expect_length(edits, 3L)
  expect_setequal(
    vapply(edits, `[[`, character(1L), "text"),
    c("X = ", "FUN.VALUE = ", "length = ")
  )
})

test_that("plan_edits skips operators, control flow and special syntax", {
  for (code in c(
    "a + b",
    "x$y",
    "lst[1L]",
    "lst[[1L]]",
    "x %% y",
    "if (x) y else z",
    "for (i in 1L:3L) print(i)",
    "while (TRUE) break",
    "(x + y)",
    "!x",
    "x <- 1L"
  )) {
    edits <- plan_of(code)
    # `print(i)` is a real call and is expected to gain `x = `
    if (grepl("print\\(", code)) {
      expect_length(edits, 1L)
    } else {
      expect_length(edits, 0L)
    }
  }
})

test_that("plan_edits skips infix operators and user-skipped functions", {
  expect_length(plan_of("x %in% y"), 0L)
  expect_length(plan_of("mean(1L:10L)", skip_fns = "mean"), 0L)
})

test_that("plan_edits skips calls that forward ... literally", {
  # The whole call is left alone, but nested calls are still handled
  expect_length(plan_of('substr("abcdef", 1L, ...)'), 0L)
  edits <- plan_of("vapply(1L:9L, identity, numeric(1L), ...)")
  expect_equal(vapply(edits, `[[`, character(1L), "text"), "length = ")
})

test_that("plan_edits skips unresolvable callees", {
  expect_length(plan_of("no_such_function_xyz(1L)"), 0L)
  expect_length(plan_of("(function(x) x)(1L)"), 0L)
})

test_that("plan_edits handles empty positional arguments", {
  # substr(x, start, stop): the empty middle argument still consumes `start`
  edits <- plan_of('substr("abcdef", , 2L)')
  expect_equal(vapply(edits, `[[`, character(1L), "text"), c("x = ", "stop = "))
  expect_equal(vapply(edits, `[[`, numeric(1L), "col"), c(8, 20))
})

test_that("apply_edits leaves lines untouched when there is nothing to do", {
  lines <- c("# comment", "mean(1L)", "")
  expect_equal(.mfae_apply_edits(lines, list()), lines)
})

test_that("apply_edits applies same-line insertions right to left", {
  lines <- "mean(1L)"
  edits <- list(
    list(line = 1, col = 6, text = "x = "),
    list(line = 1, col = 1, text = "stats::")
  )
  expect_equal(.mfae_apply_edits(lines, edits), "stats::mean(x = 1L)")
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
      character(0L)
    },
    .package = "base"
  )
  expect_error(make_func_arg_explicit(), "No R expressions found")
})

test_that("basic transformation: vapply", {
  tf <- withr::local_tempfile(fileext = ".R")
  writeLines("vapply(1:9, function(x) x*2, numeric(1))", tf)
  make_func_arg_explicit(tf)
  result <- readLines(tf, warn = FALSE)
  expected <- "vapply(X = 1:9, FUN = function(x) x*2, FUN.VALUE = numeric(length = 1))"
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

test_that("empty file aborts", {
  tf <- withr::local_tempfile(fileext = ".R")
  writeLines(character(0L), tf)
  expect_error(make_func_arg_explicit(tf), "No R expressions found")
})

test_that("file with only comments aborts", {
  tf <- withr::local_tempfile(fileext = ".R")
  writeLines(c("# just a comment", "# another one"), tf)
  expect_error(make_func_arg_explicit(tf), "No R expressions found")
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

test_that("comments inside a function body are preserved", {
  tf <- withr::local_tempfile(fileext = ".R")
  input_lines <- c(
    "my_fun <- function(x) {",
    "  # step 1: coerce to numeric",
    "  x <- as.numeric(x)   # inline note",
    "",
    "  # step 2: average",
    "  mean(x, TRUE)  # result",
    "}"
  )
  expected_lines <- c(
    "my_fun <- function(x) {",
    "  # step 1: coerce to numeric",
    "  x <- as.numeric(x)   # inline note",
    "",
    "  # step 2: average",
    "  mean(x = x, TRUE)  # result",
    "}"
  )
  writeLines(input_lines, tf)
  make_func_arg_explicit(tf)
  expect_equal(readLines(tf, warn = FALSE), expected_lines)
})

test_that("indentation and operator spacing are not reformatted", {
  tf <- withr::local_tempfile(fileext = ".R")
  input_lines <- c(
    "\tmy_fun <- function(x) {",
    "\t\t# keep my tabs",
    "\t\tmean(1 : 10,   TRUE) # keep my spaces",
    "\t}"
  )
  expected_lines <- c(
    "\tmy_fun <- function(x) {",
    "\t\t# keep my tabs",
    "\t\tmean(x = 1 : 10,   TRUE) # keep my spaces",
    "\t}"
  )
  writeLines(input_lines, tf)
  make_func_arg_explicit(tf)
  expect_equal(readLines(tf, warn = FALSE), expected_lines)
})

test_that("comments between cross-line arguments are preserved", {
  tf <- withr::local_tempfile(fileext = ".R")
  input_lines <- c(
    "res <- vapply(",
    "  1:9,  # the input",
    "  function(x) x,  # the fun",
    "  numeric(1)  # the type",
    ")"
  )
  writeLines(input_lines, tf)
  make_func_arg_explicit(tf)
  expect_equal(
    readLines(tf, warn = FALSE),
    c(
      "res <- vapply(",
      "  X = 1:9,  # the input",
      "  FUN = function(x) x,  # the fun",
      "  FUN.VALUE = numeric(length = 1)  # the type",
      ")"
    )
  )
})

test_that("several calls on one line are all handled", {
  tf <- withr::local_tempfile(fileext = ".R")
  writeLines("foo <- mean(1:10, TRUE); bar <- sd(1:5, TRUE)  # two calls", tf)
  make_func_arg_explicit(tf)
  expect_equal(
    readLines(tf, warn = FALSE),
    "foo <- mean(x = 1:10, TRUE); bar <- sd(x = 1:5, na.rm = TRUE)  # two calls"
  )
})

test_that("existing argument names are never duplicated", {
  tf <- withr::local_tempfile(fileext = ".R")
  writeLines("vapply(1:9, FUN = identity, numeric(1))", tf)
  make_func_arg_explicit(tf)
  expect_equal(
    readLines(tf, warn = FALSE),
    "vapply(X = 1:9, FUN = identity, FUN.VALUE = numeric(length = 1))"
  )
})

test_that("empty arguments keep positional alignment", {
  tf <- withr::local_tempfile(fileext = ".R")
  writeLines('substr("abcdef", , 2)', tf)
  make_func_arg_explicit(tf)
  expect_equal(readLines(tf, warn = FALSE), 'substr(x = "abcdef", , stop = 2)')
})

test_that("calls forwarding ... are left alone", {
  tf <- withr::local_tempfile(fileext = ".R")
  input_lines <- c(
    "res <- vapply(1:9, identity, numeric(1), ...)",
    "other <- mean(1:10, TRUE)"
  )
  writeLines(input_lines, tf)
  make_func_arg_explicit(tf)
  expect_equal(
    readLines(tf, warn = FALSE),
    c(
      "res <- vapply(1:9, identity, numeric(length = 1), ...)",
      "other <- mean(x = 1:10, TRUE)"
    )
  )
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
