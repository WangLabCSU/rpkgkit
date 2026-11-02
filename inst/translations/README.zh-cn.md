# rpkgkit <a href="https://wanglabcsu.github.io/rpkgkit/"><img src="../../man/figures/logo.png" align="right" height="139" alt="rpkgkit 网站" /></a>

<!-- badges: start -->
[![CRAN-status](https://www.r-pkg.org/badges/version/rpkgkit)](https://CRAN.R-project.org/package=rpkgkit)
[![R-universe-version](https://wanglabcsu.r-universe.dev/rpkgkit/badges/version)](https://wanglabcsu.r-universe.dev/rpkgkit)
[![R-CMD-check](https://github.com/WangLabCSU/rpkgkit/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/WangLabCSU/rpkgkit/actions/workflows/R-CMD-check.yaml)
[![Codesize](https://img.shields.io/github/languages/code-size/WangLabCSU/rpkgkit.svg)](https://github.com/WangLabCSU/rpkgkit)
[![Codecov-testcoverage](https://codecov.io/gh/WangLabCSU/rpkgkit/graph/badge.svg)](https://app.codecov.io/gh/WangLabCSU/rpkgkit)
[![Ask-DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/WangLabCSU/rpkgkit)
[![Dependencies](https://tinyverse.netlify.app/badge/rpkgkit)](https://cran.r-project.org/package=rpkgkit)
[![English](https://img.shields.io/badge/README-English-blue)](../../README.md)
[![Español](https://img.shields.io/badge/README-Espa%C3%B1ol-blue)](README.es.md)
[![简体中文](https://img.shields.io/badge/README-%E7%AE%80%E4%BD%93%E4%B8%AD%E6%96%87-blue)]()
<!-- badges: end -->

## 概览

`rpkgkit` 为创建和维护 R 包提供实用工具。其函数覆盖独立脚本管理、`NEWS.md` 维护、R 源代码现代化、包基础设施配置和 README 文件维护等常见开发任务。

多数函数可以检测 RStudio 和 Positron（2026.10.1 或更高版本）中的活动文件上下文，因此通常可以省略文件路径。

## 安装

从 CRAN 安装已发布版本：

```r
install.packages("rpkgkit")
```

从 r-universe 安装开发版本：

```r
install.packages(
  "rpkgkit",
  repos = c("https://wanglabcsu.r-universe.dev", "https://cloud.r-project.org")
)
```

或从 GitHub 安装（推荐）：

```r
pak::pak("WangLabCSU/rpkgkit")
```

## 指南

包网站按任务整理了可直接使用的详细示例：

- [rpkgkit 独立脚本](https://wanglabcsu.github.io/rpkgkit/articles/standalone_tools.html)：导入独立工具、维护其元数据，以及查找或创建独立文件。
- [代码转换](https://wanglabcsu.github.io/rpkgkit/articles/code_convertion.html)：为包调用添加命名空间、检查源代码、转换语法，以及处理整数或非 ASCII 字面量。
- [编辑 NEWS](https://wanglabcsu.github.io/rpkgkit/articles/news.html)：创建、更新、显示和验证 `NEWS.md` 条目。
- [包设置与维护](https://wanglabcsu.github.io/rpkgkit/articles/pkg_maintain.html)：配置包基础设施、引入宽松许可证代码，以及管理忽略文件。
- [README 与文档工具](https://wanglabcsu.github.io/rpkgkit/articles/readme_and_doc.html)：创建 README 翻译文件，以及插入或生成徽章。

建议将以下包与 `rpkgkit` 配合使用：

- [`pkgdown`](https://pkgdown.r-lib.org/) / [`pkgdown.offline`](https://nanx.me/pkgdown.offline/)：生成包网站。
- [`pkgload`](https://pkgload.r-lib.org/)：加载包源代码。
- [`flir`](https://flir.etiennebacher.com/) / [`jarl`](https://jarl.etiennebacher.com/) / [`lintr`](https://lintr.r-lib.org/)：检查并修复源代码。
- [`air`](https://posit-dev.github.io/air/)：格式化源代码。
- [`usethis`](https://usethis.r-lib.org/)：管理包元数据。
- [`devtools`](https://devtools.r-lib.org/)：构建和检查包。

## 速查表

下表列出所有导出函数及其最简调用方式。多数函数接受 `path = NULL`，表示“使用当前活动文件或当前包目录”。

### 代码转换与检查

| 函数名 | 简单用法 | 用途 |
|:---|:---|:---|
| `add_double_colons()` | `add_double_colons(code)` | 为代码字符串中的调用添加 `pkg::` 限定 |
| `make_func_call_explicit()` | `make_func_call_explicit("R/foo.R")` | 为单个文件中的所有调用添加 `pkg::` 限定 |
| `package_func_call_explicit()` | `package_func_call_explicit()` | 同上，处理 `R/` 下的所有文件 |
| `make_func_arg_explicit()` | `make_func_arg_explicit("R/foo.R")` | 为单个文件中的调用补全参数名 |
| `package_func_arg_explicit()` | `package_func_arg_explicit()` | 同上，处理 `R/` 下的所有文件 |
| `rename_func()` | `rename_func("R/foo.R", style = "snake_case")` | 按指定命名风格重命名函数定义 |
| `convert_func_syntax()` | `convert_func_syntax("R/foo.R", direction = "to_lambda")` | 在 `function()` 与 `\()` 语法之间转换 |
| `convert_pipe()` | `convert_pipe("R/foo.R", direction = "to_base")` | 在 magrittr 管道与原生管道之间转换单个文件 |
| `package_convert_pipe()` | `package_convert_pipe(direction = "to_base")` | 同上，处理 `R/` 下的所有文件 |
| `convert_int_literals()` | `convert_int_literals("R/foo.R")` | 为单个文件中的整数补上 `L` 后缀 |
| `package_convert_int_literals()` | `package_convert_int_literals()` | 同上，处理 `R/` 下的所有文件 |
| `convert_nonascii_code()` | `convert_nonascii_code(code, reverse = FALSE)` | 将非 ASCII 字符转义（或还原） |
| `convert_knitr_chunk_header()` | `convert_knitr_chunk_header()` | 将 `.Rmd` 中的 knitr 旧式代码块头部转换为新语法 |
| `optimize_rmd_yaml()` | `optimize_rmd_yaml("README.Rmd")` | 用 DESCRIPTION 补全单个文件的 YAML 头部 |
| `package_optimize_rmd_yaml()` | `package_optimize_rmd_yaml()` | 同上，处理 `README.Rmd` 和所有 vignette |
| `detect_print_and_cat()` | `detect_print_and_cat("R/foo.R", fix = TRUE)` | 查找（并修复）CRAN 不允许的 `print()` 和 `cat()` 调用 |
| `package_print_and_cat()` | `package_print_and_cat(fix = TRUE)` | 同上，范围包括 `R/` 和 `tests/testthat/` |
| `detect_lost_glue_brace()` | `detect_lost_glue_brace("R/foo.R")` | 查找 `glue` 和 `cli` 字符串中丢失的花括号 |
| `package_lost_glue_brace()` | `package_lost_glue_brace()` | 同上，范围包括 `R/` 和 `tests/testthat/` |
| `detect_unmatched_nocov_marker()` | `detect_unmatched_nocov_marker("R/foo.R")` | 查找单个文件中未配对的 `# nocov` 标记 |
| `package_unmatched_nocov_marker()` | `package_unmatched_nocov_marker()` | 同上，处理 `R/` 下的所有文件 |
| `detect_fn_arg_path()` | `detect_fn_arg_path("R/foo.R")` | 查找导出函数中默认值为 `path` 或 `file` 的参数 |
| `package_fn_arg_path()` | `package_fn_arg_path()` | 同上，检查包内所有导出函数 |
| `check_pkgdown_reference()` | `check_pkgdown_reference()` | 检查所有导出函数是否都出现在 `_pkgdown.yml` 中 |
| `check_sysdeps()` | `check_sysdeps(c("libpng-dev"))` | 检查系统库是否已安装 |
| `check_air_installed()` | `check_air_installed()` | 检查 `air` 格式化工具是否在 `PATH` 中 |
| `flir_fix()` | `flir_fix("R/foo.R")` | 使用 `flir` 修复 R 代码 |
| `air_format()` | `air_format("R/foo.R")` | 已弃用；使用 `air` 格式化 R 代码 |

### 管理 `NEWS.md`

| 函数名 | 简单用法 | 用途 |
|:---|:---|:---|
| `news_md_add_entry()` | `news_md_add_entry("Added a new feature.", category = "NEW FEATURES")` | 添加条目，必要时自动创建版本小节 |
| `news_md_show()` | `news_md_show(version = "latest")` | 显示 `NEWS.md`，可只显示某个版本 |
| `news_md_check()` | `news_md_check()` | 已弃用；校验 `NEWS.md` 格式 |

### 包设置与维护

| 函数名 | 简单用法 | 用途 |
|:---|:---|:---|
| `use_zzz()` | `use_zzz()` | 由模板创建 `R/<pkg>-package.R` |
| `use_r_v4.1.0()` | `use_r_v4.1.0()` | 在 `Depends` 中添加 `R (>= 4.1.0)` |
| `use_url()` | `use_url()` | 由 git 远程地址设置 `URL`，可附加 pkgdown 网址 |
| `use_bugreports()` | `use_bugreports()` | 由 git 远程地址设置 `BugReports` |
| `use_vendor()` | `use_vendor("wurli/pedant", "R/utils.R")` | 从 GitHub 引入宽松许可证代码 |
| `add_global_rbuildignore()` | `add_global_rbuildignore()` | 添加全局 `.Rbuildignore` 规则 |
| `add_global_gitgnore()` | `add_global_gitgnore()` | 添加 GitHub 风格的全局 `.gitignore` |
| `use_jarl()` | `use_jarl()` | 创建 `jarl.toml` 配置文件 |
| `use_clangd()` | `use_clangd()` | 创建包含 Rcpp 头文件路径的 `.clangd` 配置 |
| `use_tidy_addin()` | `use_tidy_addin("my_addin", "Open my gadget")` | 将导出函数注册到 RStudio Addins 菜单 |
| `use_workflow_version_update()` | `use_workflow_version_update()` | 添加自动更新版本号的 GitHub Actions 工作流 |
| `use_workflow_test_branch()` | `use_workflow_test_branch()` | 添加将 `main` 同步到 `test` 分支的工作流 |
| `use_workflow_rust_compatible_check()` | `use_workflow_rust_compatible_check()` | 添加兼容 Rust 的 R-CMD-check 工作流 |
| `open_cffinit()` | `open_cffinit()` | 在浏览器中打开 `cffinit` 的 `CITATION.cff` 生成器 |

### README 与文档

| 函数名 | 简单用法 | 用途 |
|:---|:---|:---|
| `badge_to_readme()` | `badge_to_readme(badge)` | 将徽章插入 README 徽章区 |
| `badge_translated_by_ai()` | `badge_translated_by_ai(lang = "zh-cn")` | 生成“AI 翻译”免责声明徽章 |
| `use_multilanguage_readme()` | `use_multilanguage_readme("zh-cn")` | 创建多语言 README 文件及其徽章 |
| `render_rmd()` | `render_rmd("README.Rmd")` | 将 `.Rmd` 或 `.R` 文件渲染为 Markdown |
| `use_hexsticker()` | `use_hexsticker("man/figures/logo.png")` | 已弃用；在 README 标题处添加六边形贴纸 |

### 独立脚本

| 函数名 | 简单用法 | 用途 |
|:---|:---|:---|
| `create_standalone()` | `create_standalone("my_utils")` | 创建带 YAML 头部的独立脚本文件 |
| `check_standalone()` | `check_standalone("R/standalone-my_utils.R")` | 检查独立脚本文件的格式 |
| `update_time_in_standalone()` | `update_time_in_standalone()` | 更新独立脚本的最后修改时间字段 |
| `add_changelog_in_standalone()` | `add_changelog_in_standalone("R/standalone-my_utils.R", "Fix a bug")` | 添加或更新变更日志条目 |
| `inquire_standalone()` | `inquire_standalone("r-lib", "rlang")` | 列出某个 GitHub 仓库中的独立脚本文件 |
| `browse_standalone()` | `browse_standalone()` | 在 GitHub 上搜索 R 包提供的独立脚本文件 |

### 工具函数

| 函数名 | 简单用法 | 用途 |
|:---|:---|:---|
| `current_packages()` | `current_packages()` | 需要为其调用添加命名空间的包 |
| `imported_functions()` | `imported_functions()` | `NAMESPACE` 中导入的函数名 |
| `is_dev_context()` | `is_dev_context()` | 当前目录是否为包开发环境 |
| `get_positron_version()` | `get_positron_version()` | 当前运行的 Positron IDE 版本 |

## Addin

自 v0.1.23 起，`rpkgkit` 附带了一个可在 RStudio 中使用的 addin。它位于 `Addins` 菜单中，也可以通过 `Ctrl+Shift+P`（Windows/Linux）或 `Cmd+Shift+P`（macOS）访问。

如果想在 Positron 中使用 addin，可以试试 [Positron R Wizard](https://github.com/ntluong95/positron-r-wizard.git) 扩展。

## AI 技能

`rpkgkit` 附带一个 agent skill，告诉编码智能体何时应当使用 `rpkgkit` 以及如何调用它。它遵循 [Agent Skills](https://skills.sh) 规范，因此可用于 Claude Code、Codex、Cursor、Positron 以及其他兼容的智能体：

```bash
npx skills add WangLabCSU/rpkgkit --skill rpkgkit
```

加上 `-g` 可将其安装到所有项目，加上 `-a <agent>` 可跳过智能体选择提示。技能源代码位于 [`skills/rpkgkit/`](https://github.com/WangLabCSU/rpkgkit/tree/main/skills/rpkgkit)。

## 致谢

感谢以下人员和项目：

- [pedant](https://github.com/wurli/pedant) 包的作者 **Jacob Scott**、**Christopher T. Kenny** 和 **Sebastian Lammers**；其代码以 MIT 许可证收录在 `R/vendor-pedant.R` 中。
- [pkgdev](https://github.com/dieghernan/pkgdev) 包的作者 **Diego Hernangómez**；其代码以 MIT 许可证收录在 `R/vendor-pkgdev.R` 中。
- 所有报告问题、提出功能建议或帮助改进本包的贡献者和用户。
