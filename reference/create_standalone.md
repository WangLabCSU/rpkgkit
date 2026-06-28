# Creates a new standalone R script with YAML metadata header. If `path` is an R package, the file is created in the `R/` subdirectory.

Creates a new standalone R script with YAML metadata header. If `path`
is an R package, the file is created in the `R/` subdirectory.

## Usage

``` r
create_standalone(
  standalone_name = NULL,
  path = NULL,
  standalone_head = list(license = "https://unlicense.org", imports = NULL, dependency =
    NULL, description = "This file provides..."),
  open = rlang::is_interactive(),
  ...
)
```

## Arguments

- standalone_name:

  Character. The name suffix for the standalone file (e.g., "my_utils"
  creates "standalone-my_utils.R").

- path:

  Character. Directory path where to create the file. Defaults to the
  current working directory (`"."`).

- standalone_head:

  List. Metadata for the file header with elements:

  - `license`: Character. License URL or identifier. Defaults to
    "https://unlicense.org".

  - `imports`: Character vector. Package dependencies to import.
    Defaults to NULL.

  - `dependency`: Character vector. Hard dependencies for the standalone
    file. Defaults to NULL.

  - `description`: Character. A short description of the standalone
    file. Defaults to "To be filled.".

- open:

  Logical. Whether to open the file in RStudio editor. Defaults to TRUE.

- ...:

  Additional arguments (must be empty).

## Value

Invisibly returns the path to the created file.

## Examples

``` r
# \donttest{
create_standalone("my_utils", path = tempdir())
#> ✔ Created standalone file: /tmp/RtmpFu9fmT/standalone-my_utils.R
# }
```
