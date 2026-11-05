<!-- README.md is generated from README.Rmd. Please edit that file. -->

# rpkgkit <a href="https://wanglabcsu.github.io/rpkgkit/"><img src="man/figures/logo.png" align="right" height="139" alt="rpkgkit website" /></a>

<!-- badges: start -->

[![CRAN-status](https://www.r-pkg.org/badges/version/rpkgkit)](https://CRAN.R-project.org/package=rpkgkit)
[![R-universe-version](https://wanglabcsu.r-universe.dev/rpkgkit/badges/version)](https://wanglabcsu.r-universe.dev/rpkgkit)
[![R-CMD-check](https://github.com/WangLabCSU/rpkgkit/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/WangLabCSU/rpkgkit/actions/workflows/R-CMD-check.yaml)
[![Codesize](https://img.shields.io/github/languages/code-size/WangLabCSU/rpkgkit.svg)](https://github.com/WangLabCSU/rpkgkit)
[![Codecov-testcoverage](https://codecov.io/gh/WangLabCSU/rpkgkit/graph/badge.svg)](https://app.codecov.io/gh/WangLabCSU/rpkgkit)
[![Ask-DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/WangLabCSU/rpkgkit)
[![Dependencies](https://tinyverse.netlify.app/badge/rpkgkit)](https://cran.r-project.org/package=rpkgkit)
[![简体中文](https://img.shields.io/badge/README-%E7%AE%80%E4%BD%93%E4%B8%AD%E6%96%87-blue)](inst/translations/README.zh-cn.md)
[![Español](https://img.shields.io/badge/README-Espa%C3%B1ol-blue)](inst/translations/README.es.md)
<!-- badges: end -->

## Overview

`rpkgkit` provides utilities for creating and maintaining R packages.
The functions support common development tasks such as managing
standalone scripts, maintaining `NEWS.md`, modernizing R source,
configuring package infrastructure, and maintaining README files.

Most functions detect the active file context in RStudio and Positron
(2026.10.1 or later), so a file path can often be omitted.

## Installation

Install the released version from CRAN:

``` r
install.packages("rpkgkit")
```

Install the development version from r-universe:

``` r
install.packages(
  "rpkgkit",
  repos = c("https://wanglabcsu.r-universe.dev", "https://cloud.r-project.org")
)
```

Or install from GitHub (recommended):

``` r
pak::pak("WangLabCSU/rpkgkit")
```

## Guides

Detailed, copy-ready examples are organized by task in the package
website:

- [rpkgkit standalone
  scripts](https://wanglabcsu.github.io/rpkgkit/articles/standalone_tools.html):
  import standalone helpers, manage their metadata, and discover or
  create standalone files.
- [Code
  Convertion](https://wanglabcsu.github.io/rpkgkit/articles/code_convertion.html):
  qualify package calls, check source code, modernize syntax, and
  convert integer or non-ASCII literals.
- [Edit NEWS](https://wanglabcsu.github.io/rpkgkit/articles/news.html):
  create, update, display, and validate `NEWS.md` entries.
- [Package Setup &
  Maintenace](https://wanglabcsu.github.io/rpkgkit/articles/pkg_maintain.html):
  configure package infrastructure, vendor permissively licensed code,
  and manage ignore files.
- [Tools for README &
  Documentation](https://wanglabcsu.github.io/rpkgkit/articles/readme_and_doc.html):
  create README translations and insert or generate badges.

It’s recommended to use following packages together with `rpkgkit`:

- [`pkgdown`](https://pkgdown.r-lib.org/) /
  [`pkgdown.offline`](https://nanx.me/pkgdown.offline/): generate
  package website.
- [`pkgload`](https://pkgload.r-lib.org/): load package source code.
- [`flir`](https://flir.etiennebacher.com/) /
  [`jarl`](https://jarl.etiennebacher.com/) /
  [`lintr`](https://lintr.r-lib.org/): lint and fix source code.
- [`air`](https://posit-dev.github.io/air/): format source code.
- [`usethis`](https://usethis.r-lib.org/): manage package metadata.
- [`devtools`](https://devtools.r-lib.org/): build and check package.

## Cheat sheet

### Convert and check code

| Function | Quick usage | Purpose |
|:---|:---|:---|
| `add_double_colons()` | `add_double_colons(code)` | Add `pkg::` qualifiers to calls in a code string |
| `make_func_call_explicit()` | `make_func_call_explicit("R/foo.R")` | Add `pkg::` qualifiers to every call in one file |
| `package_func_call_explicit()` | `package_func_call_explicit()` | Same, for every file under `R/` |
| `make_func_arg_explicit()` | `make_func_arg_explicit("R/foo.R")` | Add argument names to calls in one file |
| `package_func_arg_explicit()` | `package_func_arg_explicit()` | Same, for every file under `R/` |
| `rename_func()` | `rename_func("R/foo.R", style = "snake_case")` | Rename function definitions to a naming style |
| `convert_func_syntax()` | `convert_func_syntax("R/foo.R", direction = "to_lambda")` | Switch between `function()` and `\()` syntax |
| `convert_pipe()` | `convert_pipe("R/foo.R", direction = "to_base")` | Switch between the magrittr and base pipes in one file |
| `package_convert_pipe()` | `package_convert_pipe(direction = "to_base")` | Same, for every file under `R/` |
| `convert_int_literals()` | `convert_int_literals("R/foo.R")` | Add the integer `L` suffix in one file |
| `package_convert_int_literals()` | `package_convert_int_literals()` | Same, for every file under `R/` |
| `convert_nonascii_code()` | `convert_nonascii_code(code, reverse = FALSE)` | Escape non-ASCII characters (or restore them) |
| `convert_knitr_chunk_header()` | `convert_knitr_chunk_header()` | Modernize knitr chunk headers in `.Rmd` files |
| `optimize_rmd_yaml()` | `optimize_rmd_yaml("README.Rmd")` | Fill one YAML header from the package `DESCRIPTION` |
| `package_optimize_rmd_yaml()` | `package_optimize_rmd_yaml()` | Same, for `README.Rmd` and all vignettes |
| `detect_print_and_cat()` | `detect_print_and_cat("R/foo.R", fix = TRUE)` | Find (and fix) CRAN-unsafe `print()` and `cat()` calls |
| `package_print_and_cat()` | `package_print_and_cat(fix = TRUE)` | Same, across `R/` and `tests/testthat/` |
| `detect_lost_glue_brace()` | `detect_lost_glue_brace("R/foo.R")` | Find lost braces in `glue` and `cli` strings |
| `package_lost_glue_brace()` | `package_lost_glue_brace()` | Same, across `R/` and `tests/testthat/` |
| `detect_unmatched_nocov_marker()` | `detect_unmatched_nocov_marker("R/foo.R")` | Find unmatched `# nocov` markers in one file |
| `package_unmatched_nocov_marker()` | `package_unmatched_nocov_marker()` | Same, across `R/` |
| `detect_fn_arg_path()` | `detect_fn_arg_path("R/foo.R")` | Find default `path` or `file` arguments in exported functions |
| `package_fn_arg_path()` | `package_fn_arg_path()` | Same, across exported functions of the package |
| `check_pkgdown_reference()` | `check_pkgdown_reference()` | Check that every export appears in `_pkgdown.yml` |
| `check_sysdeps()` | `check_sysdeps(c("libpng-dev"))` | Check whether system libraries are installed |
| `check_air_installed()` | `check_air_installed()` | Check that the `air` formatter is on the `PATH` |
| `flir_fix()` | `flir_fix("R/foo.R")` | Fix R code with `flir` |
| `use_air_table()` | `use_air_table("R/foo.R", ncol = 3)` | Lay out long `c()` and `list()` calls as aligned tables with `air` |
| `air_format()` | `air_format("R/foo.R")` | Deprecated; format R code with `air` |

### Manage `NEWS.md`

| Function | Quick usage | Purpose |
|:---|:---|:---|
| `news_md_add_entry()` | `news_md_add_entry("Added a new feature.", category = "NEW FEATURES")` | Add an entry, creating the version section when needed |
| `news_md_show()` | `news_md_show(version = "latest")` | Print `NEWS.md`, optionally filtered to one version |
| `news_md_check()` | `news_md_check()` | Deprecated; validate the `NEWS.md` format |

### Set up and maintain packages

| Function | Quick usage | Purpose |
|:---|:---|:---|
| `use_zzz()` | `use_zzz()` | Create `R/<pkg>-package.R` from a template |
| `use_r_v4.1.0()` | `use_r_v4.1.0()` | Add `R (>= 4.1.0)` to `Depends` |
| `use_url()` | `use_url()` | Set `URL` from the git remote, plus an optional pkgdown URL |
| `use_bugreports()` | `use_bugreports()` | Set `BugReports` from the git remote |
| `use_vendor()` | `use_vendor("wurli/pedant", "R/utils.R")` | Vendor permissively licensed code from GitHub |
| `add_global_rbuildignore()` | `add_global_rbuildignore()` | Add the global `.Rbuildignore` patterns |
| `add_global_gitgnore()` | `add_global_gitgnore()` | Add a GitHub-style global `.gitignore` |
| `use_jarl()` | `use_jarl()` | Create a `jarl.toml` configuration |
| `use_clangd()` | `use_clangd()` | Create a `.clangd` configuration with Rcpp include paths |
| `use_tidy_addin()` | `use_tidy_addin("my_addin", "Open my gadget")` | Register an exported function in the RStudio Addins menu |
| `use_workflow_version_update()` | `use_workflow_version_update()` | Add the version-bumper GitHub Actions workflow |
| `use_workflow_test_branch()` | `use_workflow_test_branch()` | Add a workflow that syncs `main` to the `test` branch |
| `use_workflow_rust_compatible_check()` | `use_workflow_rust_compatible_check()` | Add a Rust-compatible R-CMD-check workflow |
| `open_cffinit()` | `open_cffinit()` | Open the `cffinit` `CITATION.cff` generator in the browser |

### README and documentation

| Function | Quick usage | Purpose |
|:---|:---|:---|
| `badge_to_readme()` | `badge_to_readme(badge)` | Insert a badge into the README badges block |
| `badge_translated_by_ai()` | `badge_translated_by_ai(lang = "zh-cn")` | Generate an AI-translation disclaimer badge |
| `use_multilanguage_readme()` | `use_multilanguage_readme("zh-cn")` | Create translated README files and their badges |
| `render_rmd()` | `render_rmd("README.Rmd")` | Render an `.Rmd` or `.R` file to Markdown |
| `use_hexsticker()` | `use_hexsticker("man/figures/logo.png")` | Deprecated; add a hex sticker to the README title |

### Standalone files

| Function | Quick usage | Purpose |
|:---|:---|:---|
| `create_standalone()` | `create_standalone("my_utils")` | Create a standalone file with a YAML header |
| `check_standalone()` | `check_standalone("R/standalone-my_utils.R")` | Check the format of a standalone file |
| `update_time_in_standalone()` | `update_time_in_standalone()` | Refresh the last-updated field of standalone files |
| `add_changelog_in_standalone()` | `add_changelog_in_standalone("R/standalone-my_utils.R", "Fix a bug")` | Add or update a changelog entry |
| `inquire_standalone()` | `inquire_standalone("r-lib", "rlang")` | List the standalone files of a GitHub repository |
| `browse_standalone()` | `browse_standalone()` | Search GitHub for standalone files shipped by R packages |

### Utilities

| Function | Quick usage | Purpose |
|:---|:---|:---|
| `current_packages()` | `current_packages()` | Packages whose calls should be qualified |
| `imported_functions()` | `imported_functions()` | Function names imported in `NAMESPACE` |
| `is_dev_context()` | `is_dev_context()` | Whether the working directory is package development |
| `get_positron_version()` | `get_positron_version()` | Version of the running Positron IDE |

## Addin

After v0.1.23, `rpkgkit` ships an addin that can be used in RStudio.
It’s available in the `Addins` menu, and can be accessed by pressing
`Ctrl+Shift+P` (Windows/Linux) or `Cmd+Shift+P` (macOS).

If you want to use addins in Positron, you can use [Positron R
Wizard](https://github.com/ntluong95/positron-r-wizard.git) extension.

## AI skills

`rpkgkit` ships an agent skill that tells coding agents when to reach
for `rpkgkit` and how to call it. It follows the [Agent
Skills](https://skills.sh) layout, so it works with Claude Code, Codex,
Cursor, Positron, and other compatible agents:

``` bash
npx skills add WangLabCSU/rpkgkit --skill rpkgkit
```

Add `-g` to install it for every project, and `-a <agent>` to skip the
agent prompt. The skill source lives in
[`skills/rpkgkit/`](https://github.com/WangLabCSU/rpkgkit/tree/main/skills/rpkgkit).

## Acknowledgements

We would like to thank the following people and projects:

- The authors of the [pedant](https://github.com/wurli/pedant) package —
  **Jacob Scott**, **Christopher T. Kenny**, and **Sebastian Lammers** —
  whose code is included (under MIT license) in `R/vendor-pedant.R`.
- The authors of the [pkgdev](https://github.com/dieghernan/pkgdev)
  package — **Diego Hernangómez** — whose code is included (under MIT
  license) in `R/vendor-pkgdev.R`.
- All contributors and users who have reported issues, suggested
  features, or helped improve the package.
