# Tests for standalone-make_arg_validator.R
#
# make_arg_validator() is a factory: it returns a validator function that, when
# called from inside another function, captures that caller's arguments,
# evaluates the supplied expression against them and returns the (possibly
# checked or coerced) arguments as a named list.

# ── factory shape ────────────────────────────────────────────────────────────

test_that("make_arg_validator returns a function taking an env argument", {
  v <- rpkgkit:::make_arg_validator({
    invisible(NULL)
  })

  expect_true(is.function(v))
  expect_identical(names(formals(v)), "env")
})

# ── capturing the caller's arguments ─────────────────────────────────────────

test_that("the validator returns the caller's arguments as a named list", {
  v <- rpkgkit:::make_arg_validator({
    invisible(NULL)
  })
  f <- function(x, y) v()

  expect_identical(f(1L, 2L), list(x = 1L, y = 2L))
})

test_that("the validator returns arguments ordered by name", {
  v <- rpkgkit:::make_arg_validator({
    invisible(NULL)
  })
  f <- function(b, a) v()

  expect_identical(names(f(2L, 1L)), c("a", "b"))
})

test_that("default argument values are forced and returned", {
  v <- rpkgkit:::make_arg_validator({
    invisible(NULL)
  })
  f <- function(a, b = 10L) v()

  expect_identical(f(1L), list(a = 1L, b = 10L))
})

test_that("a validator called from a function without arguments returns an empty list", {
  v <- rpkgkit:::make_arg_validator({
    invisible(NULL)
  })
  f <- function() v()

  res <- f()
  expect_type(res, "list")
  expect_length(res, 0L)
})

test_that("local temporaries in the caller are captured too", {
  v <- rpkgkit:::make_arg_validator({
    if (x <= 0) {
      rlang::abort("`x` must be positive.", call = NULL)
    }
  })
  f <- function(x) {
    tmp <- "not an argument"
    names(v())
  }

  expect_identical(f(4), c("tmp", "x"))
})

test_that("a temporary reassigned by the expression is returned", {
  v <- rpkgkit:::make_arg_validator({
    tmp <- toupper(tmp)
  })
  f <- function(tmp) v()

  expect_identical(f("a"), list(tmp = "A"))
})

test_that("helpers visible from the caller remain visible to the expression", {
  helper <- function(value) value * 2
  v <- rpkgkit:::make_arg_validator({
    x <- helper(x)
  })
  f <- function(x) v()

  expect_identical(f(3), list(x = 6))
})

# ── validating ───────────────────────────────────────────────────────────────

test_that("the expression can check the arguments and they are returned unchanged", {
  v <- rpkgkit:::make_arg_validator({
    if (!is.numeric(x) || length(x) != 1L) {
      rlang::abort("`x` must be a single number.", call = NULL)
    }
    if (!is.numeric(y) || length(y) != 1L) {
      rlang::abort("`y` must be a single number.", call = NULL)
    }
  })
  add <- function(x, y) {
    args <- v()
    args$x + args$y
  }

  expect_identical(add(1, 2), 3)
  expect_error(add("a", 2), "`x` must be a single number.", fixed = TRUE)
  expect_error(add(1, "b"), "`y` must be a single number.", fixed = TRUE)
})

test_that("errors signalled by the expression reach the caller unchanged", {
  v <- rpkgkit:::make_arg_validator({
    if (denominator == 0) {
      rlang::abort("`denominator` must not be zero.", call = NULL)
    }
  })
  f <- function(numerator, denominator) v()

  expect_error(f(1, 0), "`denominator` must not be zero.", fixed = TRUE)
})

test_that("errors about objects missing from the scope reach the caller unchanged", {
  v <- rpkgkit:::make_arg_validator({
    x <- z
  })
  f <- function(x) v()

  expect_error(f(1), "object 'z' not found", fixed = TRUE)
})

test_that("classed conditions from the expression can be caught by the caller", {
  v <- rpkgkit:::make_arg_validator({
    if (!is.numeric(n)) {
      rlang::abort(
        "`n` must be numeric.",
        class = "rpkgkit_bad_n",
        call = NULL
      )
    }
  })
  f <- function(n) v()

  expect_error(f("a"), class = "rpkgkit_bad_n")
  expect_identical(
    tryCatch(f("a"), rpkgkit_bad_n = function(cnd) conditionMessage(cnd)),
    "`n` must be numeric."
  )
})

test_that("an argument without a default fails when its promise is forced", {
  v <- rpkgkit:::make_arg_validator({
    invisible(x)
  })
  f <- function(x) v()

  expect_error(f(), 'argument "x" is missing, with no default')
})

# ── coercing ─────────────────────────────────────────────────────────────────

test_that("coercions inside the expression reach the caller through the result", {
  v <- rpkgkit:::make_arg_validator({
    numerator <- as.numeric(numerator)
    denominator <- as.numeric(denominator)
  })
  ratio <- function(numerator, denominator) {
    list2env(v(), envir = environment())
    numerator / denominator
  }

  expect_identical(ratio("3", 2), 1.5)
})

test_that("values reassigned by the expression replace the originals", {
  v <- rpkgkit:::make_arg_validator({
    x <- as.integer(x)
    x <- x + 1L
  })
  f <- function(x) v()

  expect_identical(f("2"), list(x = 3L))
})

test_that("a binding created by the expression is not added to the result", {
  v <- rpkgkit:::make_arg_validator({
    span <- max(x) - min(x)
    x <- (x - min(x)) / span
  })
  f <- function(x) v()

  expect_identical(f(c(0, 5, 10)), list(x = c(0, 0.5, 1)))
})

test_that("the caller's own bindings are never modified", {
  v <- rpkgkit:::make_arg_validator({
    x <- x + 1
  })
  f <- function(x) {
    args <- v()
    c(inside = x, returned = args$x)
  }

  expect_identical(f(1), c(inside = 1, returned = 2))
})

test_that("a validator keeps no state between calls", {
  v <- rpkgkit:::make_arg_validator({
    x <- x + 1
  })
  f <- function(x) v()$x

  expect_identical(f(1), 2)
  expect_identical(f(1), 2)
  expect_identical(f(5), 6)
})

test_that("a validator can be shared between several functions", {
  v <- rpkgkit:::make_arg_validator({
    color <- match.arg(color, c("red", "green", "blue"))
    size <- max(size, 1)
  })
  draw_point <- function(x, y, color = "red", size = 0) {
    args <- v()
    sprintf(
      "point (%s, %s) color=%s size=%s",
      x,
      y,
      args$color,
      args$size
    )
  }

  expect_identical(
    draw_point(1, 2, color = "green", size = 0),
    "point (1, 2) color=green size=1"
  )
  expect_identical(draw_point(1, 2), "point (1, 2) color=red size=1")
})

# ── dots ─────────────────────────────────────────────────────────────────────

test_that("... is readable inside the expression but never returned", {
  v <- rpkgkit:::make_arg_validator({
    if (...length() > 2L) {
      rlang::abort("at most two values are supported.", call = NULL)
    }
  })
  f <- function(x, ...) v()

  expect_identical(f(1, 2), list(x = 1))
  expect_identical(f(1, 2, 3), list(x = 1))
  expect_error(f(1, 2, 3, 4), "at most two values are supported.", fixed = TRUE)
})

test_that("... is dropped even when it is named", {
  v <- rpkgkit:::make_arg_validator({
    invisible(NULL)
  })
  f <- function(x, ...) v()

  expect_identical(f(1, extra = 2), list(x = 1))
})

# ── supplying env explicitly ─────────────────────────────────────────────────

test_that("an environment can be validated directly", {
  v <- rpkgkit:::make_arg_validator({
    name <- trimws(name)
    threads <- as.integer(threads)
  })
  opts <- list2env(list(name = "  model  ", threads = "4"))

  expect_identical(v(opts), list(name = "model", threads = 4L))
  expect_identical(opts$name, "  model  ")
})

test_that("env can be supplied by name", {
  v <- rpkgkit:::make_arg_validator({
    x <- x * 2
  })
  e <- list2env(list(x = 2))

  expect_identical(v(env = e), list(x = 4))
})

test_that("every binding of an explicitly supplied environment is returned", {
  v <- rpkgkit:::make_arg_validator({
    invisible(NULL)
  })
  e <- list2env(list(a = 1, b = 2, c = 3))

  expect_identical(v(e), list(a = 1, b = 2, c = 3))
})

test_that("passing something that is not an environment fails", {
  v <- rpkgkit:::make_arg_validator({
    invisible(NULL)
  })

  expect_error(v(list(x = 1)), "envir")
})
