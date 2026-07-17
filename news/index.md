# Changelog

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
