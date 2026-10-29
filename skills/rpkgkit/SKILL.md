---
name: rpkgkit
description: Use rpkgkit functions to create and maintain R packages when the task involves qualifying package calls with pkg::, detecting CRAN-unsafe print()/cat(), lost glue braces or unmatched # nocov start / # nocov end markers, modernizing R syntax (base/magrittr pipes, integer L suffix, non-ASCII literals, \\( lambdas, knitr chunk headers), editing or displaying NEWS.md, creating r-lib standalone files, configuring DESCRIPTION fields, .Rbuildignore/.clangd/zzz.R, vendoring upstream code, generating GitHub Actions workflows (R-CMD-check including Rust/extendr builds, version bump, branch sync), or generating multilingual README translations and badges.
---

# rpkgkit

## Overview

`rpkgkit` is an R package of development utilities. This skill maps a user's
package-maintenance request to the right `rpkgkit` call, its arguments, and the
order in which to run the calls.

Full signatures and per-function notes live in
`references/function-reference.md`; read it before calling a function whose
arguments are not obvious.

## When to use

Use this skill when the request touches R package housekeeping:

- Making function calls explicit (`pkg::fun()`) or arguments explicit (`arg = value`)
- Detecting or fixing CRAN-unsafe `print()`/`cat()`, or lost `{}` in `glue`/`cli`
- Checking the `# nocov start` / `# nocov end` markers of a file or package
- Converting pipes, `function()` ↔ `\(`, integer literals, non-ASCII literals, Rmd chunk headers
- Adding, showing, or formatting `NEWS.md` entries
- Creating or validating r-lib style `standalone-*.R` files
- Adding DESCRIPTION fields (`URL`, `BugReports`, `Depends: R (>= ...)`), `.clangd`, `(pkg)-package.R`
- Vendoring upstream code, or generating `.Rbuildignore` patterns
- Multilingual README translations, AI-translation badges, README badges, Rmd YAML headers
- Formatting with air/flir, or checking `_pkgdown.yml` coverage

Do not use rpkgkit for general R programming questions, package installation, or
CRAN submission mechanics beyond the functions listed here.

## Conventions that apply to every function

1. **`path = NULL` means "resolve it yourself".** In an interactive IDE session
   (RStudio or Positron 2026.10.1+) the active source document is used; otherwise
   the working directory is used. Pass `path` explicitly in scripts, tests, or CI.
2. **Single-file vs whole-package pairs.** `detect_*`, `make_*`, `convert_int_literals`,
   `convert_pipe`, `optimize_rmd_yaml` act on one file. The matching `package_*`
   function walks the package. `dirs` defaults to `c("R", "tests/testthat")` for
   `package_lost_glue_brace()` and `package_print_and_cat()`, and to `"R"` for
   `package_unmatched_nocov_marker()` and the converters; pass `dirs` to widen it.
   Choose the package-level function whenever more than one file is involved.
3. **Results are reported with `cli` and returned invisibly.** Wrap calls in
   `invisible()`-tolerant code; do not assert on a visible return value. Use
   `verbose = TRUE` (default on most functions) to keep the report.
4. **Mutating functions write files in place.** Commit or inspect `git diff` after
   running converters and fixers. `detect_*` functions are read-only unless `fix = TRUE`.
5. **`open = rlang::is_interactive()`** on file-creating functions opens the new file;
   set `open = FALSE` in non-interactive automation.
6. Several functions require Suggests packages (`usethis`, `desc`, `gh`, `dplyr`,
   `flir`, `yaml`, `httr2`). Call `rlang::check_installed()` before use in scripts.

## Workflow: qualify and clean a package's code

Order matters — qualify calls first, then detect issues, then modernize syntax:

```r
rpkgkit::package_func_call_explicit()   # add pkg:: to unqualified calls
rpkgkit::package_func_arg_explicit()    # add arg = for non-leading formals
rpkgkit::package_lost_glue_brace()      # report lost {} in glue/cli
rpkgkit::package_print_and_cat(fix = TRUE)  # print()/cat() -> message()
rpkgkit::package_unmatched_nocov_marker()   # report unmatched nocov markers
rpkgkit::package_convert_pipe(direction = "to_base")
rpkgkit::package_convert_int_literals()
rpkgkit::air_format()                   # format last
```

Run `package_*` converters one at a time and inspect the diff in between; they all
rewrite files on disk. Format only after all conversions are done.

## Workflow: NEWS.md

```r
rpkgkit::news_md_add_entry("Add `foo()`.")                       # current dev version
rpkgkit::news_md_add_entry("Fix crash.", category = "BUG FIXES")
rpkgkit::news_md_add_entry(c("one", "two"), contributor = "Jane Doe")
rpkgkit::news_md_show(version = "0.1.0")
```

`news_md_add_entry()` creates the version section and category when missing; with
`open_section = TRUE` it inserts into an already-open section instead of starting a
new one. `news_md_check()` is deprecated and errors — do not call it.

## Workflow: standalone files

```r
rpkgkit::create_standalone("my-helper")     # writes R/standalone-my-helper.R in a package
rpkgkit::check_standalone()                # validate header, @noRd, # nocov start
rpkgkit::add_changelog_in_standalone(description = "Initial version")
rpkgkit::update_time_in_standalone()
```

The header carries `last modified`, license, imports, dependency, description and a
changelog block. `inquire_standalone(owner, repo)` lists candidates in a specific
repository; `browse_standalone()` searches GitHub-wide (requires `gh`).

## Workflow: package infrastructure

```r
rpkgkit::use_url()                 # URL from git remote
rpkgkit::use_bugreports()
rpkgkit::use_r_v4.1.0()            # Depends: R (>= 4.1.0)
rpkgkit::use_zzz()                 # R/<pkg>-package.R from template
rpkgkit::use_clangd()              # .clangd for Rcpp projects
rpkgkit::add_global_rbuildignore() # curated .Rbuildignore patterns
rpkgkit::add_global_gitgnore()
rpkgkit::use_vendor("pkg")         # vendor upstream source into inst/vendor/
rpkgkit::use_workflow_version_update()        # version bump workflow + local action
rpkgkit::use_workflow_rust_compatible_check() # R-CMD-check that builds Rust code
rpkgkit::use_workflow_test_branch()           # sync main -> test after check passes
rpkgkit::check_pkgdown_reference() # every export present in _pkgdown.yml
```

The three `use_workflow_*()` functions copy bundled templates from `inst/actions/`
into `.github/`, create the directories they need, abort instead of overwriting
unless `overwrite = TRUE`, and return the written path invisibly. Use
`use_workflow_rust_compatible_check()` rather than
`usethis::use_github_action("check-standard")` for `extendr`/`rextendr`
packages: it installs a Rust toolchain and the `x86_64-pc-windows-gnu` target,
without which the MSVC default cannot link against Rtools and the check ends in a
WARNING.

## Workflow: README, badges, Rmd

```r
rpkgkit::use_multilanguage_readme(lang = "zh-cn")
rpkgkit::badge_translated_by_ai("zh-cn")   # returns badge markdown
rpkgkit::badge_to_readme(badge)
rpkgkit::package_optimize_rmd_yaml()       # enrich README.Rmd + vignettes/*.Rmd YAML
rpkgkit::render_rmd()                      # render to Markdown
```

## Deprecated or do not use

- `news_md_check()` — `deprecate_stop()`, always errors.
- `use_hexsticker()` — `deprecate_stop()`, use `usethis::use_logo()`.
- `test_included` argument of `package_lost_glue_brace()` and
  `package_print_and_cat()` — deprecated; use `dirs =`.
- `add_double_colons()` — operates on a code string/selection; prefer
  `make_func_call_explicit()` for files.

## Resources

- `references/function-reference.md` — all exported functions with signatures,
  source files, and behavioural notes, grouped by task.
