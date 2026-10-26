# Changelog

## rpkgkit 0.1.21 (2026-10-19)

### NEW FEATURES

- Added
  [`detect_unmatched_nocov_marker()`](https://wanglabcsu.github.io/rpkgkit/reference/detect_unmatched_nocov_marker.md)
  and
  [`package_unmatched_nocov_marker()`](https://wanglabcsu.github.io/rpkgkit/reference/detect_unmatched_nocov_marker.md)
  to check the `# nocov start` / `# nocov end` markers of a package.
  Detection is purely textual, so a marker hidden inside a string
  literal or a roxygen comment is reported too, which is intentional.
  Every marker is located by line and column, and a file may hold at
  most one start and one end, so the two counts must match: the second
  and later marker of each kind is reported, a start or an end without a
  counterpart is reported, and an end placed before the start is
  reported (an end later on the same line is accepted). An unclosed
  `# nocov start` is an error rather than a note, because
  `covr::package_coverage()` aborts on such a range with a “range start
  but only range ends” message.
  [`package_unmatched_nocov_marker()`](https://wanglabcsu.github.io/rpkgkit/reference/detect_unmatched_nocov_marker.md)
  scans `R/` by default and takes `dirs` for anything else. Every
  problem is printed with its line and column, the source line and a
  caret marker under the offending comment, so the fix is left to the
  user; the verdict is returned invisibly.
- Added
  [`get_positron_version()`](https://wanglabcsu.github.io/rpkgkit/reference/get_positron_version.md)
  to report the version of the Positron IDE. It first reads the
  `POSITRON_VERSION` environment variable that Positron sets for its R
  sessions (`POSITRON_LONG_VERSION`, which includes the build number,
  when `long = TRUE`), then falls back to the `.ps.positron_version()`
  helper injected by the IDE, and finally to the `positron --version`
  command-line tool. When none of them is available it returns
  `NA_character_`, so the function is safe to call outside Positron.
- Added
  [`check_sysdeps()`](https://wanglabcsu.github.io/rpkgkit/reference/check_sysdeps.md)
  to verify that the system development dependencies a package needs at
  build time are installed. It detects the package manager in use
  (`dpkg`, `rpm`, `pacman`, `apk` or `brew`, plus `winget`, `choco` and
  `scoop` on Windows), or takes it from `manager`, queries each
  dependency with that manager, and reports every hit and miss with cli,
  ending with a ready-to-paste install command for the missing ones. A
  dependency may list alternatives as `"a|b"`: it counts as installed
  when any alternative is, and the first one is used in the install
  hint. On Linux the manager is read from `/etc/os-release` before
  falling back to whichever manager is on the `PATH`, `dpkg` is queried
  through `dpkg-query`, and the suggested command drops `sudo` when R
  runs as root. With `deps = NULL` it checks the built-in list of
  graphics and font libraries (`freetype`, `libjpeg`, `libpng`,
  `libtiff`, `libwebp`, `harfbuzz`, `fribidi`, `fontconfig`) under the
  names used by that package manager; there is no built-in list for the
  Windows managers, so `deps` must be supplied for them. The result is
  returned invisibly as a named logical vector carrying the `"manager"`
  and, when something is missing, `"install_cmd"` attributes, and
  `verbose = FALSE` makes the check silent.
- Added
  [`check_standalone()`](https://wanglabcsu.github.io/rpkgkit/reference/check_standalone.md)
  to verify that a custom standalone file follows the layout consumed by
  [`usethis::use_standalone()`](https://usethis.r-lib.org/reference/use_standalone.html).
  It checks three points: the `# ---` header (the required `repo`,
  `file`, `last-updated` and `license` slots, plus the optional
  `imports` slot, and the format of each value), that every documented
  function carries `@noRd`, and that a `# nocov start` marker precedes
  all functions. Findings are printed in the style of
  [`devtools::check()`](https://devtools.r-lib.org/reference/check.html)
  and the counts are returned invisibly as
  `list(error = , warning = , note = )`; an error in a check point skips
  the remaining ones, while warnings and notes never stop the run.

### MINOR IMPROVEMENTS

- [`use_vendor()`](https://wanglabcsu.github.io/rpkgkit/reference/use_vendor.md)
  now routes the files it is given by language instead of assuming R:
  `.R` files still go to `R/vendor-<pkg>.R`, `.c` files to
  `src/vendor-<pkg>.c`, `.cpp` files to `src/vendor-<pkg>.cpp`, and
  `.rs` files to `src/rust/src/vendor-<pkg>.rs`. A file given without a
  directory component is looked up in the conventional directory of its
  language (`R/`, `src/` or `src/rust/src/`), and all generated files
  share the same attribution header and per-file separators, with `//`
  as the comment prefix for the compiled sources.
- [`package_convert_int_literals()`](https://wanglabcsu.github.io/rpkgkit/reference/convert_int_literals.md)
  gained an `exclude` argument listing the file names to skip, matched
  case-insensitively against the base name. It defaults to
  `c("RcppExports.R", "extendr-wrappers.R")`, so the wrappers written by
  [`Rcpp::compileAttributes()`](https://rdrr.io/pkg/Rcpp/man/compileAttributes.html)
  and `rextendr::document()` are left alone, and `NULL` (or
  [`character()`](https://rdrr.io/r/base/character.html)) restores the
  previous behaviour of processing every file.
- `GLOBAL_RBUILDIGNORE_PATTERN` and `PERMISSIVE_LICENSE` are now
  internal constants instead of exported objects, so packages extending
  rpkgkit can no longer pick them up with `::`. Both are gone from the
  pkgdown reference index, and `GLOBAL_RBUILDIGNORE_PATTERN` no longer
  has a help page of its own.
- The version-bumper action now keeps a Rust crate version in sync: when
  the package ships `src/rust/Cargo.toml`, the `version` key of its
  `[package]` table is rewritten together with the R package version,
  under the same `NEWS.md` guard, while the rest of the manifest is left
  untouched. Only `[package]` is inspected, so dependency `version` keys
  are never changed, and manifests without a literal version
  (e.g. `version.workspace = true`) are skipped. The commit step now
  stages only the files that exist.

### DEPRECATED

- [`news_md_check()`](https://wanglabcsu.github.io/rpkgkit/reference/news_md.md)
  is deprecated and now warns on every call.

### DOCUMENTATION

- The `pkg_maintain` vignette gained a “Check system dependencies”
  section covering
  [`check_sysdeps()`](https://wanglabcsu.github.io/rpkgkit/reference/check_sysdeps.md)
  and a “Detect the Positron version” section covering
  [`get_positron_version()`](https://wanglabcsu.github.io/rpkgkit/reference/get_positron_version.md).
- The `standalone_tools` vignette gained a “Validate the standalone file
  layout” section covering
  [`check_standalone()`](https://wanglabcsu.github.io/rpkgkit/reference/check_standalone.md).
- Vignette subtitles now report version 0.1.21.
- The README now notes that active-file detection in Positron requires
  Positron 2026.10.1 or later.

## rpkgkit 0.1.20 (2026-10-15)

### NEW FEATURES

- Added
  [`optimize_rmd_yaml()`](https://wanglabcsu.github.io/rpkgkit/reference/optimize_rmd_yaml.md)
  to enrich the YAML header of one `README.Rmd` or vignette from the
  package DESCRIPTION: title, author, date, language, an enriched
  `output` block and, for vignettes, the `VignetteIndexEntry`. A field
  that still holds its usethis default value (an “Untitled” title, a
  bare `output: rmarkdown::html_vignette`) is replaced, a field you
  changed is kept, and user `output` options are merged on top of the
  enriched defaults.
  [`package_optimize_rmd_yaml()`](https://wanglabcsu.github.io/rpkgkit/reference/package_optimize_rmd_yaml.md)
  applies the same logic to `README.Rmd` and every `.Rmd` under
  `vignettes/`. Both accept `extra`, `extra_readme` and `extra_vignette`
  for adding custom fields such as `params` or `bibliography`.
- Added
  [`use_clangd()`](https://wanglabcsu.github.io/rpkgkit/reference/use_clangd.md)
  to write a `.clangd` configuration file that wires up system R,
  `Rcpp`, `RcppEigen`, and `RcppArmadillo` include paths. If `path` is
  an R package root, an additional `If:` block disables clangd’s
  background indexing for the `R/` source directory, and `.clangd` is
  added to `.Rbuildignore`. The `include` argument lets users pass any
  custom package names whose `include/` directory should be added;
  packages that are not installed are skipped with a warning.
- Added the standalone `standalone-cli_table.R` script, which provides
  `cli_table()` and `cli_table_oneline()` for printing cli-styled
  frequency tables of a vector, on two aligned lines or on a single
  `header: count` line.
- Added the standalone `standalone-make_arg_validator.R` script, which
  provides `make_arg_validator()`, a factory that turns an unquoted
  block of checks and coercions written in terms of argument names into
  a reusable validator returning the validated arguments as a named
  list.

### MINOR IMPROVEMENTS

- The standalone CLI helpers `add_caller_to_cli()`
  (`standalone-caller_cli.R`), `add_colors_to_cli()` and
  `create_colorful_cli_env()` (`standalone-colorful_cli.R`), and
  `add_timestamp_to_cli()` and `create_ts_cli_env()`
  (`standalone-ts_cli.R`) now validate their arguments: `cli_func` must
  be a function and the `cli_functions` / `cli_func` vector of
  `create_*_cli_env()` must be a character vector, otherwise the call
  aborts with a cli error naming the argument instead of failing later
  with a cryptic one.
- Calls inside these standalone helpers now pass their arguments by name
  (e.g. `sys.call(which = ...)`, `do.call(what = ..., args = ...)`).
- The version-bumper action now refuses to ship a release without a
  changelog entry: before writing anything it compares the version it is
  about to set with the highest version documented in `NEWS.md` and
  skips the bump (with a warning) when the new version is higher. When
  `NEWS.md` is missing or holds no version heading, the check is
  bypassed with a warning.

### DOCUMENTATION

- The `README.Rmd` and vignette YAML headers were enriched with
  [`optimize_rmd_yaml()`](https://wanglabcsu.github.io/rpkgkit/reference/optimize_rmd_yaml.md),
  so the vignettes now carry a subtitle with the package version, an
  author, a date, a `lang`, a richer `output` block (table of contents,
  numbered sections, figure captions) and RStudio `editor_options`.
- The README badge block now shows the R-universe version badge; the
  development-version and last-commit badges were removed.
- In the `news` vignette, the section about the package startup message
  is titled “A startup message” instead of “A spinner startup message”
  and its chunk no longer echoes the message.
- The `pkg_maintain` vignette gained a “Configure the clangd language
  server” section, and the `readme_and_doc` vignette an “Enrich Rmd YAML
  headers” section covering
  [`optimize_rmd_yaml()`](https://wanglabcsu.github.io/rpkgkit/reference/optimize_rmd_yaml.md)
  and
  [`package_optimize_rmd_yaml()`](https://wanglabcsu.github.io/rpkgkit/reference/package_optimize_rmd_yaml.md),
  including the `extra`, `extra_readme` and `extra_vignette` arguments.
- The `standalone_tools` vignette documents the new `cli_table` and
  `make_arg_validator` scripts, and its examples now run as labelled,
  unevaluated knitr chunks with trimmed
  [`inquire_standalone()`](https://wanglabcsu.github.io/rpkgkit/reference/inquire_standalone.md)
  output.

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
