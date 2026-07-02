test_that("get_var_value returns parameter default value", {
  f <- function(x = 42) x
  expect_equal(rpkgkit:::get_var_value("x", f), 42)
})

test_that("get_var_value returns computed value from parameter", {
  f <- function(a = 1, b = 2) {
    c <- a * 2 + b * 3
    c
  }
  expect_equal(rpkgkit:::get_var_value("c", f), 8)
})

test_that("get_var_value resolves chained assignments", {
  f <- function(a = 1, b = 2) {
    c <- a * 2 + b * 3
    d <- c^2
    d
  }
  expect_equal(rpkgkit:::get_var_value("d", f), 64)
})

test_that("get_var_value handles <<- assignment", {
  f <- function(a = 1, b = 2) {
    c <- a * 2 + b * 3
    d <- c^2
    e <<- d - 1
    e
  }
  expect_equal(rpkgkit:::get_var_value("e", f), 63)
})

test_that("get_var_value ignores dead code after return()", {
  f <- function(a = "A", ...) {
    a <- 1
    return(a)
    a <- 2
    a
  }
  expect_equal(rpkgkit:::get_var_value("a", f), 1)
})

test_that("get_var_value traces for loop iterations", {
  f <- function(x = 2) {
    for (k in 1:3) {
      x <- x * 2
    }
    x
  }
  expect_equal(rpkgkit:::get_var_value("x", f), 16)
})

test_that("get_var_value traces while loop iterations", {
  f <- function(x = 2) {
    while (x < 10) {
      x <- x * 2
    }
    x
  }
  expect_equal(rpkgkit:::get_var_value("x", f), 16)
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
  f <- function(x = 1) y
  expect_error(
    rpkgkit:::get_var_value("nonexistent", f),
    "not found"
  )
})

test_that("get_var_value handles function calls in expressions", {
  f <- function(n = 5) {
    x <- seq_len(n)
    x
  }
  result <- rpkgkit:::get_var_value("x", f)
  expect_equal(result, 1:5)
})

test_that("get_var_value handles subset assignment with [", {
  f <- function(n = 3) {
    x <- 1:n
    x[2] <- 99
    x
  }
  result <- rpkgkit:::get_var_value("x", f)
  expect_equal(result[2], 99)
})

test_that("get_var_value handles subset assignment with [[", {
  f <- function(n = 3) {
    x <- 1:n
    x[[2]] <- 99
    x
  }
  result <- rpkgkit:::get_var_value("x", f)
  expect_equal(result[[2]], 99)
})

test_that("get_var_value handles `repeat` loop with break", {
  f <- function(x = 1) {
    repeat {
      x <- x * 2
      if (x > 10) break
    }
    x
  }
  expect_equal(rpkgkit:::get_var_value("x", f), 16)
})

test_that("get_var_value handles `$` subset assignment", {
  f <- function() {
    x <- list(a = 1, b = 2)
    x$b <- 99
    x
  }
  result <- rpkgkit:::get_var_value("x", f)
  expect_equal(result$b, 99)
})

test_that("get_var_value uses caller environment for function calls", {
  f <- function(n = 3) {
    x <- runif(n)
    x
  }
  result <- rpkgkit:::get_var_value("x", f)
  expect_length(result, 3)
})

test_that("get_var_value can resolve string operations with file.path", {
  f <- function(save_path = "./analysis") {
    save_path_new <- file.path(save_path, "res")
    save_path_new
  }
  expect_equal(rpkgkit:::get_var_value("save_path_new", f), "./analysis/res")
})
