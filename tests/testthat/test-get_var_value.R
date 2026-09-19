test_that("get_var_value returns parameter default value", {
  f <- function(x = 42L) x
  expect_equal(rpkgkit:::get_var_value("x", f), 42L)
})

test_that("get_var_value returns computed value from parameter", {
  f <- function(a = 1L, b = 2L) {
    c <- a * 2L + b * 3L
    c
  }
  expect_equal(rpkgkit:::get_var_value("c", f), 8L)
})

test_that("get_var_value resolves chained assignments", {
  f <- function(a = 1L, b = 2L) {
    c <- a * 2L + b * 3L
    d <- c^2L
    d
  }
  expect_equal(rpkgkit:::get_var_value("d", f), 64L)
})

test_that("get_var_value handles <<- assignment", {
  f <- function(a = 1L, b = 2L) {
    c <- a * 2L + b * 3L
    d <- c^2L
    e <<- d - 1L
    e
  }
  expect_equal(rpkgkit:::get_var_value("e", f), 63L)
})

test_that("get_var_value ignores dead code after return()", {
  f <- function(a = "A", ...) {
    a <- 1L
    return(a)
    a <- 2L
    a
  }
  expect_equal(rpkgkit:::get_var_value("a", f), 1L)
})

test_that("get_var_value traces for loop iterations", {
  f <- function(x = 2L) {
    for (k in 1L:3L) {
      x <- x * 2L
    }
    x
  }
  expect_equal(rpkgkit:::get_var_value("x", f), 16L)
})

test_that("get_var_value traces while loop iterations", {
  f <- function(x = 2L) {
    while (x < 10L) {
      x <- x * 2L
    }
    x
  }
  expect_equal(rpkgkit:::get_var_value("x", f), 16L)
})

test_that("get_var_value handles if/else branches", {
  f <- function(cond = TRUE) {
    if (cond) {
      x <- "true_branch"
    } else {
      x <- "false_branch"
    }
    x
  }
  expect_equal(rpkgkit:::get_var_value("x", f), "true_branch")
})

test_that("get_var_value handles if/else with FALSE condition", {
  f <- function(cond = FALSE) {
    if (cond) {
      x <- "true_branch"
    } else {
      x <- "false_branch"
    }
    x
  }
  expect_equal(rpkgkit:::get_var_value("x", f), "false_branch")
})

test_that("get_var_value aborts when variable not found", {
  f <- function(x = 1L) y
  expect_error(
    rpkgkit:::get_var_value("nonexistent", f),
    "not found"
  )
})

test_that("get_var_value handles function calls in expressions", {
  f <- function(n = 5L) {
    x <- seq_len(n)
    x
  }
  result <- rpkgkit:::get_var_value("x", f)
  expect_equal(result, 1L:5L)
})

test_that("get_var_value handles subset assignment with [", {
  f <- function(n = 3L) {
    x <- 1L:n
    x[2L] <- 99L
    x
  }
  result <- rpkgkit:::get_var_value("x", f)
  expect_equal(result[2L], 99L)
})

test_that("get_var_value handles subset assignment with [[", {
  f <- function(n = 3L) {
    x <- 1L:n
    x[[2L]] <- 99L
    x
  }
  result <- rpkgkit:::get_var_value("x", f)
  expect_equal(result[[2L]], 99L)
})

test_that("get_var_value handles `repeat` loop with break", {
  f <- function(x = 1L) {
    repeat {
      x <- x * 2L
      if (x > 10L) break
    }
    x
  }
  expect_equal(rpkgkit:::get_var_value("x", f), 16L)
})

test_that("get_var_value handles `$` subset assignment", {
  f <- function() {
    x <- list(a = 1L, b = 2L)
    x$b <- 99L
    x
  }
  result <- rpkgkit:::get_var_value("x", f)
  expect_equal(result$b, 99L)
})

test_that("get_var_value uses caller environment for function calls", {
  f <- function(n = 3L) {
    x <- runif(n)
    x
  }
  result <- rpkgkit:::get_var_value("x", f)
  expect_length(result, 3L)
})

test_that("get_var_value can resolve string operations with file.path", {
  f <- function(save_path = "./analysis") {
    save_path_new <- file.path(save_path, "res")
    save_path_new
  }
  expect_equal(rpkgkit:::get_var_value("save_path_new", f), "./analysis/res")
})
