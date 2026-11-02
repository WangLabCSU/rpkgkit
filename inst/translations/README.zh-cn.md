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
