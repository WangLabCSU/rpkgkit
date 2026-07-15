# Create a GitHub Actions Workflow to Sync Main to Test Branch

Copies the built-in `sync_test_branch.yml` workflow template and the
corresponding `sync-test-branch` composite action to the target
package's `.github/` directory. The workflow triggers on push to
`main`/`master` and force-pushes the main branch contents onto the
`test` branch.

**Safety mechanism**: If the `test` branch contains commits that are not
reachable from `main` (i.e., unmerged work-in-progress), the sync is
skipped to avoid overwriting unmerged changes.

This enables convenient isolated debugging: work on the `test` branch,
push experimental changes, and each push to `main` will reset `test` to
match `main` (as long as no unmerged work exists on `test`).

## Usage

``` r
use_workflow_test_branch(path = NULL, overwrite = FALSE)
```

## Arguments

- path:

  Character. Path to the package root directory. If `NULL` (the
  default), uses the current working directory.

- overwrite:

  Logical. If `TRUE`, overwrite existing workflow and action files.
  Defaults to `FALSE`.

## Value

Invisibly returns the path to the created workflow file.

## Examples

``` r
if (FALSE) { # \dontrun{
temp <- tempdir()
usethis::create_package(temp)
use_workflow_test_branch(temp)
use_workflow_test_branch(temp, overwrite = TRUE)
} # }
```
