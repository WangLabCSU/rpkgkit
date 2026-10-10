# Changelog

## rpkgkit 0.1.19 (2026-10-08)

### NEW FEATURES

- Added
  [`convert_pipe()`](https://wanglabcsu.github.io/rpkgkit/reference/convert_pipe.md)
  and
  [`package_convert_pipe()`](https://wanglabcsu.github.io/rpkgkit/reference/convert_pipe.md)
  to switch pipe operators between the tidyverse pipe `%>%` and the base
  pipe `|>`. Strings, comments, and raw strings are left unchanged, as
  are the placeholder pipe `%<>%` and the exposition pipe `%$%`.
- [`rename_func()`](https://wanglabcsu.github.io/rpkgkit/reference/rename_func.md)
  gains a `num_to_word` argument that expands digit abbreviations in
  function names into words, defaulting to `c("for" = 4, "to" = 2)`.
  With the default mapping
  [`list2env()`](https://rdrr.io/r/base/list2env.html) becomes
  `list_to_env()` and `wait4result()` becomes `wait_for_result()`, and
  the expanded words are formatted following the `style` argument, e.g.
  [`list2env()`](https://rdrr.io/r/base/list2env.html) becomes
  `listToEnv()` under `style = "camelCase"`. The argument accepts a
  named vector, `NULL`, or `FALSE`; any other input is an error. Only
  digit runs present in the mapping are expanded, so identifiers such as
  `scale_x_log10()` are left untouched.

### MINOR IMPROVEMENTS

- [`make_func_call_explicit()`](https://wanglabcsu.github.io/rpkgkit/reference/make_func_call_explicit.md),
  [`package_func_call_explicit()`](https://wanglabcsu.github.io/rpkgkit/reference/make_func_call_explicit.md),
  and
  [`add_double_colons()`](https://wanglabcsu.github.io/rpkgkit/reference/add_double_colons.md)
  no longer truncate function names that contain digits. Function calls
  such as [`r2dtable()`](https://rdrr.io/r/stats/r2dtable.html) and
  `scale_x_log10()` were matched only from their longest digit-free
  suffix ([`r2dtable()`](https://rdrr.io/r/stats/r2dtable.html) was
  treated as `dtable()`), which either produced invalid namespacing or
  triggered a spurious “Couldn’t find packages exporting” warning.
- Added pattern detection for exported datasets, e.g., `starwars` from
  `dplyr` will be detected.
- Faster
  [`make_func_arg_explicit()`](https://wanglabcsu.github.io/rpkgkit/reference/make_func_arg_explicit.md)
  and
  [`package_func_arg_explicit()`](https://wanglabcsu.github.io/rpkgkit/reference/make_func_arg_explicit.md):
  large files are now planned several times faster, because the parse
  table is indexed once and child nodes are looked up in constant time
  instead of being rescanned for every node. Planning a whole package
  therefore no longer grows quadratically with its size.

## rpkgkit 0.1.18

### BUG FIXES

- [`convert_int_literals()`](https://wanglabcsu.github.io/rpkgkit/reference/convert_int_literals.md)
  and
  [`package_convert_int_literals()`](https://wanglabcsu.github.io/rpkgkit/reference/convert_int_literals.md)
  no longer rewrite the exponent of a numeric literal such as `1e-3` /
  `1E-3`, which previously produced invalid code like `1e-3L`.

### MINOR IMPROVEMENTS

- [`check_air_installed()`](https://wanglabcsu.github.io/rpkgkit/reference/check_air_installed.md)
  now offers to install `air` in interactive sessions when it is
  missing, skipping the prompt during tests. On macOS it now uses the
  official installer script instead of Homebrew or `uv`.
- The package startup message now reports the load time
  (e.g. `loaded [12.34 ms]`) instead of showing a progress spinner, and
  the same template is used by
  [`use_zzz()`](https://wanglabcsu.github.io/rpkgkit/reference/use_zzz.md).

## rpkgkit 0.1.17 (2026-9-22)

### NEW FEATURES

- Added
  [`badge_to_readme()`](https://wanglabcsu.github.io/rpkgkit/reference/badge_to_readme.md)
  to insert a Markdown badge into the badges block of `README.Rmd` or
  `README.md`.
- Added exported `GLOBAL_RBUILDIGNORE_PATTERN` and `PERMISSIVE_LICENSE`
  constants for customizing package-maintenance workflows.

### BUG FIXES

- [`add_global_gitgnore()`](https://wanglabcsu.github.io/rpkgkit/reference/add_global_gitgnore.md)
  now correctly updates a package specified with an absolute path.
- [`use_vendor()`](https://wanglabcsu.github.io/rpkgkit/reference/use_vendor.md)
  now adds only people with an `aut` or `cre` role to `Authors@R`.
- [`package_convert_int_literals()`](https://wanglabcsu.github.io/rpkgkit/reference/convert_int_literals.md)
  now skips automatically generated `RcppExports.R` files, which should
  not be edited manually.

### MINOR IMPROVEMENTS

- [`add_global_rbuildignore()`](https://wanglabcsu.github.io/rpkgkit/reference/add_global_rbuildignore.md)
  now supports supplying custom patterns and replacing its default
  pattern set.
- [`use_vendor()`](https://wanglabcsu.github.io/rpkgkit/reference/use_vendor.md)
  records vendored-code authors as contributors and copyright holders,
  rather than package authors.
- The version-bumper action now updates development-version badges
  before committing a release version. Its version commits now run CI
  before test branch synchronization.

### DOCUMENTATION

- Added pkgdown articles for the package vignettes and reorganized the
  README around the package website guides.

## rpkgkit 0.1.16

### MINOR IMPROVEMENTS

- Refactored `detect_*` and `package_*` functions.
- Test-branch synchronization now runs only after `R-CMD-check.yaml`
  succeeds for a push to `main` or `master`, and syncs the exact checked
  commit.

## rpkgkit 0.1.15

### BUG FIXES

- [`convert_int_literals()`](https://wanglabcsu.github.io/rpkgkit/reference/convert_int_literals.md),
  [`package_convert_int_literals()`](https://wanglabcsu.github.io/rpkgkit/reference/convert_int_literals.md),
  and
  [`convert_func_syntax()`](https://wanglabcsu.github.io/rpkgkit/reference/convert_func_syntax.md)
  now forward `...` to
  [`rlang::check_dots_empty0()`](https://rlang.r-lib.org/reference/check_dots_empty0.html).
  Previously the call was made without `...`, so the documented “`...`
  must be empty” check was a no-op and extra arguments were silently
  ignored.

## rpkgkit 0.1.14 (2026-09-14)

### NEW FEATURES

- Added
  [`use_bugreports()`](https://wanglabcsu.github.io/rpkgkit/reference/use_bugreports.md)
  — sets the `BugReports` field of a package’s `DESCRIPTION` file,
  defaulting to the GitHub issues page detected from the `git` remote.
- Added
  [`use_url()`](https://wanglabcsu.github.io/rpkgkit/reference/use_url.md)
  — sets the `URL` field of a package’s `DESCRIPTION` file, defaulting
  to the GitHub repository detected from the `git` remote, with an
  optional pkgdown website URL.

## rpkgkit 0.1.13 (2026-08-13)

### BUG FIXES

- [`make_func_call_explicit()`](https://wanglabcsu.github.io/rpkgkit/reference/make_func_call_explicit.md)
  (and
  [`add_double_colons()`](https://wanglabcsu.github.io/rpkgkit/reference/add_double_colons.md))
  no longer add `::` to function calls inside comments or roxygen2
  documentation. Comments (including `#'` roxygen2 lines and trailing
  comments) are now left untouched.

### MINOR IMPROVEMENTS

- Updated standalone `colorful_cli`.
- Beautified `use_zzz` with a spinner loading animation.

## rpkgkit 0.1.12 (2026-07-26)

### NEW FEATURES

- Added
  [`open_cffinit()`](https://wanglabcsu.github.io/rpkgkit/reference/open_cffinit.md)
  — opens the CFF initializer in a browser to generate `CITATION.cff`
  files.

### MINOR IMPROVEMENTS

- Removed redundant dependency `standalone-purrr` in
  `standalone-args_to_func.R`.
- Beautified the changelog format in standalone files created by
  [`add_changelog_in_standalone()`](https://wanglabcsu.github.io/rpkgkit/reference/add_changelog_in_standalone.md).
- Added community files (CONTRIBUTING.md, SUPPORT.md, issue template).

### DOCUMENTATION

- Fixed an error in examples of `filter_args_for_func()` in
  `standalone-args_to_func.R`.

## rpkgkit 0.1.11 (2026-07-17)

### BUG FIXES

- Fixed documentation

## rpkgkit 0.1.10 (2026-07-15)

### BUG FIXES

- Fixed bug when deparsing multiline code in
  [`convert_nonascii_code()`](https://wanglabcsu.github.io/rpkgkit/reference/convert_nonascii_code.md)

## rpkgkit 0.1.9 (2026-07-14)

### MINOR IMPROVEMENTS

- Updated
  [`use_vendor()`](https://wanglabcsu.github.io/rpkgkit/reference/use_vendor.md)
  to make it fully comply standalone header format

### NEW FEATURES

- Added
  [`use_workflow_test_branch()`](https://wanglabcsu.github.io/rpkgkit/reference/use_workflow_test_branch.md),
  which can create a test branch for maintaining R pkg. This branch will
  sync

- Added `convert_noascii_code()` to convert non-ascii code to ascii
  code, complying with CRAN requirements

### BUG FIXES

- [`add_changelog_in_standalone()`](https://wanglabcsu.github.io/rpkgkit/reference/add_changelog_in_standalone.md):
  Fixed a bug when retrieving `Changelog` badge

## rpkgkit v0.1.8 (2026-07-12)

### BUG FIXES

- Fixed dots checking error in
  [`browse_standalone()`](https://wanglabcsu.github.io/rpkgkit/reference/browse_standalone.md)

- Fixed `.gitignore` not found error in `vendor-pkgdev.R`, this bug is
  from source code of `pkgdev`

## rpkgkit 0.1.7 (2026-07-02)

CRAN release: 2026-07-21

### BUG FIXES

- Fixed timestamp updating bug in
  [`add_changelog_in_standalone()`](https://wanglabcsu.github.io/rpkgkit/reference/add_changelog_in_standalone.md)
  when modifying `vendor-*.R`

### NEW FEATURES

- Added
  [`use_r_v4.1.0()`](https://wanglabcsu.github.io/rpkgkit/reference/use_r_v4.1.0.md)

## rpkgkit 0.1.6 (2026-07-01)

### MINOR IMPROVEMENTS

- Made `path = "."` to `path = NULL` because of CRAN requirements

## rpkgkit 0.1.5 (2026-06-30)

### MINOR IMPROVEMENTS

- Added ‘Last-updated’,‘Version’,‘Imports’ in
  [`use_vendor()`](https://wanglabcsu.github.io/rpkgkit/reference/use_vendor.md).
  Relevant files are also updated.

## rpkgkit 0.1.4 (2026-06-29)

### MINOR IMPROVEMENTS

- Added `%||%` function in
  [`use_zzz()`](https://wanglabcsu.github.io/rpkgkit/reference/use_zzz.md)

## rpkgkit 0.1.3 (2026-06-29)

### BUG FIXES

- Fixed ignorance of
  [`make_func_arg_explicit()`](https://wanglabcsu.github.io/rpkgkit/reference/make_func_arg_explicit.md)
  when resolving complex R syntax

### MINOR IMPROVEMENTS

- Made
  [`use_zzz()`](https://wanglabcsu.github.io/rpkgkit/reference/use_zzz.md)
  compatible with `usethis`

- Added cov ignorance in
  [`use_zzz()`](https://wanglabcsu.github.io/rpkgkit/reference/use_zzz.md)

## rpkgkit 0.1.2 (2026-06-29)

### NEW FEATURES

- Added
  [`convert_func_syntax()`](https://wanglabcsu.github.io/rpkgkit/reference/convert_func_syntax.md)

### MINOR IMPROVEMENTS

- Changed default file name created by
  [`use_zzz()`](https://wanglabcsu.github.io/rpkgkit/reference/use_zzz.md)
  to -package.R

- Bug fix in
  [`use_workflow_version_update()`](https://wanglabcsu.github.io/rpkgkit/reference/use_workflow_version_update.md)

## rpkgkit 0.1.1 (2026-06-27)

### DEPRECATED

- Removed unused packages in Suggests

### BUG FIXES

- Fixed quotes in action

### DOCUMENTATION

- change unicode character to raw int for checking

### MINOR IMPROVEMENTS

- make
  [`check_pkgdown_reference()`](https://wanglabcsu.github.io/rpkgkit/reference/check_pkgdown_reference.md)
  easy to copy

- Fixed lints

### NEW FEATURES

- Added `package_*`, some package-wise functions

- Added
  [`make_func_arg_explicit()`](https://wanglabcsu.github.io/rpkgkit/reference/make_func_arg_explicit.md)

- Imported `add_global_gitignore` from pkgdev, under license MIT

- Added
  [`add_global_rbuildignore()`](https://wanglabcsu.github.io/rpkgkit/reference/add_global_rbuildignore.md)
  to supplement `.Rbuildignore` with common build-exclusion patterns

- Added
  [`use_vendor()`](https://wanglabcsu.github.io/rpkgkit/reference/use_vendor.md),[`use_multilanguage_readme()`](https://wanglabcsu.github.io/rpkgkit/reference/use_multilanguage_readme.md)

## rpkgkit 0.1.0 (2026-06-25)

### MINOR IMPROVEMENTS

- typescript-source action update for
  [`use_workflow_version_update()`](https://wanglabcsu.github.io/rpkgkit/reference/use_workflow_version_update.md)

### BUG FIXES

- Fix path bug in
  [`render_rmd()`](https://wanglabcsu.github.io/rpkgkit/reference/render_rmd.md)

### DOCUMENTATION

- Fix documentation and examples to meet CRAN requirements

### NEW FEATURES

- Added
  [`use_zzz()`](https://wanglabcsu.github.io/rpkgkit/reference/use_zzz.md)
  for easier zzz.R management

- Bump verion to v0.1

## rpkgkit 0.0.7 (2026-06-17)

### MINOR IMPROVEMENTS

- Added basic color support to
  [`news_md_show()`](https://wanglabcsu.github.io/rpkgkit/reference/news_md.md)

- Added dependency, description and nocov tag in
  [`create_standalone()`](https://wanglabcsu.github.io/rpkgkit/reference/create_standalone.md)

- Fixed pattern detection of
  [`detect_lost_glue_brace()`](https://wanglabcsu.github.io/rpkgkit/reference/detect_lost_glue_brace.md)
  when resolving contexts with more than one lines. Added more detailed
  info in output

## rpkgkit 0.0.6 (2026-06-11)

### NEW FEATURES

- Added use_workflow_version_updater(), providing a github action to
  auto-update pkg version and tag.

## rpkgkit 0.0.5 (2026-06-03)

### MINOR IMPROVEMENTS

- Add more options for changelog type in NEWS.md

- Add more tests

### NEW FEATURES

- Added browse_standalone() to inquire all available standalone R files
  across github

- Added `rename_func` to change the naming style of functions

## rpkgkit 0.0.4 (2026-06-02)

### NEW FEATURES

- Added `detect_lost_glue_brace`

### MINOR IMPROVEMENTS

- Made `news_md_add_entry` vectorized

- Made `inquire_standalone` more explicit

- Made `use_hexsticker` operate on README.Rmd. Added
  `detect_lost_glue_brace`

## rpkgkit 0.0.3 (2026-05-23)

### MINOR IMPROVEMENTS

- Add tests to most functions
