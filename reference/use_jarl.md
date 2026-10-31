# Create a `jarl.toml` configuration file

Writes a `jarl.toml` configuration file for
[jarl](https://jarl.etiennebacher.com/), the R linter written in Rust.
The file pins down the linting behaviour of every `jarl` invocation in
the project, so the command line, the editor integration and the
continuous integration workflow all agree.

- `jarl.toml` is looked up by `jarl` in the current working directory,
  then in its parent directories, and finally in the user configuration
  directory. `jarl` reads a single configuration file, the closest one
  wins.

- All lint options live in the `[lint]` table. Command line flags always
  take precedence over the file.

- `[lint.per-file-ignores]` must come last in the file, otherwise the
  options written after it are parsed as glob patterns; the generated
  file does not use that table.

- When `path` is the root of an R package (contains a `DESCRIPTION`
  file), `jarl.toml` is also added to `.Rbuildignore` (inside a scoped
  project, so the active project of the calling session is restored
  afterwards).

Read the [configuration
reference](https://jarl.etiennebacher.com/reference/config-file) for the
full list of options, and the [continuous integration
guide](https://jarl.etiennebacher.com/howto/ci) to run `jarl` on every
push with the `etiennebacher/setup-jarl` action.

## Usage

``` r
use_jarl(path = NULL, overwrite = FALSE, ...)
```

## Arguments

- path:

  Character. Path to the directory where `jarl.toml` should be written.
  If `NULL` (the default), the current working directory is used.

- overwrite:

  Logical. If `TRUE`, overwrite an existing `jarl.toml` file. Defaults
  to `FALSE`.

- ...:

  Must be empty. Reserved for future arguments.

## Value

Invisibly returns the path to the created `jarl.toml` file.

## Examples

``` r
tmp <- tempdir()
use_jarl(path = tmp, overwrite = TRUE)
#> ✔ Created /tmp/RtmplPre7l/jarl.toml.
#> • Read jarl's editor support
#>   (<https://jarl.etiennebacher.com/reference/config-file>) to learn how to
#>   invoke jarl in your preferred editor.
#> • Read jarl's continuous integration
#>   (<https://jarl.etiennebacher.com/howto/ci>) to learn about GHA workflows that
#>   continuously run linting checks.
readLines(file.path(tmp, "jarl.toml"))
#>  [1] "# jarl configuration file"                                                 
#>  [2] "# Reference: https://jarl.etiennebacher.com/reference/config-file"         
#>  [3] ""                                                                          
#>  [4] "[lint]"                                                                    
#>  [5] "# Rules enabled on top of jarl's default rule set. The `TESTTHAT` group is"
#>  [6] "# opt-in, so it has to be requested explicitly."                           
#>  [7] "extend-select = [\"TESTTHAT\"]"                                            
#>  [8] ""                                                                          
#>  [9] "# Files or directories that jarl should not lint."                         
#> [10] "exclude = [\"R/vendor-*.R\"]"                                              
#> [11] ""                                                                          
#> [12] "# Also lint the R code inside `@examples` and `@examplesIf` tags"          
#> [13] "# (the default)."                                                          
#> [14] "check-roxygen = true"                                                      
#> [15] ""                                                                          
#> [16] "# Rules that `jarl check --fix` is allowed to fix (all rules by default)." 
#> [17] "# fixable = [\"PERF\"]"                                                    
#> [18] ""                                                                          
#> [19] "# Rules that `jarl check --fix` must leave untouched."                     
#> [20] "# unfixable = [\"undesirable_function\"]"                                  
```
