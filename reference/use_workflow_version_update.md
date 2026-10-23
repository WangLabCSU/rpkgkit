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
use_workflow_version_update(
  path = NULL,
  overwrite = FALSE,
  color = "blue",
  ...
)
```

## Arguments

- path:

  Character. Path to the package root directory. If `NULL` (the
  default), uses the current working directory.

- overwrite:

  Logical. If `TRUE`, overwrite an existing workflow file. Defaults to
  `FALSE`.

- color:

  badge color

- ...:

  pass to
  [`badger::badge_devel`](https://rdrr.io/pkg/badger/man/badge_devel.html)

## Value

Invisibly returns the path to the created workflow file.

## NEWS.md guard

Before writing anything, the action compares the version it is about to
set with the highest version documented in `NEWS.md` (heading lines such
as `# pkg 1.2.3 (2026-01-01)`). The bump is **skipped** when the new
version is greater than that maximum, so that no release is shipped
without a matching `NEWS.md` entry. When `NEWS.md` is missing or holds
no version heading, the check is bypassed with a warning.

## Rust crate version

When the package ships Rust code, the action also reads the `version`
key of the `[package]` table in `src/rust/Cargo.toml` and rewrites it to
the new version. The rest of the manifest is left untouched and the same
`NEWS.md` guard applies, so the crate version never exceeds the highest
version documented in `NEWS.md`. The file is skipped when it is absent
or declares no literal version (for example `version.workspace = true`).

## Examples

``` r
if (FALSE) { # \dontrun{
temp <- tempdir()
usethis::create_package(temp)
use_workflow_version_update(temp)
use_workflow_version_update(temp, overwrite = TRUE)
} # }
```
