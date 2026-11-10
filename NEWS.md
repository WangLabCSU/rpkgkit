# rpkgkit 0.2.0 (2026-12-01)

## NEW FEATURES

* The source-code tooling is now backed by Rust through `extendr`: the
  scanning, rewriting and formatting internals of `optimize_rmd_yaml()`,
  `detect_fn_arg_path()`, `detect_lost_glue_brace()`, `rename_func()`,
  `convert_func_syntax()`, `detect_print_and_cat()`,
  `convert_int_literals()`, `convert_pipe()`,
  `detect_unmatched_nocov_marker()` and `use_air_table()`, together with their
  `package_*()` counterparts, delegate to compiled `*_rs()` helpers in
  `src/rust/src/` through the generated `R/extendr-wrappers.R`. The exported R
  functions keep their signatures, and file discovery, progress reporting and
  summary output stay in R; no export was added or removed.
* Source builds now ship the usual `extendr` infrastructure: `configure`,
  `configure.win`, `cleanup`, `cleanup.win`, `src/Makevars.in`,
  `src/Makevars.win.in`, `src/entrypoint.c`, `tools/config.R` and
  `tools/msrv.R` (which checks Cargo/rustc against the declared MSRV). The
  crate depends on `extendr-api` 0.9.0 and `regex`;
  `src/rust/vendor.tar.xz` and `src/rust/vendor-config.toml` allow offline
  builds on CRAN, and `src/rust/deny.toml` configures dependency auditing.

## BREAKING CHANGES

* The package requires R >= 4.2 and `cli` >= 3.0.0. Building from source also
  requires Cargo (Rust's package manager), `rustc` >= 1.65.0 and `xz`, now
  declared in `SystemRequirements`; the shared library is registered with
  `useDynLib(rpkgkit, .registration = TRUE)`.

## DEFUNCT

* `render_rmd()` now aborts with `lifecycle::deprecate_stop()` instead of
  rendering, and its test file was removed.

## INTERNAL CHANGES

* `detect_lost_glue_brace()` and `detect_print_and_cat()` scan raw source text
  with the Rust tokenizer, which understands strings, comments and raw
  strings, instead of walking a `utils::getParseData()` parse table. A parse
  is still run as a guard that rejects unparseable files.
* `use_air_table()` moved from `R/54_use_air_table_.R` to
  `R/54_use_air_table.R`; its internal helpers were renamed from `.at_*` to
  `.uat_*` and now delegate to Rust, while the two `air format` runs remain in
  R.
* The `R-CMD-check` workflow installs a Rust toolchain on Windows, macOS and
  Ubuntu (release and devel), uses the `x86_64-pc-windows-gnu` target on
  Windows and no longer runs the `oldrel-1` to `oldrel-4` jobs. Generated
  `Makevars`, the vendored crate directory and Rust build output are ignored
  by Git and excluded from the source tarball; the VS Code settings point
  rust-analyzer at the crate and drop machine-specific R paths.
* Tests of the migrated helpers now exercise the text-based Rust interface.

## DOCUMENTATION

* The README gained an `extendr` badge and a "Citation" section, and no longer
  lists `flir_fix()`, `air_format()`, `render_rmd()` or `use_hexsticker()` in
  its function tables.
* The `detect_lost_glue_brace()` help page describes the Rust tokenizer, the
  old `.at_*` helper pages were replaced by `man/*_rs.Rd` pages for the
  generated wrappers, and `man/use_air_table.Rd` points at the renamed source
  file.

# rpkgkit 0.1.24 (2026-11-08)

## NEW FEATURES

* Added `use_air_table()` to lay out long `c()` and `list()` calls as
  column-aligned tables with `air` 0.8.0 or newer. A first `air format` run
  leaves every element on its own line; the experimental `# fmt: table`
  directive is then inserted above every call holding more than `min_length`
  elements and the elements are re-flowed so that each row holds `ncol` of them,
  by collapsing the line breaks inside a row or, for a definition that air kept
  on a single line, by splitting it into rows. A second `air format` run pads
  the cells and aligns the columns. Only calls whose elements are all unnamed
  are converted, because air expands named elements one per line whatever the
  directive says; only the outermost call of a statement is converted, because
  air ignores the directive on nested calls; a line ending in a comment is never
  joined with the next one, which would swallow the following element; and a
  call that already carries the directive is left untouched, so the function is
  idempotent. `path = NULL` falls back to the active RStudio document, `air`
  must be on the `PATH` (checked with `check_air_installed()`), and the
  normalized path is returned invisibly.
* Added the standalone `standalone-cli_kable.R` script, which provides
  `cli_kable()` for printing a data frame, a matrix or any object
  `as.data.frame()` accepts as the pipe table of `knitr::kable()`, the layout
  `kableExtra::kable()` shows, with `cli` inline classes instead of Markdown. The
  layout is the one of `kable()`: cells are padded to the column width, columns
  are `padding` spaces wider and at least 3 characters wide, numeric columns are
  rounded to `digits` decimals and right aligned while everything else is left
  aligned, and the `:---|---:` alignment rule follows the headers.
  `header_format` (default `".val"`), `rownames_format` (default `".val"`) and
  `value_format` (default `NULL`) accept a single class, a vector of `ncol(x)`
  classes, or a named vector or named list: named elements style only the columns
  or rows they name and an unnamed element is the fallback of everything that is
  not named, which is how a part of the table is highlighted, while the elements
  of a `value_format` list can be named vectors of row names to style single
  cells. Widths are measured with `cli::ansi_nchar()` after the classes are
  applied, so classes that add visible characters (`{.val}`, `{.code}`) keep the
  columns aligned, and each distinct class is rendered once instead of once per
  cell. `align`, `digits`, `padding`, `sep` and `rule` control the rest of the
  table, an unknown name or an invalid class aborts with `cli::cli_abort()`, and
  the printed lines are returned invisibly.

## DOCUMENTATION

* The `code_convertion` vignette gained a "Lay out long vectors and lists as
  tables" section covering `use_air_table()` and its requirements.
* `use_air_table()` is listed in the README, in both translations under
  `inst/translations/`, and in the `_pkgdown.yml` reference index.
* The package is now spell-checked: `spelling` was added to `Suggests` together
  with `Language: en-US`, `inst/WORDLIST` holds the accepted words, and
  `tests/spelling.R` runs `spelling::spell_check_test()`.
* The `standalone_tools` vignette gained a "Print data frames as kable-style
  tables" section covering `cli_kable()` and the named formats that highlight a
  part of the table, and the package skill (`skills/rpkgkit/`) now lists every
  bundled standalone helper with the functions it provides.

# rpkgkit 0.1.23 (2026-11-01)

## NEW FEATURES

* Added `detect_fn_arg_path()` and `package_fn_arg_path()` to report exported
  functions whose path-like argument defaults to a concrete location, which CRAN
  does not allow. The check is syntactic: the file is parsed, the top-level
  `name <- function(...)` definitions that count as exported are kept, and every
  formal whose name matches `arg_pattern` (default `"path|file|filename"`) is
  reported when its default is not listed in `allow` (default `"NULL"`); an
  argument without a default is always fine. Each hit is printed as
  `file:line:col` with the function and argument name, the source lines and a
  caret marker under `arg = default`. `detect_fn_arg_path()` checks one file and
  falls back to the active document; pass `exports` or `export_patterns` when the
  exports of that file are known, otherwise every top-level function is checked.
  `package_fn_arg_path()` reads the exports from `NAMESPACE` and scans the `.R`
  files under `dirs` (default `"R"`). Both return `TRUE` invisibly when nothing
  needs fixing.
* Added `use_tidy_addin()` to register an exported function in
  `inst/rstudio/addins.dcf`, which makes it available from the RStudio Addins
  menu. The new entry is written above the existing ones, a `Binding` that is
  already registered is never added twice, and the file is written as UTF-8.
  Before writing, the function checks that the path is a package and that the
  function is exported in `NAMESPACE`, reads the function body (from the
  installed package, or from `R/` when the package has not been documented yet),
  and warns when the body calls no `rstudioapi` function or, with
  `Interactive = TRUE`, no `shiny`/`miniUI` function; a non-interactive session
  cannot confirm, so it only reports the warning and continues. It returns the
  path of the dcf file invisibly, or `NULL` when the operation is cancelled.
* `rpkgkit` now registers its own addins in `inst/rstudio/addins.dcf`:
  `package_lost_glue_brace()` and `detect_lost_glue_brace()`,
  `package_print_and_cat()` and `detect_print_and_cat()`,
  `package_fn_arg_path()` and `detect_fn_arg_path()`,
  `package_unmatched_nocov_marker()` and `check_pkgdown_reference()`. The
  `detect_*()` addins run on the active editor, the package-wide ones on the
  current package directory. All of them only report, so none rewrites a file.

## MINOR IMPROVEMENTS

* `detect_lost_glue_brace()` and `detect_print_and_cat()` now print the offending
  source line with cli syntax highlighting. The file is highlighted once and then
  indexed line by line, because a single source line is usually not parseable (a
  continuation such as `x = fn(a, b),` ends with a comma) and
  `cli::code_highlight()` silently returns unparseable input unchanged; when the
  highlighting fails, or when it returns a different number of lines, the plain
  source is printed instead.
* `add_colors_to_cli()` (standalone `colorful_cli.R`) gained `.envir`, defaulting
  to `parent.frame()` and forwarded to the wrapped cli function, so glue-style
  interpolation such as `"Hello, {name}"` is resolved in the caller's environment
  instead of the wrapper's frame.
* `use_zzz()` now resolves `file_name` inside the function body
  (`file_name = NULL` means `<pkg>-package.R`) instead of in the default
  argument, following the `path = NULL` convention of the other `use_*()`
  helpers.

## DOCUMENTATION

* The `code_convertion` vignette gained a "Detect default paths in exported
  arguments" section covering `detect_fn_arg_path()` and
  `package_fn_arg_path()`, and the `pkg_maintain` vignette an "RStudio addins"
  section covering `use_tidy_addin()` and the bundled addins.
* The `standalone_tools` vignette documents the `.envir` argument of the
  `colorful_cli.R` wrapper.
* The README gained an "Addin" section, and `README.md` was regenerated from
  `README.Rmd`. Both translations under `inst/translations/` were brought back in
  sync with the English README: they now share its badge block (the stale
  development-version badge is gone), and carry the "recommended packages" and
  "AI skills" sections and the "Addin" section they were missing.
* The package skill (`skills/rpkgkit/`) covers the new functions and the addin
  workflow.
* Vignette subtitles now report version 0.1.23.

# rpkgkit 0.1.22 (2026-10-28)

## NEW FEATURES

* Added `use_workflow_rust_compatible_check()` to install a
  `.github/workflows/R-CMD-check.yaml` that can build packages shipping Rust
  code. It copies the bundled `R-CMD-Check.yaml` template to the target
  package, creating `.github/workflows/` when needed. Unlike the workflow from
  `usethis::use_github_action("check-standard")`, which only sets up R and
  leaves the runner's default toolchain in place, the template installs Rust
  through `dtolnay/rust-toolchain` and, on Windows, additionally the
  `x86_64-pc-windows-gnu` target: the Windows runner defaults to an MSVC
  toolchain while R and Rtools are GNU based, so the static library produced by
  `cargo` cannot be linked and the build noise makes `R CMD check` report a
  WARNING. The job matrix covers Windows, macOS, Ubuntu release and Ubuntu
  devel with `fail-fast: false`, and sets `R_REMOTES_NO_ERRORS_FROM_WARNINGS` so
  that download noise from `remotes`/`pak` does not surface as a check failure.
  The function aborts when the path is not a package root, when the template is
  missing, or when the workflow file already exists and `overwrite = FALSE`, and
  it returns the created path invisibly. The template follows the official
  `extendr` CI.

## BUG FIXES

* `make_func_arg_explicit()` now accounts for the argument a pipe passes into
  its right-hand side call. The piped-in value already fills the function's
  first formal, so the arguments written in the call are matched one formal
  later: `x %>% stringr::str_remove("Merc")` becomes
  `x %>% stringr::str_remove(pattern = "Merc")`, where it previously claimed
  `string` and pushed `Merc` onto `pattern`. Placeholders are honoured too: a
  `.` anywhere in a magrittr right-hand side (`%>%`, `%<>%`, `%T>%`) cancels
  the leading injection, because the piped value is substituted at `.` instead
  of being inserted first, and a `_` in a native pipe (`|>`) makes the value
  fill the formal it is attached to, so `x |> lm(y ~ z, data = _)` becomes
  `x |> lm(formula = y ~ z, data = _)`. Symbols that merely start with a dot,
  such as the `.data` pronoun and `..1`, are not mistaken for the placeholder.
  A comment between a pipe and its right-hand side no longer hides the call
  from the transformation.

# rpkgkit 0.1.21 (2026-10-19)

## NEW FEATURES

* Added `detect_unmatched_nocov_marker()` and
  `package_unmatched_nocov_marker()` to check the `# nocov start` / `# nocov end`
  markers of a package. Detection is purely textual, so a marker hidden inside a
  string literal or a roxygen comment is reported too, which is intentional.
  Every marker is located by line and column, and a file may hold at most one
  start and one end, so the two counts must match: the second and later marker
  of each kind is reported, a start or an end without a counterpart is reported,
  and an end placed before the start is reported (an end later on the same line
  is accepted). An unclosed `# nocov start` is an error rather than a note,
  because `covr::package_coverage()` aborts on such a range with a "range start
  but only range ends" message. `package_unmatched_nocov_marker()` scans `R/` by
  default and takes `dirs` for anything else. Every problem is printed with its
  line and column, the source line and a caret marker under the offending
  comment, so the fix is left to the user; the verdict is returned invisibly.
* Added `get_positron_version()` to report the version of the Positron IDE. It
  first reads the `POSITRON_VERSION` environment variable that Positron sets for
  its R sessions (`POSITRON_LONG_VERSION`, which includes the build number, when
  `long = TRUE`), then falls back to the `.ps.positron_version()` helper
  injected by the IDE, and finally to the `positron --version` command-line
  tool. When none of them is available it returns `NA_character_`, so the
  function is safe to call outside Positron.
* Added `check_sysdeps()` to verify that the system development dependencies a
  package needs at build time are installed. It detects the package manager in
  use (`dpkg`, `rpm`, `pacman`, `apk` or `brew`, plus `winget`, `choco` and
  `scoop` on Windows), or takes it from `manager`, queries each dependency with
  that manager, and reports every hit and miss with cli, ending with a
  ready-to-paste install command for the missing ones. A dependency may list
  alternatives as `"a|b"`: it counts as installed when any alternative is, and
  the first one is used in the install hint. On Linux the manager is read from
  `/etc/os-release` before falling back to whichever manager is on the `PATH`,
  `dpkg` is queried through `dpkg-query`, and the suggested command drops `sudo`
  when R runs as root. With `deps = NULL` it checks the built-in list of graphics
  and font libraries (`freetype`, `libjpeg`, `libpng`, `libtiff`, `libwebp`,
  `harfbuzz`, `fribidi`, `fontconfig`) under the names used by that package
  manager; there is no built-in list for the Windows managers, so `deps` must be
  supplied for them. The result is returned invisibly as a named logical vector
  carrying the `"manager"` and, when something is missing, `"install_cmd"`
  attributes, and `verbose = FALSE` makes the check silent.
* Added `check_standalone()` to verify that a custom standalone file follows the
  layout consumed by `usethis::use_standalone()`. It checks three points: the
  `# ---` header (the required `repo`, `file`, `last-updated` and `license`
  slots, plus the optional `imports` slot, and the format of each value), that
  every documented function carries `@noRd`, and that a `# nocov start` marker
  precedes all functions. Findings are printed in the style of
  `devtools::check()` and the counts are returned invisibly as
  `list(error = , warning = , note = )`; an error in a check point skips the
  remaining ones, while warnings and notes never stop the run.

## MINOR IMPROVEMENTS

* `use_vendor()` now routes the files it is given by language instead of
  assuming R: `.R` files still go to `R/vendor-<pkg>.R`, `.c` files to
  `src/vendor-<pkg>.c`, `.cpp` files to `src/vendor-<pkg>.cpp`, and `.rs` files
  to `src/rust/src/vendor-<pkg>.rs`. A file given without a directory component
  is looked up in the conventional directory of its language (`R/`, `src/` or
  `src/rust/src/`), and all generated files share the same attribution header
  and per-file separators, with `//` as the comment prefix for the compiled
  sources.
* `package_convert_int_literals()` gained an `exclude` argument listing the file
  names to skip, matched case-insensitively against the base name. It defaults
  to `c("RcppExports.R", "extendr-wrappers.R")`, so the wrappers written by
  `Rcpp::compileAttributes()` and `rextendr::document()` are left alone, and
  `NULL` (or `character()`) restores the previous behaviour of processing every
  file.
* `GLOBAL_RBUILDIGNORE_PATTERN` and `PERMISSIVE_LICENSE` are now internal
  constants instead of exported objects, so packages extending rpkgkit can no
  longer pick them up with `::`. Both are gone from the pkgdown reference index,
  and `GLOBAL_RBUILDIGNORE_PATTERN` no longer has a help page of its own.
* The version-bumper action now keeps a Rust crate version in sync: when the
  package ships `src/rust/Cargo.toml`, the `version` key of its `[package]` table
  is rewritten together with the R package version, under the same `NEWS.md`
  guard, while the rest of the manifest is left untouched. Only `[package]` is
  inspected, so dependency `version` keys are never changed, and manifests
  without a literal version (e.g. `version.workspace = true`) are skipped. The
  commit step now stages only the files that exist.

## DEPRECATED

* `news_md_check()` is deprecated and now warns on every call.

## DOCUMENTATION

* The `pkg_maintain` vignette gained a "Check system dependencies" section
  covering `check_sysdeps()` and a "Detect the Positron version" section
  covering `get_positron_version()`.
* The `standalone_tools` vignette gained a "Validate the standalone file layout"
  section covering `check_standalone()`.
* Vignette subtitles now report version 0.1.21.
* The README now notes that active-file detection in Positron requires Positron
  2026.10.1 or later.

# rpkgkit 0.1.20 (2026-10-15)

## NEW FEATURES

* Added `optimize_rmd_yaml()` to enrich the YAML header of one `README.Rmd` or
  vignette from the package DESCRIPTION: title, author, date, language, an
  enriched `output` block and, for vignettes, the `VignetteIndexEntry`. A
  field that still holds its usethis default value (an "Untitled" title, a bare
  `output: rmarkdown::html_vignette`) is replaced, a field you changed is kept,
  and user `output` options are merged on top of the enriched defaults.
  `package_optimize_rmd_yaml()` applies the same logic to `README.Rmd` and
  every `.Rmd` under `vignettes/`. Both accept `extra`, `extra_readme` and
  `extra_vignette` for adding custom fields such as `params` or `bibliography`.
* Added `use_clangd()` to write a `.clangd` configuration file that wires up
  system R, `Rcpp`, `RcppEigen`, and `RcppArmadillo` include paths. If `path`
  is an R package root, an additional `If:` block disables clangd's background
  indexing for the `R/` source directory, and `.clangd` is added to
  `.Rbuildignore`. The `include` argument lets users pass any custom package
  names whose `include/` directory should be added; packages that are not
  installed are skipped with a warning.
* Added the standalone `standalone-cli_table.R` script, which provides
  `cli_table()` and `cli_table_oneline()` for printing cli-styled frequency
  tables of a vector, on two aligned lines or on a single `header: count` line.
* Added the standalone `standalone-make_arg_validator.R` script, which provides
  `make_arg_validator()`, a factory that turns an unquoted block of checks and
  coercions written in terms of argument names into a reusable validator
  returning the validated arguments as a named list.

## MINOR IMPROVEMENTS

* The standalone CLI helpers `add_caller_to_cli()`
  (`standalone-caller_cli.R`), `add_colors_to_cli()` and
  `create_colorful_cli_env()` (`standalone-colorful_cli.R`), and
  `add_timestamp_to_cli()` and `create_ts_cli_env()` (`standalone-ts_cli.R`)
  now validate their arguments: `cli_func` must be a function and the
  `cli_functions` / `cli_func` vector of `create_*_cli_env()` must be a
  character vector, otherwise the call aborts with a cli error naming the
  argument instead of failing later with a cryptic one.
* Calls inside these standalone helpers now pass their arguments by name
  (e.g. `sys.call(which = ...)`, `do.call(what = ..., args = ...)`).
* The version-bumper action now refuses to ship a release without a changelog
  entry: before writing anything it compares the version it is about to set
  with the highest version documented in `NEWS.md` and skips the bump (with a
  warning) when the new version is higher. When `NEWS.md` is missing or holds
  no version heading, the check is bypassed with a warning.

## DOCUMENTATION

* The `README.Rmd` and vignette YAML headers were enriched with
  `optimize_rmd_yaml()`, so the vignettes now carry a subtitle with the package
  version, an author, a date, a `lang`, a richer `output` block (table of
  contents, numbered sections, figure captions) and RStudio `editor_options`.
* The README badge block now shows the R-universe version badge; the
  development-version and last-commit badges were removed.
* In the `news` vignette, the section about the package startup message is
  titled "A startup message" instead of "A spinner startup message" and its
  chunk no longer echoes the message.
* The `pkg_maintain` vignette gained a "Configure the clangd language server"
  section, and the `readme_and_doc` vignette an "Enrich Rmd YAML headers"
  section covering `optimize_rmd_yaml()` and `package_optimize_rmd_yaml()`,
  including the `extra`, `extra_readme` and `extra_vignette` arguments.
* The `standalone_tools` vignette documents the new `cli_table` and
  `make_arg_validator` scripts, and its examples now run as labelled,
  unevaluated knitr chunks with trimmed `inquire_standalone()` output.

# rpkgkit 0.1.19 (2026-10-08)

## NEW FEATURES

* Added `convert_pipe()` and `package_convert_pipe()` to switch pipe operators
  between the tidyverse pipe `%>%` and the base pipe `|>`. Strings, comments,
  and raw strings are left unchanged, as are the placeholder pipe `%<>%` and
  the exposition pipe `%$%`.
* `rename_func()` gains a `num_to_word` argument that expands digit
  abbreviations in function names into words, defaulting to
  `c("for" = 4, "to" = 2)`. With the default mapping `list2env()` becomes
  `list_to_env()` and `wait4result()` becomes `wait_for_result()`, and the
  expanded words are formatted following the `style` argument, e.g.
  `list2env()` becomes `listToEnv()` under `style = "camelCase"`. The argument
  accepts a named vector, `NULL`, or `FALSE`; any other input is an error. Only
  digit runs present in the mapping are expanded, so identifiers such as
  `scale_x_log10()` are left untouched.

## MINOR IMPROVEMENTS

* `make_func_call_explicit()`, `package_func_call_explicit()`, and
  `add_double_colons()` no longer truncate function names that contain digits.
  Function calls such as `r2dtable()` and `scale_x_log10()` were matched only
  from their longest digit-free suffix (`r2dtable()` was treated as `dtable()`),
  which either produced invalid namespacing or triggered a spurious
  "Couldn't find packages exporting" warning.
* Added pattern detection for exported datasets, e.g., `starwars` from `dplyr` will be
  detected.
* Faster `make_func_arg_explicit()` and
  `package_func_arg_explicit()`: large files are now planned several times
  faster, because the parse table is indexed once and child nodes are looked up
  in constant time instead of being rescanned for every node. Planning a whole
  package therefore no longer grows quadratically with its size.

# rpkgkit 0.1.18

## BUG FIXES

* `convert_int_literals()` and `package_convert_int_literals()` no longer
  rewrite the exponent of a numeric literal such as `1e-3` / `1E-3`, which
  previously produced invalid code like `1e-3L`.

## MINOR IMPROVEMENTS

* `check_air_installed()` now offers to install `air` in interactive sessions
  when it is missing, skipping the prompt during tests. On macOS it now uses
  the official installer script instead of Homebrew or `uv`.
* The package startup message now reports the load time (e.g. `loaded [12.34 ms]`)
  instead of showing a progress spinner, and the same template is used by
  `use_zzz()`.

# rpkgkit 0.1.17 (2026-9-22)

## NEW FEATURES

* Added `badge_to_readme()` to insert a Markdown badge into the badges block of
  `README.Rmd` or `README.md`.
* Added exported `GLOBAL_RBUILDIGNORE_PATTERN` and `PERMISSIVE_LICENSE`
  constants for customizing package-maintenance workflows.

## BUG FIXES

* `add_global_gitgnore()` now correctly updates a package specified with an
  absolute path.
* `use_vendor()` now adds only people with an `aut` or `cre` role to
  `Authors@R`.
* `package_convert_int_literals()` now skips automatically generated
  `RcppExports.R` files, which should not be edited manually.

## MINOR IMPROVEMENTS

* `add_global_rbuildignore()` now supports supplying custom patterns and
  replacing its default pattern set.
* `use_vendor()` records vendored-code authors as contributors and copyright
  holders, rather than package authors.
* The version-bumper action now updates development-version badges before
  committing a release version. Its version commits now run CI before test
  branch synchronization.

## DOCUMENTATION

* Added pkgdown articles for the package vignettes and reorganized the README
  around the package website guides.

# rpkgkit 0.1.16

## MINOR IMPROVEMENTS

* Refactored `detect_*` and `package_*` functions.
* Test-branch synchronization now runs only after `R-CMD-check.yaml` succeeds
  for a push to `main` or `master`, and syncs the exact checked commit.

# rpkgkit 0.1.15

## BUG FIXES

* `convert_int_literals()`, `package_convert_int_literals()`, and
  `convert_func_syntax()` now forward `...` to `rlang::check_dots_empty0()`.
  Previously the call was made without `...`, so the documented "`...` must be
  empty" check was a no-op and extra arguments were silently ignored.

# rpkgkit 0.1.14 (2026-09-14)

## NEW FEATURES

* Added `use_bugreports()` — sets the `BugReports` field of a package's
  `DESCRIPTION` file, defaulting to the GitHub issues page detected from
  the `git` remote.
* Added `use_url()` — sets the `URL` field of a package's `DESCRIPTION`
  file, defaulting to the GitHub repository detected from the `git` remote,
  with an optional pkgdown website URL.

# rpkgkit 0.1.13 (2026-08-13)

## BUG FIXES

* `make_func_call_explicit()` (and `add_double_colons()`) no longer add `::`
  to function calls inside comments or roxygen2 documentation. Comments
  (including `#'` roxygen2 lines and trailing comments) are now left
  untouched.

## MINOR IMPROVEMENTS

* Updated standalone `colorful_cli`.
* Beautified `use_zzz` with a spinner loading animation.

# rpkgkit 0.1.12 (2026-07-26)

## NEW FEATURES

* Added `open_cffinit()` — opens the CFF initializer in a browser to generate
  `CITATION.cff` files.

## MINOR IMPROVEMENTS

* Removed redundant dependency `standalone-purrr` in `standalone-args_to_func.R`.
* Beautified the changelog format in standalone files created by
  `add_changelog_in_standalone()`.
* Added community files (CONTRIBUTING.md, SUPPORT.md, issue template).

## DOCUMENTATION

* Fixed an error in examples of `filter_args_for_func()` in
  `standalone-args_to_func.R`.

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

* Changed default file name created by `use_zzz()` to <pkg></pkg>-package.R
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
