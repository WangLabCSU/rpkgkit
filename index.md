# rpkgkit

## Overview

`rpkgkit` provides utilities for creating and maintaining R packages.
The functions support common development tasks such as managing
standalone scripts, maintaining `NEWS.md`, modernizing R source,
configuring package infrastructure, and maintaining README files.

Most functions detect the active file context in RStudio and Positron,
so a file path can often be omitted.

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
