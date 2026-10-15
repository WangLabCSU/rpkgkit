# Tests for R/10_optimize_rmd_yaml.R and R/10A_package_optimize_rmd_yaml.R

# ---- fixtures --------------------------------------------------------------

# Both desc and yaml are only in Suggests.
skip_if_no_yaml_deps <- function() {
  testthat::skip_if_not_installed("desc")
  testthat::skip_if_not_installed("yaml")
}

# A minimal but valid package directory. Cleanup is registered in the calling
# frame, so the package lives exactly as long as the test.
#
# Both functions report progress with cli alerts, which would otherwise flood
# the test log. They are silenced by default; pass `quiet = FALSE` when the
# messages themselves are the behaviour under test.
local_test_pkg <- function(
  extra_desc = character(),
  quiet = TRUE,
  .local_envir = parent.frame()
) {
  if (quiet) {
    withr::local_options(
      cli.default_handler = function(msg) invisible(),
      .local_envir = .local_envir
    )
  }

  pkg <- withr::local_tempdir(pattern = "testpkg", .local_envir = .local_envir)
  writeLines(
    c(
      "Package: testpkg",
      "Title: A Test Package",
      "Version: 1.0.0",
      'Authors@R: person("Jane", "Doe", email = "jane@example.com", role = c("aut", "cre"))',
      "Description: A test package used for unit tests.",
      "License: MIT",
      "Encoding: UTF-8",
      extra_desc
    ),
    file.path(pkg, "DESCRIPTION")
  )
  pkg
}

# The usethis vignette skeleton ("Untitled" + bare html_vignette output).
ory_vignette_lines <- function(title = "Untitled") {
  c(
    "---",
    sprintf('title: "%s"', title),
    "output: rmarkdown::html_vignette",
    "vignette: >",
    sprintf("  %%\\VignetteIndexEntry{%s}", title),
    "  %\\VignetteEngine{knitr::rmarkdown}",
    "  %\\VignetteEncoding{UTF-8}",
    "---",
    "",
    "```{r}",
    "1 + 1",
    "```"
  )
}

# The usethis README skeleton.
ory_readme_lines <- function() {
  c("---", "output: github_document", "---", "", "Body")
}

# ---- optimize_rmd_yaml(): argument validation ------------------------------

test_that("optimize_rmd_yaml() errors when path cannot be resolved", {
  skip_if_no_yaml_deps()
  local_mocked_bindings(isAvailable = function() FALSE, .package = "rstudioapi")

  expect_error(optimize_rmd_yaml(), "is required")
})

test_that("optimize_rmd_yaml() errors on a missing or non-Rmd path", {
  skip_if_no_yaml_deps()

  expect_error(
    optimize_rmd_yaml(withr::local_tempfile(fileext = ".Rmd")),
    "must be an existing Rmd file",
    fixed = TRUE
  )
  expect_error(
    optimize_rmd_yaml(withr::local_tempfile(fileext = ".R")),
    "must be an existing Rmd file",
    fixed = TRUE
  )
})

test_that("optimize_rmd_yaml() reports a helpful error without a DESCRIPTION", {
  skip_if_no_yaml_deps()
  dir <- withr::local_tempdir()
  rmd <- file.path(dir, "intro.Rmd")
  writeLines(ory_vignette_lines(), rmd)

  expect_error(optimize_rmd_yaml(rmd, type = "vignette"), "package")
})

test_that("optimize_rmd_yaml() uses the active RStudio document", {
  skip_if_no_yaml_deps()
  pkg <- local_test_pkg()
  rmd <- file.path(pkg, "intro.Rmd")
  writeLines(ory_vignette_lines(), rmd)

  local_mocked_bindings(isAvailable = function() TRUE, .package = "rstudioapi")
  local_mocked_bindings(
    getActiveDocumentContext = function() list(path = rmd),
    .package = "rstudioapi"
  )

  expect_true(optimize_rmd_yaml())
  expect_in('title: "Intro"', readLines(rmd))
})

test_that("optimize_rmd_yaml() returns its result invisibly", {
  skip_if_no_yaml_deps()
  pkg <- local_test_pkg()
  rmd <- file.path(pkg, "intro.Rmd")
  writeLines(ory_vignette_lines(), rmd)

  expect_invisible(optimize_rmd_yaml(rmd, type = "vignette"))
})

# ---- .ory_check_extra() ----------------------------------------------------

test_that(".ory_check_extra() accepts NULL, empty and named lists", {
  expect_identical(.ory_check_extra(NULL, "extra"), list())
  expect_identical(.ory_check_extra(list(), "extra"), list())
  expect_identical(.ory_check_extra(list(a = 1), "extra"), list(a = 1))
})

test_that(".ory_check_extra() rejects non-lists and unnamed lists", {
  expect_error(.ory_check_extra("not a list", "extra"), "named list")
  expect_error(.ory_check_extra(list(1, 2), "extra"), "named list")
  expect_error(.ory_check_extra(list(a = 1, 2), "extra"), "named list")
})

# ---- .ory_extra_by_type() --------------------------------------------------

test_that(".ory_extra_by_type() returns the built-in defaults per type", {
  x <- .ory_extra_by_type(NULL, NULL, NULL)

  expect_named(x, c("readme", "vignette"))
  expect_true(x$readme$always_allow_html)
  expect_identical(
    x$readme$editor_options$markdown$wrap,
    "sentence"
  )
  expect_identical(x$vignette$editor_options$chunk_output_type, "console")
  expect_null(x$vignette$always_allow_html)
})

test_that(".ory_extra_by_type() lets user values win and NULL drop a default", {
  x <- .ory_extra_by_type(
    extra = list(lang = "zh-CN"),
    extra_readme = list(always_allow_html = NULL),
    extra_vignette = list(bibliography = "refs.bib")
  )

  expect_identical(x$readme$lang, "zh-CN")
  expect_identical(x$vignette$lang, "zh-CN")
  expect_null(x$readme$always_allow_html)
  expect_null(x$vignette$always_allow_html)
  expect_identical(x$vignette$bibliography, "refs.bib")
  expect_identical(x$vignette$editor_options$chunk_output_type, "console")
})

test_that(".ory_extra_by_type() applies type-specific overrides last", {
  x <- .ory_extra_by_type(
    extra = list(lang = "en-US"),
    extra_readme = NULL,
    extra_vignette = list(lang = "de-DE")
  )

  expect_identical(x$vignette$lang, "de-DE")
  expect_identical(x$readme$lang, "en-US")
})

# ---- .ory_detect_type() ----------------------------------------------------

test_that(".ory_detect_type() recognises README files case-insensitively", {
  expect_identical(.ory_detect_type("README.Rmd"), "readme")
  expect_identical(.ory_detect_type("/tmp/pkg/readme.rmd"), "readme")
  expect_identical(.ory_detect_type("intro.Rmd"), "vignette")
})

# ---- .ory_meta() -----------------------------------------------------------

test_that(".ory_meta() reads metadata from DESCRIPTION", {
  skip_if_no_yaml_deps()
  meta <- .ory_meta(local_test_pkg())

  expect_identical(meta$package, "testpkg")
  expect_identical(meta$title, "A Test Package")
  expect_identical(meta$version, "1.0.0")
  expect_identical(meta$authors, "Jane Doe")
  expect_true(is.na(meta$date))
  expect_identical(meta$lang, "en-US")
})

test_that(".ory_meta() picks up Date and Language fields", {
  skip_if_no_yaml_deps()
  meta <- .ory_meta(
    local_test_pkg(extra_desc = c("Date: 2026-03-01", "Language: zh-CN"))
  )

  expect_identical(meta$date, "2026-03-01")
  expect_identical(meta$lang, "zh-CN")
})

# ---- .ory_get_author_names() -----------------------------------------------

test_that(".ory_get_author_names() keeps aut/cre roles", {
  skip_if_no_yaml_deps()
  d <- desc::desc(file = local_test_pkg())

  expect_identical(.ory_get_author_names(d), "Jane Doe")
})

test_that(".ory_get_author_names() falls back to the Author field", {
  skip_if_no_yaml_deps()
  pkg <- withr::local_tempdir()
  writeLines(
    c(
      "Package: testpkg",
      "Version: 1.0.0",
      "Author: John Smith [aut, cre] <js@example.com>"
    ),
    file.path(pkg, "DESCRIPTION")
  )

  expect_identical(
    .ory_get_author_names(desc::desc(file = pkg)),
    "John Smith"
  )
})

test_that(".ory_get_author_names() ignores people without aut/cre roles", {
  skip_if_no_yaml_deps()
  pkg <- withr::local_tempdir()
  writeLines(
    c(
      "Package: testpkg",
      "Version: 1.0.0",
      'Authors@R: person("Only", "Contributor", role = "ctb")',
      "Author: Fall Back [aut]"
    ),
    file.path(pkg, "DESCRIPTION")
  )

  expect_identical(.ory_get_author_names(desc::desc(file = pkg)), "Fall Back")
})

test_that(".ory_get_author_names() returns NULL without author information", {
  skip_if_no_yaml_deps()
  pkg <- withr::local_tempdir()
  writeLines(
    c("Package: testpkg", "Version: 1.0.0"),
    file.path(pkg, "DESCRIPTION")
  )

  expect_null(.ory_get_author_names(desc::desc(file = pkg)))
})

# ---- .ory_read_rmd() -------------------------------------------------------

test_that(".ory_read_rmd() splits the YAML header from the body", {
  path <- withr::local_tempfile(fileext = ".Rmd")
  writeLines(c("---", "title: x", "---", "", "body"), path)

  rmd <- .ory_read_rmd(path)

  expect_identical(rmd$header, "title: x")
  expect_identical(rmd$body, "body")
  expect_identical(rmd$raw, c("---", "title: x", "---", "", "body"))
})

test_that(".ory_read_rmd() accepts ... as the closing fence", {
  path <- withr::local_tempfile(fileext = ".Rmd")
  writeLines(c("---", "title: x", "...", "body"), path)

  rmd <- .ory_read_rmd(path)

  expect_identical(rmd$header, "title: x")
  expect_identical(rmd$body, "body")
})

test_that(".ory_read_rmd() handles files without a YAML header", {
  path <- withr::local_tempfile(fileext = ".Rmd")
  writeLines(c("hello", "world"), path)

  rmd <- .ory_read_rmd(path)

  expect_length(rmd$header, 0L)
  expect_identical(rmd$body, c("hello", "world"))
})

test_that(".ory_read_rmd() handles an empty header and an empty body", {
  path <- withr::local_tempfile(fileext = ".Rmd")
  writeLines(c("---", "---"), path)

  rmd <- .ory_read_rmd(path)

  expect_length(rmd$header, 0L)
  expect_length(rmd$body, 0L)
})

# ---- .ory_split_chunks() ---------------------------------------------------

test_that(".ory_split_chunks() groups top-level keys with their values", {
  h <- c(
    'title: "x"',
    "author: y",
    "output:",
    "  html_document:",
    "    toc: true"
  )

  chunks <- .ory_split_chunks(h)

  expect_named(chunks, c("title", "author", "output"))
  expect_identical(chunks$title, 'title: "x"')
  expect_identical(
    chunks$output,
    c("output:", "  html_document:", "    toc: true")
  )
})

test_that(".ory_split_chunks() returns an empty list for empty input", {
  expect_identical(.ory_split_chunks(character()), list())
})

test_that(".ory_split_chunks() attaches leading non-key lines to the first key", {
  chunks <- .ory_split_chunks(c("# a comment", "title: x"))

  expect_named(chunks, "title")
  expect_identical(chunks$title, c("# a comment", "title: x"))
})

# ---- .ory_yq() -------------------------------------------------------------

test_that(".ory_yq() double-quotes and escapes scalars", {
  expect_identical(.ory_yq("plain"), '"plain"')
  expect_identical(.ory_yq('he said "hi"'), '"he said \\"hi\\""')
  expect_identical(.ory_yq("a\\b"), '"a\\\\b"')
})

# ---- .ory_emit_yaml() ------------------------------------------------------

test_that(".ory_emit_yaml() writes logicals as true/false", {
  skip_if_no_yaml_deps()

  expect_identical(
    .ory_emit_yaml(list(a = TRUE, b = FALSE)),
    c("a: true", "b: false")
  )
})

# ---- .ory_format_defaults() ------------------------------------------------

test_that(".ory_format_defaults() returns defaults per managed format", {
  expect_identical(
    .ory_format_defaults("rmarkdown::html_vignette"),
    .ory_format_defaults("html_vignette")
  )
  expect_identical(
    .ory_format_defaults("github_document"),
    list(html_preview = FALSE)
  )
  expect_identical(.ory_format_defaults("md_document"), list(variant = "gfm"))
  expect_true(.ory_format_defaults("html_document")$toc_float)
  expect_null(.ory_format_defaults("pdf_document"))
})

# ---- .ory_merge_list() -----------------------------------------------------

test_that(".ory_merge_list() keeps user values and fills in missing ones", {
  out <- .ory_merge_list(
    over = list(html_document = list(toc = FALSE)),
    base = list(
      html_document = list(toc = TRUE, theme = "cosmo"),
      toc_float = TRUE
    )
  )

  expect_false(out$html_document$toc)
  expect_identical(out$html_document$theme, "cosmo")
  expect_true(out$toc_float)
})

# ---- .ory_default_output() -------------------------------------------------

test_that(".ory_default_output() emits the expected block per format", {
  skip_if_no_yaml_deps()

  expect_identical(
    .ory_default_output("readme", "gfm"),
    c("output:", "  md_document:", "    variant: gfm")
  )
  expect_identical(
    .ory_default_output("readme", "github_document"),
    c("output:", "  github_document:", "    html_preview: false")
  )
  expect_in("  html_document:", .ory_default_output("readme", "html"))
  expect_in(
    "  rmarkdown::html_vignette:",
    .ory_default_output("vignette", "gfm")
  )
})

# ---- .ory_optimize_output() ------------------------------------------------

test_that(".ory_optimize_output() never rewrites an !expr output", {
  chunk <- c("output:", "  !expr foo")

  expect_identical(.ory_optimize_output(chunk, "readme"), chunk)
})

test_that(".ory_optimize_output() flags usethis default output formats", {
  expect_null(.ory_optimize_output("output: html_document", "readme"))
  expect_null(.ory_optimize_output("output: github_document", "readme"))
  expect_null(.ory_optimize_output("output: md_document", "readme"))
  expect_null(.ory_optimize_output("output: html_vignette", "vignette"))
  expect_null(
    .ory_optimize_output("output: rmarkdown::html_vignette", "vignette")
  )
})

test_that(".ory_optimize_output() keeps other bare formats untouched", {
  chunk <- "output: pdf_document"

  expect_identical(.ory_optimize_output(chunk, "readme"), chunk)
  expect_identical(.ory_optimize_output(chunk, "vignette"), chunk)
})

test_that(".ory_optimize_output() merges defaults under user options", {
  out <- .ory_optimize_output(
    c("output:", "  html_document:", "    toc: false"),
    "readme"
  )

  expect_identical(
    out,
    c(
      "output:",
      "  html_document:",
      "    toc: false",
      "    toc_float: true",
      "    theme: cosmo",
      "    df_print: paged"
    )
  )
})

test_that(".ory_optimize_output() keeps the original text when nothing changes", {
  chunk <- c("output:", "  md_document:", "    variant: gfm")

  expect_identical(.ory_optimize_output(chunk, "readme"), chunk)
})

test_that(".ory_optimize_output() replaces a 'default' value with options", {
  out <- .ory_optimize_output(
    c("output:", "  github_document: default"),
    "readme"
  )

  expect_identical(
    out,
    c("output:", "  github_document:", "    html_preview: false")
  )
})

test_that(".ory_optimize_output() leaves unmanaged formats alone", {
  chunk <- c("output:", "  pdf_document:", "    toc: true")

  expect_identical(.ory_optimize_output(chunk, "readme"), chunk)
})

# ---- .ory_default_title() --------------------------------------------------

test_that(".ory_default_title() builds titles for README files", {
  skip_if_no_yaml_deps()
  meta <- .ory_meta(local_test_pkg())

  expect_identical(
    .ory_default_title("README.Rmd", "readme", meta),
    "testpkg: A Test Package"
  )

  meta$title <- NA_character_
  expect_identical(.ory_default_title("README.Rmd", "readme", meta), "testpkg")
})

test_that(".ory_default_title() builds titles for vignettes", {
  skip_if_no_yaml_deps()
  meta <- .ory_meta(local_test_pkg())

  expect_identical(.ory_default_title("intro.Rmd", "vignette", meta), "Intro")
  expect_identical(
    .ory_default_title("testpkg.Rmd", "vignette", meta),
    "Introduction to testpkg"
  )
  expect_identical(
    .ory_default_title("my-intro_vignette.Rmd", "vignette", meta),
    "My Intro Vignette"
  )
})

# ---- optimize_rmd_yaml() behaviour -----------------------------------------

test_that("optimize_rmd_yaml() enriches a usethis vignette skeleton", {
  skip_if_no_yaml_deps()
  pkg <- local_test_pkg()
  rmd <- file.path(pkg, "vignettes", "intro.Rmd")
  dir.create(dirname(rmd))
  writeLines(ory_vignette_lines(), rmd)

  expect_true(optimize_rmd_yaml(rmd, type = "vignette"))

  out <- readLines(rmd)
  expect_identical(out[1L], "---")
  expect_in('title: "Intro"', out)
  expect_in('subtitle: "testpkg 1.0.0"', out)
  expect_in('author: "Jane Doe"', out)
  expect_in('date: "`r Sys.Date()`"', out)
  expect_in("lang: en-US", out)
  expect_in("  rmarkdown::html_vignette:", out)
  expect_in("  %\\VignetteIndexEntry{Intro}", out)
  expect_in("editor_options:", out)
  # the body is preserved
  expect_in("1 + 1", out)
})

test_that("optimize_rmd_yaml() is idempotent", {
  skip_if_no_yaml_deps()
  pkg <- local_test_pkg()
  rmd <- file.path(pkg, "intro.Rmd")
  writeLines(ory_vignette_lines(), rmd)

  expect_true(optimize_rmd_yaml(rmd, type = "vignette"))
  first <- readLines(rmd)

  expect_false(optimize_rmd_yaml(rmd, type = "vignette"))
  expect_identical(readLines(rmd), first)
})

test_that("optimize_rmd_yaml() detects README.Rmd automatically", {
  skip_if_no_yaml_deps()
  pkg <- local_test_pkg()
  rmd <- file.path(pkg, "README.Rmd")
  writeLines(ory_readme_lines(), rmd)

  expect_true(optimize_rmd_yaml(rmd))

  out <- readLines(rmd)
  expect_in('title: "testpkg: A Test Package"', out)
  expect_in("always_allow_html: true", out)
  expect_in("  md_document:", out)
  expect_in("    variant: gfm", out)
  expect_false(any(grepl("VignetteIndexEntry", out, fixed = TRUE)))
})

test_that("optimize_rmd_yaml() keeps a user-written title", {
  skip_if_no_yaml_deps()
  pkg <- local_test_pkg()
  rmd <- file.path(pkg, "README.Rmd")
  writeLines(
    c(
      "---",
      'title: "My Great README"',
      "output: github_document",
      "---",
      "",
      "Body"
    ),
    rmd
  )

  optimize_rmd_yaml(rmd)

  expect_in('title: "My Great README"', readLines(rmd))
})

test_that("optimize_rmd_yaml() enriches a header without any fields", {
  skip_if_no_yaml_deps()
  pkg <- local_test_pkg()
  rmd <- file.path(pkg, "intro.Rmd")
  writeLines(c("---", "---", "", "Body"), rmd)

  expect_true(optimize_rmd_yaml(rmd, type = "vignette"))
  expect_in('title: "Intro"', readLines(rmd))
})

test_that("optimize_rmd_yaml() respects readme_format", {
  skip_if_no_yaml_deps()
  pkg <- local_test_pkg()
  rmd <- file.path(pkg, "README.Rmd")
  writeLines(c("---", "output: html_document", "---", "", "Body"), rmd)

  optimize_rmd_yaml(rmd, readme_format = "html")

  out <- readLines(rmd)
  expect_in("  html_document:", out)
  expect_in("    toc_float: true", out)
})

test_that("optimize_rmd_yaml() accepts partial argument values", {
  skip_if_no_yaml_deps()
  pkg <- local_test_pkg()
  rmd <- file.path(pkg, "README.Rmd")
  writeLines(ory_readme_lines(), rmd)

  expect_true(optimize_rmd_yaml(rmd, readme_format = "git"))
  expect_in("  github_document:", readLines(rmd))
})

test_that("optimize_rmd_yaml() supports date = 'desc' and date = 'none'", {
  skip_if_no_yaml_deps()
  pkg <- local_test_pkg(extra_desc = "Date: 2026-03-01")

  rmd_desc <- file.path(pkg, "a.Rmd")
  writeLines(ory_vignette_lines(), rmd_desc)
  optimize_rmd_yaml(rmd_desc, type = "vignette", date = "desc")
  expect_in('date: "2026-03-01"', readLines(rmd_desc))

  rmd_none <- file.path(pkg, "b.Rmd")
  writeLines(ory_vignette_lines(), rmd_none)
  optimize_rmd_yaml(rmd_none, type = "vignette", date = "none")
  expect_false(any(grepl("^date:", readLines(rmd_none))))
})

test_that("optimize_rmd_yaml() picks up a neighbouring .bib file", {
  skip_if_no_yaml_deps()
  pkg <- local_test_pkg()
  writeLines("placeholder", file.path(pkg, "refs.bib"))
  rmd <- file.path(pkg, "intro.Rmd")
  writeLines(ory_vignette_lines(), rmd)

  optimize_rmd_yaml(rmd, type = "vignette")

  out <- readLines(rmd)
  expect_in("bibliography: refs.bib", out)
  expect_in("link-citations: true", out)
})

test_that("optimize_rmd_yaml() merges extra fields and can drop defaults", {
  skip_if_no_yaml_deps()
  pkg <- local_test_pkg()
  rmd <- file.path(pkg, "intro.Rmd")
  writeLines(ory_vignette_lines(), rmd)

  optimize_rmd_yaml(
    rmd,
    type = "vignette",
    extra = list(lang = "zh-CN", editor_options = NULL)
  )

  out <- readLines(rmd)
  expect_in("lang: zh-CN", out)
  expect_false(any(grepl("^editor_options:", out)))
})

test_that("optimize_rmd_yaml() does not overwrite keys already in the header", {
  skip_if_no_yaml_deps()
  pkg <- local_test_pkg()
  rmd <- file.path(pkg, "intro.Rmd")
  writeLines(
    c("---", 'title: "Untitled"', "lang: fr-FR", "---", "", "Body"),
    rmd
  )

  optimize_rmd_yaml(rmd, type = "vignette", extra = list(lang = "de-DE"))

  expect_in("lang: fr-FR", readLines(rmd))
})

test_that("optimize_rmd_yaml() lets extra replace a generated field", {
  skip_if_no_yaml_deps()
  pkg <- local_test_pkg()
  rmd <- file.path(pkg, "intro.Rmd")
  writeLines(ory_vignette_lines(), rmd)

  optimize_rmd_yaml(
    rmd,
    type = "vignette",
    extra = list(date = "1999-01-01")
  )

  out <- readLines(rmd)
  expect_in("date: '1999-01-01'", out)
  expect_false(any(grepl("Sys.Date", out, fixed = TRUE)))
})

test_that("optimize_rmd_yaml() applies extra_readme only to README files", {
  skip_if_no_yaml_deps()
  pkg <- local_test_pkg()
  rmd <- file.path(pkg, "README.Rmd")
  writeLines(ory_readme_lines(), rmd)

  optimize_rmd_yaml(
    rmd,
    extra_readme = list(always_allow_html = NULL),
    extra_vignette = list(bibliography = "x.bib")
  )

  out <- readLines(rmd)
  expect_false(any(grepl("^always_allow_html:", out)))
  expect_false(any(grepl("^bibliography:", out)))
})

test_that("optimize_rmd_yaml() applies extra_vignette only to vignettes", {
  skip_if_no_yaml_deps()
  pkg <- local_test_pkg()
  rmd <- file.path(pkg, "intro.Rmd")
  writeLines(ory_vignette_lines(), rmd)

  optimize_rmd_yaml(
    rmd,
    type = "vignette",
    extra_vignette = list(bibliography = "refs.bib"),
    extra_readme = list(always_allow_html = FALSE)
  )

  out <- readLines(rmd)
  expect_in("bibliography: refs.bib", out)
  expect_false(any(grepl("always_allow_html", out, fixed = TRUE)))
})

test_that("optimize_rmd_yaml() keeps unrelated user fields and the body", {
  skip_if_no_yaml_deps()
  pkg <- local_test_pkg()
  rmd <- file.path(pkg, "intro.Rmd")
  writeLines(
    c(
      "---",
      'title: "Untitled"',
      "params:",
      "  eval: false",
      "---",
      "",
      "# Heading",
      "",
      "Some text."
    ),
    rmd
  )

  optimize_rmd_yaml(rmd, type = "vignette")

  out <- readLines(rmd)
  expect_in("params:", out)
  expect_in("  eval: false", out)
  expect_in("# Heading", out)
  expect_in("Some text.", out)
})

# ---- package_optimize_rmd_yaml() -------------------------------------------

test_that("package_optimize_rmd_yaml() errors when the path is not a package", {
  skip_if_no_yaml_deps()

  expect_error(package_optimize_rmd_yaml(withr::local_tempdir()), "DESCRIPTION")
})

test_that("package_optimize_rmd_yaml() informs when there is nothing to do", {
  skip_if_no_yaml_deps()
  pkg <- local_test_pkg(quiet = FALSE)

  expect_message(
    res <- package_optimize_rmd_yaml(pkg),
    "No README.Rmd"
  )
  expect_identical(res, character())
})

test_that("package_optimize_rmd_yaml() processes README and vignettes", {
  skip_if_no_yaml_deps()
  pkg <- local_test_pkg()
  writeLines(ory_readme_lines(), file.path(pkg, "README.Rmd"))
  dir.create(file.path(pkg, "vignettes"))
  writeLines(ory_vignette_lines(), file.path(pkg, "vignettes", "intro.Rmd"))
  # underscore-prefixed and non-Rmd files must be ignored
  writeLines(
    ory_vignette_lines(title = "Hidden"),
    file.path(pkg, "vignettes", "_hidden.Rmd")
  )
  writeLines("not an rmd", file.path(pkg, "vignettes", "b.R"))

  res <- package_optimize_rmd_yaml(pkg)

  expect_setequal(basename(res), c("README.Rmd", "intro.Rmd"))
  expect_in(
    'title: "Intro"',
    readLines(file.path(pkg, "vignettes", "intro.Rmd"))
  )
  expect_in("always_allow_html: true", readLines(file.path(pkg, "README.Rmd")))
  expect_identical(
    readLines(file.path(pkg, "vignettes", "_hidden.Rmd")),
    ory_vignette_lines(title = "Hidden")
  )
  expect_identical(readLines(file.path(pkg, "vignettes", "b.R")), "not an rmd")
})

test_that("package_optimize_rmd_yaml() honours the readme/vignettes switches", {
  skip_if_no_yaml_deps()
  pkg <- local_test_pkg()
  writeLines(ory_readme_lines(), file.path(pkg, "README.Rmd"))
  dir.create(file.path(pkg, "vignettes"))
  writeLines(ory_vignette_lines(), file.path(pkg, "vignettes", "a.Rmd"))

  res <- package_optimize_rmd_yaml(pkg, vignettes = FALSE)

  expect_identical(basename(res), "README.Rmd")
  expect_identical(
    readLines(file.path(pkg, "vignettes", "a.Rmd")),
    ory_vignette_lines()
  )
})

test_that("package_optimize_rmd_yaml() returns changed paths invisibly", {
  skip_if_no_yaml_deps()
  pkg <- local_test_pkg()
  writeLines(ory_readme_lines(), file.path(pkg, "README.Rmd"))

  expect_invisible(package_optimize_rmd_yaml(pkg))
})
