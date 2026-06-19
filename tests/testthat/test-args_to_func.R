# Tests for standalone-args_to_func.R
# Three functions: filter_args_for_func, match_func_to_args, get_func_args

# ── filter_args_for_func ─────────────────────────────────────────────────────

test_that("filter_args_for_func keeps only arguments matching function formals", {
  f <- function(a, b, c) a + b + c
  args <- list(a = 1, b = 2, c = 3, d = 4, e = 5)

  result <- filter_args_for_func(args, f)
  expect_named(result, c("a", "b", "c"))
  expect_equal(result$a, 1)
  expect_equal(result$b, 2)
  expect_equal(result$c, 3)
})

test_that("filter_args_for_func returns empty list when no args match", {
  f <- function(x, y) x + y
  args <- list(a = 1, b = 2)

  result <- filter_args_for_func(args, f)
  expect_type(result, "list")
  expect_length(result, 0)
})

test_that("filter_args_for_func preserves additional arguments via keep", {https://xmpalantir.wu.ac.at/cransubmit/conf_mail.php?code=9e1b68fc5e6afd2fcf0dc454596e66ae
  f <- function(a, b) a + b
  args <- list(a = 1, b = 2, extra = 99, another = 100)

  result <- filter_args_for_func(args, f, keep = c("extra", "another"))
  expect_named(result, c("a", "b", "extra", "another"))
  expect_equal(result$extra, 99)
  expect_equal(result$another, 100)
})

test_that("filter_args_for_func: keep works even when args don't match formals at all", {
  f <- function(x, y) x + y
  args <- list(a = 1, b = 2)

  result <- filter_args_for_func(args, f, keep = "a")
  expect_named(result, "a")
  expect_equal(result$a, 1)
})

test_that("filter_args_for_func handles empty args_list", {
  f <- function(a, b) a + b
  args <- list()

  result <- filter_args_for_func(args, f)
  expect_type(result, "list")
  expect_length(result, 0)
})

test_that("filter_args_for_func handles NULL keep (default)", {
  f <- function(a, b) a + b
  args <- list(a = 1, b = 2)

  result <- filter_args_for_func(args, f)
  expect_named(result, c("a", "b"))
})

test_that("filter_args_for_func excludes ... from function formals", {
  f <- function(a, b, ...) a + b
  args <- list(a = 1, b = 2, ... = "dots")

  result <- filter_args_for_func(args, f)
  expect_named(result, c("a", "b"))
  expect_false("..." %in% names(result))
})

test_that("filter_args_for_func handles function with no formal parameters", {
  f <- function() 42
  args <- list(a = 1, b = 2)

  result <- filter_args_for_func(args, f)
  expect_type(result, "list")
  expect_length(result, 0)
})

test_that("filter_args_for_func: keep does not duplicate matched formals", {
  f <- function(a, b) a + b
  args <- list(a = 1, b = 2, c = 3)

  # keep includes 'a' which is already in formals — should not duplicate
  result <- filter_args_for_func(args, f, keep = c("a", "c"))
  expect_named(result, c("a", "b", "c"))
})

# ── match_func_to_args ───────────────────────────────────────────────────────

test_that("match_func_to_args: strict matching returns only compatible functions", {
  f1 <- function(a, b) a + b
  f2 <- function(x, y) x * y
  f3 <- function(p, q) p - q

  args <- list(a = 1, b = 2)

  result <- match_func_to_args(args, f1, f2, f3)
  expect_length(result, 1)
  expect_true(is.function(result[[1]]))
})

test_that("match_func_to_args returns empty when no function matches", {
  f1 <- function(x, y) x + y
  f2 <- function(p, q) p * q

  args <- list(a = 1, b = 2)

  result <- match_func_to_args(args, f1, f2)
  expect_length(result, 0)
})

test_that("match_func_to_args: dots_enabled=TRUE includes functions with ...", {
  f1 <- function(a, b) a + b
  f2 <- function(x, y, ...) x * y
  f3 <- function(p, q) p - q

  args <- list(a = 1, b = 2)

  result <- match_func_to_args(args, f1, f2, f3, dots_enabled = TRUE)
  expect_length(result, 2)
})

test_that("match_func_to_args: dots_enabled=TRUE and first function matches all args", {
  f1 <- function(a, b) a + b
  f2 <- function(x, y, ...) x * y

  args <- list(a = 1, b = 2)

  result <- match_func_to_args(args, f1, f2, dots_enabled = TRUE)
  # f1 matches all args, so first_hold=TRUE preserves f1
  expect_true(any(vapply(result, identical, logical(1), f1)))
})

test_that("match_func_to_args: name_only=TRUE returns names", {
  f1 <- function(a, b) a + b
  f2 <- function(x, y) x * y

  args <- list(a = 1, b = 2)

  result <- match_func_to_args(args, f1, f2, name_only = TRUE)
  expect_type(result, "character")
  expect_equal(result, "f1")
})

test_that("match_func_to_args: name_only=TRUE with no match returns empty character", {
  f1 <- function(x, y) x + y

  args <- list(a = 1, b = 2)

  result <- match_func_to_args(args, f1, name_only = TRUE)
  expect_type(result, "character")
  expect_length(result, 0)
})

test_that("match_func_to_args: top_one_only=TRUE returns single best match", {
  # f1's matched params (a,b) are at positions 1,2 → sum=3
  # f2's matched params (a,b) are at positions 1,3 → sum=4
  # f1 wins with lower position_sum
  f1 <- function(a, b) a + b
  f2 <- function(a, c, b) a + b + c

  args <- list(a = 1, b = 2)

  result <- match_func_to_args(args, f1, f2, top_one_only = TRUE)
  expect_true(is.function(result))
})

test_that("match_func_to_args: aborts on unnamed args_list", {
  f1 <- function(a, b) a + b

  # Named but some empty names
  expect_error(
    match_func_to_args(setNames(list(1, 2), c("a", "")), f1),
    "named list"
  )

  # Completely unnamed
  expect_error(
    match_func_to_args(list(1, 2), f1),
    "named list"
  )
})

test_that("match_func_to_args handles empty ... (no functions)", {
  args <- list(a = 1, b = 2)

  result <- match_func_to_args(args)
  expect_length(result, 0)
})

test_that("match_func_to_args: empty ... with name_only=TRUE returns empty character", {
  args <- list(a = 1, b = 2)

  result <- match_func_to_args(args, name_only = TRUE)
  expect_type(result, "character")
  expect_length(result, 0)
})

test_that("match_func_to_args: top_one_only with tie warns", {
  f1 <- function(a, b) a + b
  f2 <- function(a, b) a - b

  args <- list(a = 1, b = 2)

  expect_warning(
    match_func_to_args(args, f1, f2, top_one_only = TRUE),
    "not enough to select"
  )
})

test_that("match_func_to_args: top_one_only with name_only=TRUE returns name", {
  # f1's matched params (a,b) are at positions 1,2 → sum=3
  # f2's matched params (a,b) are at positions 1,3 → sum=4
  # f1 wins with lower position_sum
  f1 <- function(a, b) a + b
  f2 <- function(a, c, b) a + b + c

  args <- list(a = 1, b = 2)

  result <- match_func_to_args(args, f1, f2, top_one_only = TRUE, name_only = TRUE)
  expect_type(result, "character")
  expect_equal(result, "f1")
})

test_that("match_func_to_args: strict matching excludes function missing an arg", {
  f1 <- function(a) a
  f2 <- function(a, b) a + b

  args <- list(a = 1, b = 2)

  result <- match_func_to_args(args, f1, f2)
  # f1 is missing 'b', so only f2 should match
  expect_length(result, 1)
})

test_that("match_func_to_args matches function with extra formals (beyond args)", {
  f1 <- function(a, b, c = 10) a + b + c

  args <- list(a = 1, b = 2)

  # f1 has all args (a, b) even though it also has c
  result <- match_func_to_args(args, f1)
  expect_length(result, 1)
})

# ── get_func_args ────────────────────────────────────────────────────────────

test_that("get_func_args retrieves all arguments from calling context", {
  tester <- function(a, b, c) {
    get_func_args()
  }

  result <- tester(1, 2, 3)
  expect_type(result, "list")
  expect_named(result, c("a", "b", "c"))
  expect_equal(result$a, 1)
  expect_equal(result$b, 2)
  expect_equal(result$c, 3)
})

test_that("get_func_args: name_only=TRUE returns argument names", {
  tester <- function(a, b, c = 10) {
    get_func_args(name_only = TRUE)
  }

  result <- tester(1, 2)
  expect_type(result, "character")
  expect_setequal(result, c("a", "b", "c"))
})

test_that("get_func_args: name_only=TRUE with ... and dots_expand=TRUE", {
  tester <- function(a, ...) {
    get_func_args(name_only = TRUE, dots_expand = TRUE)
  }

  result <- tester(1, 2, 3)
  expect_true("a" %in% result)
  expect_true("..." %in% result)
})

test_that("get_func_args excludes arguments by character vector", {
  tester <- function(a, b, c) {
    get_func_args(exclude = "b")
  }

  result <- tester(1, 2, 3)
  expect_named(result, c("a", "c"))
  expect_false("b" %in% names(result))
})

test_that("get_func_args excludes arguments by numeric index", {
  tester <- function(a, b, c) {
    get_func_args(exclude = 2)
  }

  result <- tester(1, 2, 3)
  expect_named(result, c("a", "c"))
  expect_false("b" %in% names(result))
})

test_that("get_func_args: exclude with name_only=TRUE", {
  tester <- function(a, b, c) {
    get_func_args(exclude = "a", name_only = TRUE)
  }

  result <- tester(1, 2, 3)
  expect_false("a" %in% result)
  expect_true("b" %in% result)
  expect_true("c" %in% result)
})

test_that("get_func_args aborts on invalid exclude type", {
  tester <- function(a) {
    get_func_args(exclude = TRUE)
  }

  expect_error(tester(1), "logical")
})

test_that("get_func_args handles defaults correctly", {
  tester <- function(a, b = 10) {
    get_func_args()
  }

  result <- tester(1)
  expect_named(result, c("a", "b"))
  expect_equal(result$a, 1)
  expect_equal(result$b, 10)
})

test_that("get_func_args: exclude by name with name_only=TRUE and ...", {
  tester <- function(a, b, ...) {
    get_func_args(exclude = "b", name_only = TRUE, dots_expand = TRUE)
  }

  result <- tester(1, 2, 3, 4)
  expect_false("b" %in% result)
  expect_true("a" %in% result)
  expect_true("..." %in% result)
})
