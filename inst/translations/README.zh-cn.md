# rpkgkit <a href="https://wanglabcsu.github.io/rpkgkit/"><img src="man/figures/logo.png" align="right" height="139" alt="rpkgkit website" /></a>

<!-- badges: start -->

[![Lifecycle:stable](https://img.shields.io/badge/lifecycle-stable-brightgreen.svg)](https://lifecycle.r-lib.org/articles/stages.html#stable)
[![Project Status: Active - The project has reached a stable, usable
state and is being actively
developed.](https://www.repostatus.org/badges/latest/active.svg)](https://www.repostatus.org/#active)
[![CRAN-status](https://www.r-pkg.org/badges/version/rpkgkit)](https://CRAN.R-project.org/package=rpkgkit)
[![R-CMD-check](https://github.com/WangLabCSU/rpkgkit/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/WangLabCSU/rpkgkit/actions/workflows/R-CMD-check.yaml)
[![Devel-version](https://img.shields.io/badge/devel%20version-0.1.9-blue.svg)](https://github.com/WangLabCSU/rpkgkit)
[![Codesize](https://img.shields.io/github/languages/code-size/WangLabCSU/rpkgkit.svg)](https://github.com/WangLabCSU/rpkgkit)
[![Codecov-testcoverage](https://codecov.io/gh/WangLabCSU/rpkgkit/graph/badge.svg)](https://app.codecov.io/gh/WangLabCSU/rpkgkit)
[![Ask-DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/WangLabCSU/rpkgkit)
[![Dependencies](https://tinyverse.netlify.app/badge/rpkgkit)](https://cran.r-project.org/package=rpkgkit)
[![English](https://img.shields.io/badge/README-English-blue)](../README.md)
[![简体中文](https://img.shields.io/badge/README-%E7%AE%80%E4%BD%93%E4%B8%AD%E6%96%87-blue)]()
<!-- badges: end -->

## 推荐的最佳实践

虽然已经有很多面向 R 包开发的开源项目，但开发过程中许多繁琐且重复的任务可以通过函数化来简化。rpkgkit 的目标是为 R 包开发提供实用的函数。

## 安装

从 CRAN 安装：

``` r
install.packages("rpkgkit")
```

从 GitHub 安装：

``` r
if (!requireNamespace("pak")) {
  install.packages(
    "pak",
    repos = sprintf(
      "https://r-lib.github.io/p/pak/stable/%s/%s/%s",
      .Platform$pkgType,
      R.Version()$os,
      R.Version()$arch
    )
  )
}
pak::pak("Exceret/rpkgkit")
```

## 特性

所有函数都能自动检测 RStudio 和 Positron 中的活动文件上下文，因此通常可以省略文件路径参数。

### 可用的独立脚本 (Standalone Scripts)

使用 `usethis::use_standalone("WangLabCSU/rpkgkit", "<name>")` 导入：

- args_to_func.R：将参数列表与函数调用进行匹配：

<!-- -->

``` r
f1 <- function(a, b) a + b
f2 <- function(x, y, ...) x * y
f3 <- function(p, q) p - q

args <- list(a = 1, b = 2)

# 严格匹配（默认）：仅返回 f1
match_func_to_args(args, f1, f2, f3)
```

``` r
args <- list(a = 1, b = 2, x = 3, y = 4)
foo <- function(x , y = 1){x + y}
filter_args_for_func(args, foo) # 保留属于 foo 的参数
# $x
# [1] 3

# $y
# [1] 4
```

- caller_cli.R：显示 cli 函数的调用来源位置：

<!-- -->

``` r
decorated <- add_caller_to_cli(cli::cli_alert_info)
foo1 <- \() {
  print("I' m in foo1")
  decorated("<- where is this called from?")
}
foo2 <- \() {
  print("I' m in foo2")
  foo1()
}
bar <- function() {
  print("I' m in bar")
  foo2()
}
bar()
# [1] "I' m in bar"
# [1] "I' m in foo2"
# [1] "I' m in foo1"
# ℹ [foo1()]: <- where is this called from?
```

- colorful_cli.R：在单个 cli 函数中更方便地调用颜色：

<!-- -->

``` r
color_cli <- create_colorful_cli_env()
color_cli$cli_alert_danger("{.red This is a red message}")
color_cli$cli_alert_info("{.blue This is a blue message}")
color_cli$cli_alert_info("{.orange This is an orange message}")
# cyan, green, magenta, yellow, purple, 等

color_cli2 <- create_colorful_cli_env(cli_theme = generate_color_theme()) # 颜色更多但速度较慢
color_cli2$cli_alert_success(
  "{.violetred3 R}{.orange a}{.yellow i}{.green n}{.cyan b}{.blue o}{.purple w}"
)
```

- match_arg.R：函数参数的局部匹配，类似 `match.arg`、`rlang::arg_match`

- ts_cli.R：带时间戳的 cli 函数：

<!-- -->

``` r
ts_cli <- create_ts_cli_env()
ts_cli$cli_alert_info("Hello, world!")
# ℹ [2026/05/30 22:45:42] Hello, world!
```

### 独立脚本文件管理

- `inquire_standalone()` — 列出 GitHub 仓库 `R/` 目录下可用的独立脚本文件

- `browse_standalone()` — 浏览 GitHub 仓库中所有可用的独立脚本文件

<!-- -->

``` r
inquire_standalone("r-lib/rlang")
# A tibble: 13 × 9
#    name                         path                           sha                                       size url                               html_url git_url download_url type
#    <chr>                        <chr>                          <chr>                                    <int> <chr>                             <chr>    <chr>   <chr>        <chr>
#  1 standalone-cli.R             R/standalone-cli.R             14c6006f721028d2da0ab1654afd49e426e745c6 18672 https://api.github.com/repos/r-l… https:/… https:… https://raw… file
#  2 standalone-downstream-deps.R R/standalone-downstream-deps.R 09b7700582bf710498d2ca5652662669655e5600  9213 https://api.github.com/repos/r-l… https:/… https:… https://raw… file
#  3 standalone-lazyeval.R        R/standalone-lazyeval.R        50ced0ddc07e4fffccbec96ef34e30a82cfbb075  2313 https://api.github.com/repos/r-l… https:/… https:… https://raw… file
#  4 standalone-lifecycle.R       R/standalone-lifecycle.R       70f03184aa89aa7e801b2fc6b8a12dd3a0e61700  6411 https://api.github.com/repos/r-l… https:/… https:… https://raw… file
#  5 standalone-linked-version.R  R/standalone-linked-version.R  9ab21931a161722b6b837fa3cd40dd0a65b88551  2167 https://api.github.com/repos/r-l… https:/… https:… https://raw… file
#  6 standalone-obj-type.R        R/standalone-obj-type.R        e9c33c8e34f2a194c2bd71f0126fc0bdaa974e61  7175 https://api.github.com/repos/r-l… https:/… https:… https://raw… file
#  7 standalone-purrr.R           R/standalone-purrr.R           0c1d7677258aada8464e6c3f48fb70a062492a89  5501 https://api.github.com/repos/r-l… https:/… https:… https://raw… file
#  8 standalone-rlang.R           R/standalone-rlang.R           4da3655d2d1c86535616c53cd5dab421e1e0cf6b  1807 https://api.github.com/repos/r-l… https:/… https:… https://raw… file
#  9 standalone-s3-register.R     R/standalone-s3-register.R     05f0a2680fcbbdda64524ffa5481940671faac83  6056 https://api.github.com/repos/r-l… https:/… https:… https://raw… file
# 10 standalone-sizes.R           R/standalone-sizes.R           03ee9f7a8ddddd6132a3ebf703e0a9aa3ccf30d5  3069 https://api.github.com/repos/r-l… https:/… https:… https://raw… file
# 11 standalone-types-check.R     R/standalone-types-check.R     42c756a299cea38af775b587a1fe440de2afed40  6843 https://api.github.com/repos/r-l… https:/… https:… https://raw… file
# 12 standalone-vctrs.R           R/standalone-vctrs.R           a78927f6d65fd769c61e2c132dea05d89a8b353a 14292 https://api.github.com/repos/r-l… https:/… https:… https://raw… file
# 13 standalone-zeallot.R         R/standalone-zeallot.R         5e9d59a03e1d6df18ab4921e7d828750d6a41d6f   843 https://api.github.com/repos/r-l… https:/… https:… https://raw… file

browse_standalone()
# # A tibble: 184 × 9
#    repo                   name                             path                               sha                 url   html_url git_url repo_url repo_description
#    <chr>                  <chr>                            <chr>                              <chr>               <chr> <chr>    <chr>   <chr>    <chr>           
#  1 tidymodels/parsnip     standalone-survival.R            R/standalone-survival.R            3f3809cc6019326a7f… http… https:/… https:… https:/… A tidy unified …
#  2 prioritizr/prioritizr  standalone-cli.R                 R/standalone-cli.R                 00453fe89a55497eba… http… https:/… https:… https:/… Systematic cons…
#  3 r-lib/rlang            standalone-vctrs.R               R/standalone-vctrs.R               a78927f6d65fd769c6… http… https:/… https:… https:/… Low-level API f…
#  4 cran/prioritizr        standalone-all_columns_inherit.R R/standalone-all_columns_inherit.R 2c08f0fdc2e3749b46… http… https:/… https:… https:/… :exclamation: T…
#  5 ai4ci/tidyabc          standalone-distributions.R       R/standalone-distributions.R       249a19d425c208db51… http… https:/… https:… https:/… R framework for…
#  6 terminological/ggrrr   standalone-empirical.R           R/standalone-empirical.R           4bcde2d56ddc24ae9d… http… https:/… https:… https:/… Data presentati…
#  7 WangLabCSU/SigBridgeR  standalone-get_var_value.R       R/standalone-get_var_value.R       6331dae57b7e759122… http… https:/… https:… https:/… SigBridgeR: Int…
#  8 willgearty/deeptime    standalone-obj-type.R            R/standalone-obj-type.R            106accce773ab162cd… http… https:/… https:… https:/… An R package th…
#  9 ddsjoberg/standalone   standalone-check_pkg_installed.R R/standalone-check_pkg_installed.R 571303b0f4e689ab4d… http… https:/… https:… https:/… Standalone scri…
# 10 elipousson/standaloner standalone-extra-checks.R        R/standalone-extra-checks.R        75bda8f557cfcae29e… http… https:/… https:… https:/… Set or get a to…
# # ℹ 174 more rows
```

- `create_standalone()` — 在你的包中创建独立脚本工具文件

``` r
create_standalone("foo")
# ✔ Created standalone file: /data/home/yyx/Project/rpkgkit/R/standalone-.R
# ☐ File opened in editor.
```

在 `R/standalone-foo.R` 中：

``` r
# ---
# repo: WangLabCSU/rpkgkit
# file: standalone-foo.R
# last-updated: 2026-06-02
# license: https://unlicense.org
# imports: []
# ---
# 
# This file provides...
#
# nocov start
```

- `update_time_in_standalone()` — 更新独立脚本文件中的 `last-updated` 字段

<!-- -->

``` r
update_time_in_standalone()

# ---
# repo: WangLabCSU/rpkgkit
# file: standalone-foo.R
# last-updated: 2026-06-02
# license: https://unlicense.org
# imports: []
# ---
```

- `add_changelog_in_standalone()` — 向独立脚本文件中添加更新日志条目

<!-- -->

``` r
add_changelog_in_standalone("R/standalone-foo.R", "Added foo function")
# ✔ Added changelog entry for "2026-06-02" in 1 file(s).

# ---
# repo: WangLabCSU/rpkgkit
# file: standalone-foo.R
# last-updated: 2026-06-02
# license: https://unlicense.org
# imports: []
# ---
#
# Changelog:
#
# 2026-06-02:
# Added foo function
```

### NEWS.md 管理

- `news_md_add_entry()` — 按照 CRAN 规范向 NEWS.md 添加新条目

<!-- -->

``` r
news_md_add_entry("Added foo function")
```

    # rpkgkit 0.0.4 (2026-06-02)

    ## NEW FEATURES

    * Added foo function

添加一条不同类型的条目：

``` r
news_md_add_entry(
  entry = "Fixed bugs in `foo()`",  
  version = "0.0.4",
  category = "BUG FIXES"
)
```

    # rpkgkit 0.0.4 (2026-06-02)

    ## NEW FEATURES

    * Added foo function

    ## BUG FIXES

    * Fixed bugs in `foo()`

- `news_md_check()` — 验证 NEWS.md 格式是否符合 CRAN 要求

<!-- -->

``` r
news_md_check()
# ℹ Checking NEWS.md with 22 lines
# ✔ NEWS.md passed all required checks
# ℹ 4 suggestion(s) for improvement
# $valid
# [1] TRUE

# $errors
# character(0)

# $warnings
# character(0)

# $suggestions
# [1] "Line 10: Bullet points should start with '* ' followed by capital letter"
# [2] "Line 12: Bullet points should start with '* ' followed by capital letter"
# [3] "Line 14: Bullet points should start with '* ' followed by capital letter"
# [4] "Line 14: Longer entries should end with punctuation"
```

- `news_md_show()` — 在控制台中以彩色形式展示包的 NEWS.md 内容

### R 函数转换

- `make_func_call_explicit()` — 通过添加包前缀使函数调用显式化
- `package_func_call_explicit()` — 在包中批量添加包前缀使函数调用显式化

以下代码片段来自 [dplyr](https://github.com/tidyverse/dplyr)：

``` r

starwars |>
  mutate(name, bmi = mass / ((height / 100)^2)) |>
  select(name:mass, bmi)

make_func_call_explicit("path_to_file", use_packages = "dplyr")
```

将被转换为：

``` r
starwars |>
  dplyr::mutate(name, bmi = mass / ((height / 100)^2)) |>
  dplyr::select(name:mass, bmi)
```

- `detect_lost_glue_brace()` — 查找文件中所有缺少右括号的 `glue` 调用，同时支持 `glue` 和 `cli` 表达式
- `package_lost_glue_brace()` — 在包中查找所有缺少右括号的 `glue` 调用，同时支持 `glue` 和 `cli` 表达式

``` r
# foo.R
name <- "world"
msg <- glue::glue("Hello, {name!")

library(cli)
warning <- ""
bar <- cli::col_red(cli::cli_alert_warning(
  "{.field warning}}: This string is missing {.val 1} brace{?s}"
))
```

``` r
detect_lost_glue_brace()

# msg <- glue::glue("Hello, {name!")
#                           ^^^^^^ 

#   "{.field warning}}: This string is missing {.val 1} brace{?s}"
#    ^^^^^^^^^^^^^^^^^ 
# ✖ Found 2 lines with mismatched braces: 3 and 8
```

- `make_func_arg_explicit()` — 使函数参数使用显式参数名传递
- `package_func_arg_explicit()` — 在包中使函数参数使用显式参数名传递

``` r
tf <- tempfile(fileext = ".R")
writeLines("vapply(1:9, function(x) x*2, numeric(1))", tf)
make_func_arg_explicit(tf)
# ✔ Made function arguments explicit in /tmp/RtmpOr1Iz0/file15b76c2120b264.R

cat(readLines(tf), sep = "\n")
# vapply(X = 1:9, FUN = function(x) x * 2, FUN.VALUE = numeric(length = 1))
```

- `rename_func()` — 按特定风格重命名文件中的函数

``` r
tf <- tempfile(fileext = ".R")
writeLines("this_is_a_function <- function(){message('Hello, world')}", tf)

rename_func(
  tf,
  style = "camelCase"
)
# ✔ Renamed 1 function to "camelCase" style in /tmp/RtmpOr1Iz0/file15b76c8de7e51.R

cat(readLines(tf), sep = "\n")
# thisIsAFunction <- function(){message('Hello, world')}
```

- `detect_print_and_cat()` — 检测文件中的 `print()` 和 `cat()` 调用
- `package_print_and_cat()` — 检测包中的 `print()` 和 `cat()` 调用

根据 CRAN 政策不允许使用 `print()` 和 `cat()`，因此需要用 `message()` 来修正：

``` r
tf <- tempfile(fileext = ".R")
writeLines("print('Hello, world')", tf)
detect_print_and_cat(tf)
# print('Hello, world')
# ^^^^^^
# ✖ Found 1 unsupported call on line 
# 1.
detect_print_and_cat(tf, fix = TRUE)
cat(readLines(tf), sep = "\n")
# message('Hello, world')
```

- `convert_func_syntax()` — 在 `function()` 和 `\()` 语法之间转换函数定义

``` r
f <- tempfile(fileext = ".R")
writeLines("f <- function(x) x^2", f)
convert_func_syntax(f)
# ✔ Converted function definitions in /tmp/Rtmp9ftJDS/file2a5a1320c9342e.R to "to_lambda"
message(readLines(f), sep = "\n")
# f <- \(x) x^2

convert_func_syntax(f, "to_explicit")
# ✔ Converted function definitions in /tmp/Rtmp9ftJDS/file2a5a1320c9342e.R to "to_explicit"
message(readLines(f), sep = "\n")
# f <- function(x) x^2
```

### R 包维护

- `use_zzz()` — 在 `R/` 目录下创建 `{pkgname}-package.R` 文件，包含 `.onLoad`、`.onAttach`、`%||%` 以及包描述信息。类似于 `usethis::use_package_doc()` 但功能更强大。

``` r
# * 例如，在 rpkgkit 开发环境下使用
use_zzz()

# #' @title Create and Maintain R Packages
# #'
# #' @description Utilities for R package development including NEWS.md
# #' management, standalone file creation, and code formatting. Supports popular
# #' development workflows and integrates with 'usethis' and 'RStudio'. Includes
# #' helper functions for renaming functions and detecting common coding errors.
# #'
# #' @section License:
# #' MIT + file LICENSE
# #'
# #' @docType package
# #' @name rpkgkit-package
# #' @aliases rpkgkit
# #' @keywords internal
# #'
# "_PACKAGE"


# .onAttach <- function(libname, pkgname) {
#   pkg_version <- utils::packageVersion(pkgname)

#   msg <- cli::cli_fmt(cli::cli_alert_success(
#     "{.pkg {pkgname}} v{pkg_version} loaded"
#   ))
#   packageStartupMessage(msg)
#   invisible()
# }

# .onLoad <- function(libname, pkgname) {
#   invisible()
# }

# `%||%` <- function(left, right) {
#   if (is.null(left)) {
#     return(right)
#   }
#   left
# }
```

- `check_pkgdown_reference()` — 检查 `_pkgdown.yml` 中是否引用了所有导出函数

``` r
check_pkgdown_reference()
# ✖ 9 exported functions missing from pkgdown reference:
# - current_packages
# - detect_lost_glue_brace
# - detect_print_and_cat
# - imported_functions
# - make_func_arg_explicit
# - make_func_call_explicit
# - news_md_add_entry
# - news_md_check
# - news_md_show
```

- `use_vendor()` — 从 GitHub 引用一个宽松许可的 R 包以便纳入你自己的 R 包。在 CRAN 政策下轻松导入来自 GitHub 的 R 包。

许可协议、版权和声明将自动生成到 `DESCRIPTION`、`R/vendor-*.R` 和 `inst/vendor/` 中。

``` r
dir <- tempdir()
usethis::create_package(path = dir)
use_vendor(pkg = "WangLabCSU/rpkgkit", "43_use_vendor.R", branch = "main", path = dir)
# ℹ Fetching repository information for WangLabCSU/rpkgkit...
# ✔ Vendor package uses MIT license.
# ✔ Created directory /tmp/RtmpOr1Iz0/inst/vendor/rpkgkit.
# ✔ Copied LICENSE.
# ✔ Copied LICENSE.md.
# ✔ Created inst/vendor/rpkgkit/README.md.
# ✔ Created /tmp/RtmpOr1Iz0//R/vendor-rpkgkit.R.
# ✔ Added rpkgkit authors to Authors@R.
# ✔ Updated DESCRIPTION.
# ☐ Consider pasting the following statement into README.md

# ## Acknowledgements

# We would like to thank the following people and projects:

# - The authors of the [rpkgkit](https://github.com/WangLabCSU/rpkgkit) package &mdash; **Yuxi Yang, Jacob Scott, Christopher T. Kenny, Sebastian Lammers and Diego Hernangómez** &mdash; whose code is included (under MIT license) in `R/vendor-rpkgkit.R`.
```

- `use_multilanguage_readme()` — 为你的 R 包创建多语言 README.md 模板
- `badge_translated_by_ai()` — 创建"由 AI 翻译"徽章

``` r
use_multilangauge_readme("es")
# ✔ Created 1 README translation file in inst/translations.
# ☐ Consider pasting the following badges into your main README.md:

# [![Español](https://img.shields.io/badge/README-Espa%C3%B1ol-blue)](inst/translations/README.es.md)
```

``` r
badge_translated_by_ai("es")
# ☐ Consider copying the following statement to the AI-translated file(s):

# [![AI](https://img.shields.io/badge/AI-Espa%C3%B1ol-yellow)]()

# > Este contenido ha sido traducido por IA y no ha sido revisado. No es la lengua materna del autor y es solo para referencia.
```

- `convert_nonascii_code()` — 将非 ASCII 代码转换为 ASCII 代码。便于在 CRAN 政策下使用非 ASCII 代码。

``` r
# 从文件转换
tmp <- tempfile()
writeLines("foo <- \\() message('滚滚长江东逝水')", tmp)
convert_nonascii_code(tmp)
# ☐ Overwrite file /tmp/Rtmp72DzrV/file1e2ec6cc2d66c with converted content? (yes/No/cancel) 
# yes
# ℹ Converted content written to /tmp/Rtmp72DzrV/file1e2ec6cc2d66c
message(readLines(tmp))
# foo <- \() message('\u6eda\u6eda\u957f\u6c5f\u4e1c\u901d\u6c34')
```

``` r
# 从 R 表达式转换
convert_nonascii_code(
  cli::cli_alert_info("明月几时有")
)
# ℹ Converted code (copy from console):
# cli::cli_alert_info("\u660e\u6708\u51e0\u65f6\u6709")
cli::cli_alert_info("\u660e\u6708\u51e0\u65f6\u6709")
# ℹ 明月几时有
```

- `Add_global_rbuildignore()` — 向你的 R 包中添加全局 `.Rbuildignore` 文件
- `Add_global_gitignore()` — 向你的 R 包中添加全局 `.gitignore` 文件

## 致谢

感谢以下人员与项目：

- [pedant](https://github.com/wurli/pedant) 包的作者 — **Jacob Scott**、**Christopher T. Kenny** 和 **Sebastian Lammers** — 其代码（基于 MIT 许可）已包含在 `R/vendor-pedant.R` 中。
- [pkgdev](https://github.com/dieghernan/pkgdev) 包的作者 — **Diego Hernangómez** — 其代码（基于 MIT 许可）已包含在 `R/vendor-pkgdev.R` 中。
- 所有报告问题、提出功能建议或帮助改进本包的贡献者与用户。
