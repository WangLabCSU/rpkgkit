# rpkgkit function reference

Signatures are copied from source. `path = NULL` resolves to the active IDE
document, falling back to the working directory. Source files are under `R/`.

## Standalone scripts

| Function | File | Notes |
|---|---|---|
| `inquire_standalone(owner, repo, ...)` | `60_inquire_standalone.R` | Lists `standalone-*.R` under `R/` of a given GitHub repo. Requires `gh`. |
| `create_standalone(standalone_name = NULL, path = NULL, standalone_head = list(license = "https://unlicense.org", imports = NULL, dependency = NULL, description = "This file provides ..."), open = rlang::is_interactive(), ...)` | `61_create_standalone.R` | Writes `R/standalone-<name>.R` with the r-lib YAML header when inside a package. |
| `update_time_in_standalone(path = NULL)` | `62_update_time_in_standalone.R` | Refreshes the `last modified` date; `path` may be a file or a directory. |
| `add_changelog_in_standalone(path = NULL, description = NULL, date = NULL)` | `63_add_changelog_in_standalone.R` | Inserts or updates one changelog entry in the header block. |
| `browse_standalone(per_page = 100L, limit = 200L, ...)` | `64_browse_standalone.R` | GitHub code search across repositories. Requires `gh`, `dplyr`. |
| `check_standalone(path = NULL, ...)` | `65_check_standalone.R` | Validates header fields, `@noRd`, `# nocov start/end`; reports in `devtools::check()` style. |

## Bundled standalone helpers

Internal scripts under `R/standalone-*.R` (`@noRd`, not exported). Vendor one into
another package with
`usethis::use_standalone("WangLabCSU/rpkgkit", "<script name>")`; they are
self-contained and `cli`-only unless the table says otherwise.

| Script | Functions | Notes |
|---|---|---|
| `args_to_func` | `match_func_to_args()`, `filter_args_for_func()`, `get_func_args()` | Match a list of arguments to compatible functions, and keep only the arguments a function accepts. |
| `caller_cli` | `get_caller_name()`, `add_caller_to_cli()`, `create_caller_cli_env()` | Decorate a `cli` function so its output names the caller. |
| `cli_kable` | `cli_kable(x, header_format = ".val", rownames_format = ".val", value_format = NULL, ...)` | Print a data frame or matrix as the pipe table of `knitr::kable()` (`kableExtra::kable()` layout) with `cli` inline classes. Named formats style only the named columns or rows and an unnamed element is the fallback; a `value_format` list element may be a named vector of row names, for per-cell styling. `align`, `digits`, `padding`, `sep` and `rule` control the rest of the layout. Returns the printed lines invisibly. |
| `cli_table` | `cli_table()`, `cli_table_oneline()` | Print a `cli`-styled frequency table of a vector, on two aligned lines or on one `header: count` line. |
| `colorful_cli` | `add_colors_to_cli()`, `create_colorful_cli_env()`, `generate_color_code()`, `generate_color_theme()` | Wrap `cli` functions with a custom colour theme. |
| `make_arg_validator` | `make_arg_validator()` | Turn an unquoted block of checks and coercions into a reusable argument validator. |
| `match_arg` | `match_arg()` | Exact, partial and default fallback argument matching. |
| `ts_cli` | `add_timestamp_to_cli()`, `create_ts_cli_env()` | Prefix `cli` output with a timestamp. |

## Code qualification and detection (single file)

| Function | File | Notes |
|---|---|---|
| `make_func_call_explicit(path = NULL, use_packages = current_packages(), ignore_functions = imported_functions(), ...)` | `13_make_func_call_explicit.R` | Adds `pkg::` to unqualified calls. |
| `make_func_arg_explicit(path = NULL, skip_functions = NULL, ...)` | `19_make_func_arg_explicit.R` | Inserts `arg =` using parse data; leaves all other text untouched. |
| `detect_lost_glue_brace(path = NULL, verbose = TRUE, ...)` | `14_detect_lost_glue_brace.R` | Finds unbalanced `{}` inside `glue()`/`cli` expressions. |
| `detect_print_and_cat(path = NULL, fix = FALSE, pattern_fn_names = DEFAULT_PATTERN_FN_NAMES, replace_default_pattern = FALSE, include_s3 = TRUE, include_refs = FALSE, verbose = TRUE, ...)` | `18_detect_print_and_cat.R` | Reports CRAN-unsafe `print()`/`cat()`; `fix = TRUE` rewrites them to `message()`. |
| `detect_fn_arg_path(path = NULL, arg_pattern = "path\|file\|filename", exports = NULL, export_patterns = character(), allow = "NULL", verbose = TRUE, ...)` | `11_detect_fn_arg_path.R` | Reports exported `name <- function()` formals whose name matches `arg_pattern` and whose default is not in `allow`; shared Rd page with `package_fn_arg_path()`. |
| `detect_unmatched_nocov_marker(path = NULL, verbose = TRUE, ...)` | `24_detect_unmatched_nocov_marker.R` | Textual scan of the `# nocov start` / `# nocov end` comments (strings and roxygen lines included by design). Reports every marker after the first of its kind, a start or an end without a counterpart, and an end before the start, each with line and column plus a caret. An unclosed start matters because `covr::package_coverage()` aborts on it. Read-only. |
| `rename_func(path = NULL, style = c("snake_case", "camelCase", "PascalCase", "google"), num_to_word = c(for = 4, to = 2), ...)` | `15_rename_func.R` | Renames function definitions in one file. |
| `convert_func_syntax(path = NULL, direction = c("to_lambda", "to_explicit"), ...)` | `16_convert_func_syntax.R` | `function()` ⇄ `\(`. |
| `convert_int_literals(path = NULL, verbose = TRUE, ...)` | `20_convert_int_literals.R` | Appends `L` to integer literals. |
| `convert_pipe(path = NULL, direction = c("to_base", "to_magrittr"), verbose = TRUE, ...)` | `21_convert_pipe.R` | `%>%` ⇄ `|>`. |
| `convert_knitr_chunk_header(path = NULL, ...)` | `23_convert_knitr_chunk_header.R` | Normalizes Rmd chunk headers; `path` may be a package root or a file. |
| `convert_nonascii_code(code, ..., reverse = FALSE, overwrite = NULL)` | `22_convert_nonascii_code.R` | Converts non-ASCII string content ⇄ `\uXXXX`. First argument is `code` (text or file), not `path`. |
| `optimize_rmd_yaml(path = NULL, type = c("auto", "readme", "vignette"), readme_format = c("gfm", "github_document", "html"), date = c("auto", "desc", "none"), extra = NULL, extra_readme = NULL, extra_vignette = NULL)` | `10_optimize_rmd_yaml.R` | Enriches one Rmd YAML header from DESCRIPTION. |

## Code qualification and detection (whole package)

These share an Rd page with their single-file counterpart (`@rdname`/`@describeIn`).

| Function | File | Notes |
|---|---|---|
| `package_func_call_explicit(path = NULL, use_packages = current_packages(), ignore_functions = imported_functions(), ...)` | `13A_package_func_call_explicit.R` | Walks every `R/*.R` file. |
| `package_func_arg_explicit(path = NULL, skip_functions = NULL, ...)` | `19A_package_func_arg_explicit.R` | Walks every `R/*.R` file. |
| `package_lost_glue_brace(path = NULL, dirs = c("R", "tests/testthat"), test_included = lifecycle::deprecated(), ...)` | `14A_package_lost_glue_brace.R` | Multi-directory scan; reports file and line. |
| `package_print_and_cat(path = NULL, dirs = c("R", "tests/testthat"), test_included = lifecycle::deprecated(), fix = FALSE, ...)` | `18A_package_print_and_cat.R` | Multi-directory scan, optional fix. |
| `package_fn_arg_path(path = NULL, arg_pattern = "path\|file\|filename", allow = "NULL", dirs = "R", verbose = TRUE, ...)` | `11A_package_fn_arg_path.R` | Reads exports from `NAMESPACE` (including `exportPattern`), then scans `dirs`; `...` must be empty. |
| `package_unmatched_nocov_marker(path = NULL, dirs = "R", verbose = TRUE)` | `24A_package_unmatched_nocov_marker.R` | Same rules as the single-file version, reported per file with `file: line` and the caret hint. Scans only `R/` unless `dirs` says otherwise; no `test_included` argument. Read-only. |
| `package_convert_int_literals(path = NULL, dirs = "R", recursive = TRUE, exclude = c("RcppExports.R", "extendr-wrappers.R"), ...)` | `20A_package_convert_int_literals.R` | Batch conversion. |
| `package_convert_pipe(path = NULL, direction = c("to_base", "to_magrittr"), dirs = "R", recursive = TRUE, ...)` | `21A_package_convert_pipe.R` | Batch conversion. |
| `package_optimize_rmd_yaml(path = NULL, readme = TRUE, vignettes = TRUE, readme_format = c("gfm", "github_document", "html"), date = c("auto", "desc", "none"), extra = NULL, extra_readme = NULL, extra_vignette = NULL)` | `10A_package_optimize_rmd_yaml.R` | Independent Rd page; applies to README.Rmd and `vignettes/*.Rmd`. |

## Formatting and rendering

| Function | File | Notes |
|---|---|---|
| `air_format(path = NULL, ...)` | `70_air_format.R` | Formats with `air`. |
| `check_air_installed()` | `70_air_format.R` | Aborts with the per-OS `air` install command when the binary is not on the `PATH`; called by `use_air_table()`. |
| `use_air_table(path = NULL, ncol = 3L, min_length = 12L, marker = "# fmt: table", ...)` | `54_use_air_table_.R` | Runs `air format`, inserts `marker` above every unnamed `c()`/`list()` call with more than `min_length` elements, re-flows the elements `ncol` per row, then formats again so the cells are aligned. Skips calls nested inside another call, calls that already carry `marker` (idempotent) and line breaks that would swallow a trailing comment. Requires `air` 0.8.0+. Returns the normalized path invisibly. |
| `flir_fix(path = NULL, ...)` | `71_flir_fix.R` | Dispatches to `flir::fix()`, `fix_package()`, or `fix_dir()` based on the path. Single entry point for flir. |
| `render_rmd(path = NULL, output_format = "md_document", ...)` | `72_render_rmd.R` | Renders Rmd/R to Markdown. |

## NEWS.md

`news_md_add_entry()`, `news_md_show()` share `man/news_md.Rd`.

| Function | File | Notes |
|---|---|---|
| `news_md_add_entry(entry, version = NULL, category = "NEW FEATURES", contributor = NULL, path = NULL, date = NULL, open_section = TRUE)` | `33_news_md_add_entry.R` | Main entry point; vectorized `entry`, creates missing version/category. |
| `news_md_show(path = NULL, version = NULL, max_versions = NULL)` | `32_news_md_show.R` | Prints NEWS.md for the requested versions. |
| `news_md_check(path = NULL, strict = FALSE, verbose = TRUE)` | `31_news_md_check.R` | Deprecated: `lifecycle::deprecate_stop()`. |

## Package configuration and infrastructure

| Function | File | Notes |
|---|---|---|
| `add_global_rbuildignore(..., pattern = GLOBAL_RBUILDIGNORE_PATTERN, replace_default = FALSE, path = NULL)` | `17_add_global_rbuildignore.R` | Appends curated `.Rbuildignore` patterns; existing ones are skipped; `...` takes extra regexes. |
| `add_global_gitgnore(pkg = NULL)` | `vendor-pkgdev.R` | Vendored pkgdev helper; the argument is `pkg`, not `path`. |
| `use_r_v4.1.0(path = NULL, ...)` | `46_use_r_v4.1.0.R` | Adds `R (>= 4.1.0)` to `Depends`. |
| `use_url(url = NULL, pkgdown_url = NULL, path = NULL, ...)` | `49_use_url.R` | Writes `URL`; defaults to the git remote. |
| `use_bugreports(url = NULL, path = NULL, ...)` | `50_use_bugreports.R` | Writes `BugReports`. |
| `use_clangd(path = NULL, include = c("Rcpp", "RcppEigen", "RcppArmadillo"), overwrite = FALSE, open = rlang::is_interactive(), ...)` | `51_use_clangd.R` | Creates `.clangd`. |
| `use_zzz(path = NULL, file_name = NULL, overwrite = FALSE, open = rlang::is_interactive(), ...)` | `45_use_zzz.R` | Creates `R/<pkg>-package.R` from `inst/R_template/zzz_template.R`; `file_name = NULL` resolves to `<pkg>-package.R` inside the function. The template reports the load time with `cli::cli_progress_step()` in `.onLoad()` and `cli::cli_process_done()` in `.onAttach()`, and the function adds `cli` to `Imports`. |
| `use_tidy_addin(fn_name, desc, Interactive = FALSE, path = NULL)` | `53_use_tidy_addin.R` | Prepend a record to `inst/rstudio/addins.dcf`; requires the function to be exported in `NAMESPACE`, skips an already registered `Binding`, warns when the body calls no `rstudioapi` (or, with `Interactive = TRUE`, no `shiny`/`miniUI`) function. Requires `desc`. |
| `use_vendor(pkg, ..., branch = "main", path = NULL)` | `43_use_vendor.R` | Vendors upstream source into `inst/vendor/`, writes provenance and license, records vendor version and imports. |
| `use_workflow_version_update(path = NULL, overwrite = FALSE, color = "blue", ...)` | `42_use_workflow_version_update.R` | Generates the version bump GitHub Actions workflow. |
| `use_workflow_test_branch(path = NULL, overwrite = FALSE)` | `42B_use_workflow_test_branch.R` | Generates the `main` → `test` sync workflow. |
| `use_workflow_rust_compatible_check(path = NULL, overwrite = FALSE)` | `42C_use_workflow_rust_compatible_check.R` | Copies `inst/actions/rust_compatible_check/R-CMD-Check.yaml` to `.github/workflows/R-CMD-check.yaml`; installs Rust via `dtolnay/rust-toolchain` plus the `x86_64-pc-windows-gnu` target on Windows, because the MSVC default cannot link with Rtools and makes the check report a WARNING. Use instead of `usethis::use_github_action("check-standard")` for `extendr` packages. |
| `check_pkgdown_reference(pkg = ".")` | `40_check_pkgdown_reference.R` | Verifies every export appears in `_pkgdown.yml`. Argument is `pkg`. |
| `check_sysdeps(deps = NULL, manager = NULL, verbose = TRUE)` | `92_check_sysdeps.R` | Reports system dependencies and install commands (apt/dnf/brew). |
| `get_positron_version(long = FALSE)` | `91_get_positron_version.R` | Returns the Positron version, `NA_character_` outside Positron. |
| `open_cffinit(...)` | `90_open_cffinit.R` | Opens the CFF initializer in the browser. |

## README, badges, documentation

| Function | File | Notes |
|---|---|---|
| `use_multilanguage_readme(lang = c("zh-cn", "es", "fr", "ar", "ru"), color = "blue", ..., path = NULL, overwrite = FALSE)` | `44_use_multilanguage_readme.R` | Creates `inst/translations/README.<lang>.md` and its badges. Translations live in `inst/use_multilanguage_readme_dict/language_dict.R`. |
| `badge_translated_by_ai(lang = "en", color = "yellow")` | `44_use_multilanguage_readme.R` | Returns badge markdown; does not write files. |
| `badge_to_readme(badge, path = NULL, ...)` | `73_badge_to_readme.R` | Inserts a badge into the README badge block. |
| `use_hexsticker(img_path, url = NULL, alt_text = "package logo", height = 139L, align = "right", path = NULL, ...)` | `41_use_hexsticker.R` | Deprecated: `deprecate_stop()`, use `usethis::use_logo()`. |

## Vendored helpers (pedant / pkgdev)

Share `man/current_packages.Rd`. Used mainly as defaults of
`make_func_call_explicit()`.

| Function | File | Notes |
|---|---|---|
| `is_dev_context(dir = ".")` | `vendor-pedant.R` | TRUE when running inside a pkgload development context. |
| `current_packages(dir = ".", base_packages = getOption("defaultPackages"), include_types = "Imports")` | `vendor-pedant.R` | Package set to qualify against. |
| `imported_functions(dir = ".")` | `vendor-pedant.R` | Functions already imported, skipped when adding `::`. |
| `add_double_colons(code = NULL, use_packages = current_packages(), ignore_functions = imported_functions())` | `vendor-pedant.R` | Operates on a code string/selection; prefer `make_func_call_explicit()` for files. |
