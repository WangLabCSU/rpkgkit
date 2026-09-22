# rpkgkit standalone scripts

``` r

library(rpkgkit)
dir <- file.path(tempdir(), "example")
usethis::create_package(dir, open = FALSE)
usethis::local_project(dir)
usethis::use_readme_md(open = FALSE)
```

## Import standalone helpers

`rpkgkit` includes utilities that can also be imported directly into
another project with
[`usethis::use_standalone()`](https://usethis.r-lib.org/reference/use_standalone.html).

``` r

usethis::use_standalone("WangLabCSU/rpkgkit", "args_to_func")
```

### Match arguments to functions

The `args_to_func.R` standalone script provides helpers for matching a
list of arguments to compatible functions.

``` r

f1 <- function(a, b) a + b
f2 <- function(x, y, ...) x * y
f3 <- function(p, q) p - q

args <- list(a = 1, b = 2)
match_func_to_args(args, f1, f2, f3)
```

``` r

args <- list(a = 1, b = 2, x = 3, y = 4)
foo <- function(x, y = 1) x + y
filter_args_for_func(args, foo)
```

### Show the caller of a cli message

The `caller_cli.R` standalone script decorates a `cli` function so its
output identifies the caller.

``` r

decorated <- add_caller_to_cli(cli::cli_alert_info)
foo1 <- \() {
  decorated("<- where is this called from?")
}
foo2 <- \() foo1()
bar <- function() foo2()
bar()
```

### Use colored cli output

The `colorful_cli.R` standalone script creates a `cli` environment with
convenient color classes.

``` r

color_cli <- create_colorful_cli_env()
color_cli$cli_alert_danger("{.red This is a red message}")
color_cli$cli_alert_info("{.blue This is a blue message}")
color_cli$cli_alert_info("{.orange This is an orange message}")

color_cli2 <- create_colorful_cli_env(cli_theme = generate_color_theme())
color_cli2$cli_alert_success(
  "{.violetred3 R}{.orange a}{.yellow i}{.green n}{.cyan b}{.blue o}{.purple w}"
)
```

### Add timestamps to cli output

The `ts_cli.R` standalone script creates timestamped `cli` functions.

``` r

ts_cli <- create_ts_cli_env()
ts_cli$cli_alert_info("Hello, world!")
```

## Manage standalone files in a package

Use
[`inquire_standalone()`](https://wanglabcsu.github.io/rpkgkit/reference/inquire_standalone.md)
to inspect standalone files in a GitHub repository and
[`browse_standalone()`](https://wanglabcsu.github.io/rpkgkit/reference/browse_standalone.md)
to search supported repositories.

``` r

try(inquire_standalone("r-lib/rlang"))
#> # A tibble: 13 × 9
#>    name              path  sha    size url   html_url git_url download_url type 
#>    <chr>             <chr> <chr> <int> <chr> <chr>    <chr>   <chr>        <chr>
#>  1 standalone-cli.R  R/st… 14c6… 18672 http… https:/… https:… https://raw… file 
#>  2 standalone-downs… R/st… 09b7…  9213 http… https:/… https:… https://raw… file 
#>  3 standalone-lazye… R/st… 50ce…  2313 http… https:/… https:… https://raw… file 
#>  4 standalone-lifec… R/st… 70f0…  6411 http… https:/… https:… https://raw… file 
#>  5 standalone-linke… R/st… 9ab2…  2167 http… https:/… https:… https://raw… file 
#>  6 standalone-obj-t… R/st… e9c3…  7175 http… https:/… https:… https://raw… file 
#>  7 standalone-purrr… R/st… 0c1d…  5501 http… https:/… https:… https://raw… file 
#>  8 standalone-rlang… R/st… 4da3…  1807 http… https:/… https:… https://raw… file 
#>  9 standalone-s3-re… R/st… 05f0…  6056 http… https:/… https:… https://raw… file 
#> 10 standalone-sizes… R/st… 03ee…  3069 http… https:/… https:… https://raw… file 
#> 11 standalone-types… R/st… 42c7…  6843 http… https:/… https:… https://raw… file 
#> 12 standalone-vctrs… R/st… a789… 14292 http… https:/… https:… https://raw… file 
#> 13 standalone-zeall… R/st… 5e9d…   843 http… https:/… https:… https://raw… file
```

``` r

try(browse_standalone())
#> ℹ Searching GitHub for standalone-*.R files
#> ■■■■■■■■■■■■■■■■                  50% | 100/200 items, page 1/2 | ETA  0s
#> ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■  100% | 200/200 items, page 2/2 | ETA  0s
#> # A tibble: 180 × 9
#>    repo       name  path  sha   url   html_url git_url repo_url repo_description
#>    <chr>      <chr> <chr> <chr> <chr> <chr>    <chr>   <chr>    <chr>           
#>  1 tidymodel… stan… R/st… 3f38… http… https:/… https:… https:/… A tidy unified …
#>  2 r-lib/rla… stan… R/st… 14c6… http… https:/… https:… https:/… Low-level API f…
#>  3 r-lib/rla… stan… R/st… a789… http… https:/… https:… https:/… Low-level API f…
#>  4 r-lib/rla… stan… R/st… 4da3… http… https:/… https:… https:/… Low-level API f…
#>  5 r-lib/rla… stan… R/st… 03ee… http… https:/… https:… https:/… Low-level API f…
#>  6 r-lib/rla… stan… R/st… 0c1d… http… https:/… https:… https:/… Low-level API f…
#>  7 r-lib/rla… stan… R/st… 5e9d… http… https:/… https:… https:/… Low-level API f…
#>  8 r-lib/rla… stan… R/st… e9c3… http… https:/… https:… https:/… Low-level API f…
#>  9 r-lib/rla… stan… R/st… 50ce… http… https:/… https:… https:/… Low-level API f…
#> 10 r-lib/rla… stan… R/st… 70f0… http… https:/… https:… https:/… Low-level API f…
#> # ℹ 170 more rows
```

Create a local standalone file with a standard metadata header:

``` r

create_standalone("foo", open = FALSE)
```

After editing standalone files, refresh their `last-updated` field:

``` r

update_time_in_standalone(path = "./R/standalone-foo.R")
```

Add a dated changelog entry to one or more standalone files:

``` r

add_changelog_in_standalone("R/standalone-foo.R", "Added foo function")
```
