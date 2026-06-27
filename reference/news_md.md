# Manage NEWS.md file for R packages

Functions to help manage the NEWS.md file in R packages according to
CRAN guidelines. Includes functions to add new entries and check the
format.

Validates the NEWS.md file against CRAN guidelines and common best
practices. Reports issues found and provides suggestions for fixes.

Reads and displays the NEWS.md file content with optional filtering.

Adds a new entry to the NEWS.md file following CRAN guidelines. Can
create a new version section if needed or add to an existing one.

## Usage

``` r
news_md_check(path = ".", strict = FALSE, verbose = TRUE)

news_md_show(path = ".", version = NULL, max_versions = NULL)

news_md_add_entry(
  entry,
  version = NULL,
  category = "NEW FEATURES",
  contributor = NULL,
  path = ".",
  date = NULL,
  open_section = TRUE
)
```

## Arguments

- path:

  Path to the package root. Defaults to the current working directory
  (`"."`).

- strict:

  If TRUE, treats warnings as errors. Default is FALSE.

- verbose:

  If TRUE, prints detailed information about checks performed.

- version:

  Package version number. If NULL, uses the version from DESCRIPTION.

- max_versions:

  Maximum number of versions to display. NULL shows all.

- entry:

  Text of the news entry (without leading "\* ").

- category:

  Category of the change (e.g., "NEW FEATURES", "BUG FIXES", "MINOR
  IMPROVEMENTS", "DOCUMENTATION", "DEPRECATED", "DEFUNCT", "BREAKING
  CHANGES", "PERFORMANCE", "TESTING", "INTERNAL CHANGES"). Default is
  "NEW FEATURES".

- contributor:

  GitHub username or name for attribution (optional).

- date:

  Date of the release. If NULL, uses today's date (YYYY-MM-DD format).

- open_section:

  If TRUE and the version section exists but isn't open (has content
  after it), creates a new section. If FALSE, adds to existing section.

## Value

A list with components:

- valid:

  Logical indicating if NEWS.md passes all checks.

- errors:

  Character vector of error messages.

- warnings:

  Character vector of warning messages.

- suggestions:

  Character vector of improvement suggestions.

Invisibly returns the content as a character vector.

Invisibly returns the path to the NEWS.md file.

## Details

The NEWS.md format follows CRAN recommendations:

- Version headers use `#` followed by "package version (date)"

- Major changes use `##` with category names (e.g., "NEW FEATURES", "BUG
  FIXES")

- Individual items use bullet points starting with `*`

- Contributor acknowledgments use `(@username)` at the end of items

- Dates should be in YYYY-MM-DD format

## Examples

``` r
if (FALSE) { # \dontrun{
temp <- tempdir()
usethis::create_package(temp)
file.create(file.path(temp, "NEWS.md"))
result <- news_md_check(temp)
if (!result$valid) {
  print(result$errors)
  print(result$warnings)
}
} # }
if (FALSE) { # \dontrun{
temp <- tempdir()
usethis::create_package(temp)
file.create(file.path(temp, "NEWS.md"))
news_md_add_entry("Added `foo()`", path = temp)

# Show latest version news
news_md_show(version = "latest", path = temp)

# Show last 3 versions
news_md_show(max_versions = 3, path = temp)
} # }
if (FALSE) { # \dontrun{
temp <- tempdir()
usethis::create_package(temp)
file.create(file.path(temp, "NEWS.md"))
# Add a bug fix entry
news_md_add_entry("Fixed issue with parsing large files.",
                  category = "BUG FIXES",
                  contributor = "johndoe",
                  path = temp)

# Add a new feature with specific version
news_md_add_entry("Added new function for data validation.",
                  version = "1.2.0",
                  category = "NEW FEATURES",
                  path = temp)
} # }
```
