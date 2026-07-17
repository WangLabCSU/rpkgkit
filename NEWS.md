# rpkgkit 0.1.11 (2026-07-17)

## BUG FIXES

* Fixed documentation


# rpkgkit 0.1.10 (2026-07-15)

## BUG FIXES

* Fixed bug when deparsing multiline code in `convert_nonascii_code()`

# rpkgkit 0.1.9 (2026-07-14)

## MINOR IMPROVEMENTS

* Updated `use_vendor()` to make it fully comply standalone header format


## NEW FEATURES

* Added `use_workflow_test_branch()`, which can create a test branch for maintaining R pkg. This branch will sync

* Added `convert_noascii_code()` to convert non-ascii code to ascii code, complying with CRAN requirements

## BUG FIXES

* `add_changelog_in_standalone()`: Fixed a bug when retrieving `Changelog` badge


# rpkgkit v0.1.8 (2026-07-12)

## BUG FIXES

* Fixed dots checking error in `browse_standalone()`

* Fixed `.gitignore` not found error in `vendor-pkgdev.R`, this bug is from source code of `pkgdev`


# rpkgkit 0.1.7 (2026-07-02)

## BUG FIXES

* Fixed timestamp updating bug in `add_changelog_in_standalone()` when modifying `vendor-*.R`


## NEW FEATURES

* Added `use_r_v4.1.0()`


# rpkgkit 0.1.6 (2026-07-01)

## MINOR IMPROVEMENTS

* Made `path = "."` to `path = NULL` because of CRAN requirements


# rpkgkit 0.1.5 (2026-06-30)

## MINOR IMPROVEMENTS

* Added 'Last-updated','Version','Imports' in `use_vendor()`. Relevant files are also updated.


# rpkgkit 0.1.4 (2026-06-29)

## MINOR IMPROVEMENTS

* Added `%||%` function in `use_zzz()`


# rpkgkit 0.1.3 (2026-06-29)

## BUG FIXES

* Fixed ignorance of `make_func_arg_explicit()` when resolving complex R syntax


## MINOR IMPROVEMENTS

* Made `use_zzz()` compatible with `usethis`

* Added cov ignorance in `use_zzz()`


# rpkgkit 0.1.2 (2026-06-29)

## NEW FEATURES

* Added `convert_func_syntax()`


## MINOR IMPROVEMENTS

* Changed default file name created by `use_zzz()` to <pkg>-package.R

* Bug fix in `use_workflow_version_update()`

# rpkgkit 0.1.1 (2026-06-27)

## DEPRECATED

* Removed unused packages in Suggests


## BUG FIXES

* Fixed quotes in action


## DOCUMENTATION

* change unicode character to raw int for checking


## MINOR IMPROVEMENTS

* make `check_pkgdown_reference()` easy to copy

* Fixed lints


## NEW FEATURES

* Added `package_*`, some package-wise functions

* Added `make_func_arg_explicit()`

* Imported `add_global_gitignore` from pkgdev, under license MIT

* Added `add_global_rbuildignore()` to supplement `.Rbuildignore` with common build-exclusion patterns

* Added `use_vendor()`,`use_multilanguage_readme()`


# rpkgkit 0.1.0 (2026-06-25)

## MINOR IMPROVEMENTS

* typescript-source action update for `use_workflow_version_update()`


## BUG FIXES

* Fix path bug in `render_rmd()`

## DOCUMENTATION

* Fix documentation and examples to meet CRAN requirements


## NEW FEATURES

* Added `use_zzz()` for easier zzz.R management

* Bump verion to v0.1


# rpkgkit 0.0.7 (2026-06-17)

## MINOR IMPROVEMENTS

* Added basic color support to `news_md_show()`

* Added dependency, description and nocov tag in `create_standalone()`

* Fixed pattern detection of `detect_lost_glue_brace()` when resolving contexts with more than one lines. Added more detailed info in output


# rpkgkit 0.0.6 (2026-06-11)

## NEW FEATURES

* Added use_workflow_version_updater(), providing a github action to auto-update pkg version and tag.


# rpkgkit 0.0.5 (2026-06-03)

## MINOR IMPROVEMENTS

* Add more options for changelog type in NEWS.md

* Add more tests


## NEW FEATURES

* Added browse_standalone() to inquire all available standalone R files across github

* Added `rename_func` to change the naming style of functions


# rpkgkit 0.0.4 (2026-06-02)

## NEW FEATURES

* Added `detect_lost_glue_brace`


## MINOR IMPROVEMENTS

* Made `news_md_add_entry` vectorized

* Made `inquire_standalone` more explicit

* Made `use_hexsticker` operate on README.Rmd. Added `detect_lost_glue_brace`


# rpkgkit 0.0.3 (2026-05-23)

## MINOR IMPROVEMENTS

* Add tests to most functions

