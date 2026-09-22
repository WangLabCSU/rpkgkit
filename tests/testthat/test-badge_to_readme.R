test_that("badge_to_readme inserts a badge into the README.Rmd badges block", {
  path <- withr::local_tempdir()
  writeLines("Package: testpkg", file.path(path, "DESCRIPTION"))
  readme <- file.path(path, "README.Rmd")
  writeLines(
    c(
      "# Test package",
      "<!-- badges: start -->",
      "[![Existing](https://example.com/existing.svg)](https://example.com)",
      "<!-- badges: end -->",
      "",
      "Package text"
    ),
    readme
  )

  result <- suppressMessages(withVisible(
    badge_to_readme(
      "[![New](https://example.com/new.svg)](https://example.com)",
      path
    )
  ))

  expect_identical(result$value, readme)
  expect_false(result$visible)
  expect_equal(
    readLines(readme, warn = FALSE),
    c(
      "# Test package",
      "<!-- badges: start -->",
      "[![Existing](https://example.com/existing.svg)](https://example.com)",
      "[![New](https://example.com/new.svg)](https://example.com)",
      "<!-- badges: end -->",
      "",
      "Package text"
    )
  )
})

test_that("badge_to_readme uses README.md when README.Rmd is absent", {
  path <- withr::local_tempdir()
  writeLines("Package: testpkg", file.path(path, "DESCRIPTION"))
  readme <- file.path(path, "README.md")
  writeLines(
    c("<!-- badges: start -->", "<!-- badges: end -->"),
    readme
  )

  result <- suppressMessages(badge_to_readme("[![New](new.svg)](new)", path))

  expect_identical(result, readme)
  expect_equal(
    readLines(readme, warn = FALSE),
    c(
      "<!-- badges: start -->",
      "[![New](new.svg)](new)",
      "<!-- badges: end -->"
    )
  )
})

test_that("badge_to_readme prefers README.Rmd when both README files exist", {
  path <- withr::local_tempdir()
  writeLines("Package: testpkg", file.path(path, "DESCRIPTION"))
  rmd <- file.path(path, "README.Rmd")
  md <- file.path(path, "README.md")
  writeLines(c("<!-- badges: start -->", "<!-- badges: end -->"), rmd)
  writeLines(c("<!-- badges: start -->", "<!-- badges: end -->"), md)

  suppressMessages(badge_to_readme(
    "[![Preferred](preferred.svg)](preferred)",
    path
  ))

  expect_equal(
    readLines(rmd, warn = FALSE),
    c(
      "<!-- badges: start -->",
      "[![Preferred](preferred.svg)](preferred)",
      "<!-- badges: end -->"
    )
  )
  expect_equal(
    readLines(md, warn = FALSE),
    c("<!-- badges: start -->", "<!-- badges: end -->")
  )
})

test_that("badge_to_readme does not add an existing badge twice", {
  path <- withr::local_tempdir()
  writeLines("Package: testpkg", file.path(path, "DESCRIPTION"))
  readme <- file.path(path, "README.md")
  writeLines(
    c("<!-- badges: start -->", "badge", "<!-- badges: end -->"),
    readme
  )

  expect_message(
    result <- badge_to_readme("badge", path),
    "Badge already present"
  )

  expect_identical(result, readme)
  expect_equal(
    readLines(readme, warn = FALSE),
    c("<!-- badges: start -->", "badge", "<!-- badges: end -->")
  )
})

test_that("badge_to_readme validates the package root and badge", {
  expect_snapshot(error = TRUE, badge_to_readme("badge", "not-a-package"))

  path <- withr::local_tempdir()
  writeLines("Package: testpkg", file.path(path, "DESCRIPTION"))
  writeLines(
    c("<!-- badges: start -->", "<!-- badges: end -->"),
    file.path(path, "README.md")
  )

  expect_snapshot(error = TRUE, badge_to_readme("", path))
  expect_snapshot(error = TRUE, badge_to_readme(c("one", "two"), path))
  expect_snapshot(error = TRUE, badge_to_readme("badge", path, unused = TRUE))
})

test_that("badge_to_readme requires a README with one valid badges block", {
  path <- withr::local_tempdir()
  writeLines("Package: testpkg", file.path(path, "DESCRIPTION"))
  withr::local_dir(path)

  expect_snapshot(error = TRUE, badge_to_readme("badge", "."))

  readme <- file.path(path, "README.md")
  writeLines(c("<!-- badges: start -->", "Content"), readme)
  expect_snapshot(error = TRUE, badge_to_readme("badge", "."))

  writeLines(
    c(
      "<!-- badges: start -->",
      "<!-- badges: end -->",
      "<!-- badges: start -->",
      "<!-- badges: end -->"
    ),
    readme
  )
  expect_snapshot(error = TRUE, badge_to_readme("badge", "."))
})
