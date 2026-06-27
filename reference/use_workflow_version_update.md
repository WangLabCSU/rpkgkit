# Create a GitHub Actions workflow to auto-update R package version

Copies the built-in `version_update.yml` workflow template to the target
package's `.github/workflows/` directory. The workflow automatically
bumps the R package version based on commit messages, or manually via
`workflow_dispatch` with a specified version type.

Version bump rules (from commit messages, case-insensitive):

- **major** / **breaking** - increments the major version (X.0.0)

- **feat** / **feature** / **minor** - increments the minor version
  (x.Y.0)

- **patch** / **fix** / **bug** - increments the patch version (x.y.Z)

- Otherwise, no version bump occurs

The `workflow_dispatch` input always overrides commit message detection.

## Usage

``` r
use_workflow_version_update(path = ".", overwrite = FALSE, color = "blue", ...)
```

## Arguments

- path:

  Character. Path to the package root directory. Defaults to the current
  working directory (`"."`).

- overwrite:

  Logical. If `TRUE`, overwrite an existing workflow file. Defaults to
  `FALSE`.

- color:

  badge color

- ...:

  pass to `badger::badge_devel`

## Value

Invisibly returns the path to the created workflow file.

## Examples

``` r
if (FALSE) { # \dontrun{
temp <- tempdir()
usethis::create_package(temp)
use_workflow_version_update(temp)
use_workflow_version_update(temp, overwrite = TRUE)
} # }
```
