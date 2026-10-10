# ---------------------------------------------------------------------------
# convert_pipe -- integration tests
# ---------------------------------------------------------------------------

test_that("convert_pipe rewrites %>% to the base pipe", {
  path <- withr::local_tempfile(fileext = ".R")
  writeLines("mtcars %>% dplyr::filter(cyl > 4)", path)

  result <- convert_pipe(path, direction = "to_base", verbose = FALSE)

  expect_true(result)
  expect_equal(
    readLines(path, warn = FALSE),
    "mtcars |> dplyr::filter(cyl > 4)"
  )
})

test_that("convert_pipe rewrites |> to the magrittr pipe", {
  path <- withr::local_tempfile(fileext = ".R")
  writeLines("mtcars |> dplyr::filter(cyl > 4)", path)

  convert_pipe(path, direction = "to_magrittr", verbose = FALSE)

  expect_equal(
    readLines(path, warn = FALSE),
    "mtcars %>% dplyr::filter(cyl > 4)"
  )
})

test_that("convert_pipe returns TRUE invisibly after converting", {
  path <- withr::local_tempfile(fileext = ".R")
  writeLines("x %>% identity()", path)

  result <- withVisible(convert_pipe(path, verbose = FALSE))

  expect_false(result$visible)
  expect_true(result$value)
})

test_that("convert_pipe returns FALSE when there is nothing to convert", {
  path <- withr::local_tempfile(fileext = ".R")
  writeLines("x <- 1", path)

  expect_message(
    result <- convert_pipe(path, verbose = TRUE),
    "No pipes to convert"
  )
  expect_false(result)
})

test_that("convert_pipe defaults to converting toward the base pipe", {
  path <- withr::local_tempfile(fileext = ".R")
  writeLines("x %>% identity()", path)

  convert_pipe(path, verbose = FALSE)

  expect_equal(readLines(path, warn = FALSE), "x |> identity()")
})

test_that("convert_pipe converts every pipe in a chain", {
  path <- withr::local_tempfile(fileext = ".R")
  writeLines(c("x %>%", "  identity() %>%", "  identity()"), path)

  convert_pipe(path, verbose = FALSE)

  expect_equal(
    readLines(path, warn = FALSE),
    c("x |>", "  identity() |>", "  identity()")
  )
})

test_that("convert_pipe matches pipes literally, not across whitespace", {
  path <- withr::local_tempfile(fileext = ".R")
  writeLines(c("x %>% identity()", "y %", "> % identity()"), path)

  convert_pipe(path, verbose = FALSE)

  expect_equal(
    readLines(path, warn = FALSE),
    c("x |> identity()", "y %", "> % identity()")
  )
})

test_that("convert_pipe leaves other magrittr operators unchanged", {
  path <- withr::local_tempfile(fileext = ".R")
  writeLines(c("x %<>% identity()", "y %$% col", "z %myop% 1"), path)

  convert_pipe(path, verbose = FALSE)

  expect_equal(
    readLines(path, warn = FALSE),
    c("x %<>% identity()", "y %$% col", "z %myop% 1")
  )
})

test_that("convert_pipe does not treat the tail of %>% as a base pipe", {
  path <- withr::local_tempfile(fileext = ".R")
  writeLines("x %>% identity()", path)

  convert_pipe(path, direction = "to_magrittr", verbose = FALSE)

  expect_equal(readLines(path, warn = FALSE), "x %>% identity()")
})

test_that("convert_pipe leaves |> inside strings unchanged on the way to magrittr", {
  path <- withr::local_tempfile(fileext = ".R")
  writeLines(c('pat <- "a|>b"', "x |> identity()"), path)

  convert_pipe(path, direction = "to_magrittr", verbose = FALSE)

  expect_equal(
    readLines(path, warn = FALSE),
    c('pat <- "a|>b"', "x %>% identity()")
  )
})

test_that("convert_pipe leaves pipes inside strings unchanged", {
  path <- withr::local_tempfile(fileext = ".R")
  writeLines(c('x <- "a %>% b"', "y %>% identity()"), path)

  convert_pipe(path, verbose = FALSE)

  expect_equal(
    readLines(path, warn = FALSE),
    c('x <- "a %>% b"', "y |> identity()")
  )
})

test_that("convert_pipe leaves pipes inside comments unchanged", {
  path <- withr::local_tempfile(fileext = ".R")
  writeLines(c("# x %>% y", "x %>% identity() # still %>%"), path)

  convert_pipe(path, verbose = FALSE)

  expect_equal(
    readLines(path, warn = FALSE),
    c("# x %>% y", "x |> identity() # still %>%")
  )
})

test_that("convert_pipe leaves pipes inside raw strings unchanged", {
  path <- withr::local_tempfile(fileext = ".R")
  writeLines('x <- r"(a %>% b)"', path)

  convert_pipe(path, verbose = FALSE)

  expect_equal(readLines(path, warn = FALSE), 'x <- r"(a %>% b)"')
})

test_that("convert_pipe handles escaped quotes in strings", {
  path <- withr::local_tempfile(fileext = ".R")
  writeLines('x <- "say \\"%>%\\"" ; y %>% identity()', path)

  convert_pipe(path, verbose = FALSE)

  expect_equal(
    readLines(path, warn = FALSE),
    'x <- "say \\"%>%\\"" ; y |> identity()'
  )
})

test_that("convert_pipe is idempotent", {
  path <- withr::local_tempfile(fileext = ".R")
  writeLines("x %>% identity()", path)

  convert_pipe(path, verbose = FALSE)
  convert_pipe(path, verbose = FALSE)

  expect_equal(readLines(path, warn = FALSE), "x |> identity()")
})

test_that("convert_pipe round-trips between the two pipes", {
  path <- withr::local_tempfile(fileext = ".R")
  writeLines("x %>% identity() %>% identity()", path)

  convert_pipe(path, direction = "to_base", verbose = FALSE)
  convert_pipe(path, direction = "to_magrittr", verbose = FALSE)

  expect_equal(
    readLines(path, warn = FALSE),
    "x %>% identity() %>% identity()"
  )
})

test_that("convert_pipe reports when nothing changes", {
  path <- withr::local_tempfile(fileext = ".R")
  writeLines("x <- 1", path)

  expect_message(
    convert_pipe(path, verbose = TRUE),
    "No pipes to convert"
  )
  expect_equal(readLines(path, warn = FALSE), "x <- 1")
})

test_that("convert_pipe reports the conversion when verbose = TRUE", {
  path <- withr::local_tempfile(fileext = ".R")
  writeLines("x %>% identity()", path)

  expect_message(
    convert_pipe(path, verbose = TRUE),
    "Converted pipes in"
  )
  expect_equal(readLines(path, warn = FALSE), "x |> identity()")
})

test_that("convert_pipe handles a file that contains only comments", {
  path <- withr::local_tempfile(fileext = ".R")
  original <- c("# x %>% y", "  # an indented %>% comment", "")
  writeLines(original, path)

  expect_message(
    convert_pipe(path, verbose = TRUE),
    "No pipes to convert"
  )
  expect_equal(readLines(path, warn = FALSE), original)
})

test_that("convert_pipe handles an empty file", {
  path <- withr::local_tempfile(fileext = ".R")
  file.create(path)

  expect_silent(convert_pipe(path, verbose = FALSE))
  expect_equal(readLines(path, warn = FALSE), character())
})

test_that("convert_pipe rejects an unknown direction", {
  path <- withr::local_tempfile(fileext = ".R")
  writeLines("x %>% identity()", path)

  expect_error(
    convert_pipe(path, direction = "sideways"),
    "must be one of"
  )
  expect_equal(readLines(path, warn = FALSE), "x %>% identity()")
})

test_that("convert_pipe aborts when path is missing outside RStudio", {
  expect_error(convert_pipe(path = NULL), "path.*is required")
})
