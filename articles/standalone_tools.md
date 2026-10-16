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

### Print frequency tables

The `cli_table.R` standalone script prints frequency tables of a vector
with cli styling. `cli_table()` uses two aligned lines (headers, then
counts), while `cli_table_oneline()` collapses them into a single
`header: count` line. Both return the underlying `table` object
invisibly.

``` r

x <- c("apple", "pear", "apple", NA)

cli_table(x)
cli_table(x, head_format = ".strong", align = "center")

cli_table_oneline(x)
cli_table_oneline(mtcars$cyl, sep = " | ", count_format = NULL)
```

### Validate and transform arguments

The `make_arg_validator.R` standalone script builds reusable validators.
Give it an unquoted block of checks and coercions written in terms of
argument names; it returns a function that, called from inside your
function, returns the validated arguments as a named list.

``` r

validate_add <- make_arg_validator({
  if (!type %in% c("sum", "product")) {
    rlang::abort("`type` must be \"sum\" or \"product\".", call = NULL)
  }
  n <- as.integer(max(n, 1L))
})

add <- function(type = c("sum", "product"), n = 1L) {
  args <- validate_add()
  switch(args$type, sum = sum(1:args$n), product = prod(1:args$n))
}

add("sum", 3)
```

Errors raised inside the block reach the caller unchanged, and an
assignment to an existing argument is written back through the returned
list:

``` r

list2env(validate_add(), envir = environment())
```

Only names that already existed in the caller’s frame are returned, so a
validator updates arguments but never adds new ones. The same validator
can be shared by several functions, and `env` can be passed explicitly
to validate a list of options instead of a function frame.

## Manage standalone files in a package

Use
[`inquire_standalone()`](https://wanglabcsu.github.io/rpkgkit/reference/inquire_standalone.md)
to inspect standalone files in a GitHub repository and
[`browse_standalone()`](https://wanglabcsu.github.io/rpkgkit/reference/browse_standalone.md)
to search supported repositories.

``` r

try(inquire_standalone("r-lib/rlang")) |> head()
#> # A tibble: 6 × 9
#>   name               path  sha    size url   html_url git_url download_url type 
#>   <chr>              <chr> <chr> <int> <chr> <chr>    <chr>   <chr>        <chr>
#> 1 standalone-cli.R   R/st… 14c6… 18672 http… https:/… https:… https://raw… file 
#> 2 standalone-downst… R/st… 09b7…  9213 http… https:/… https:… https://raw… file 
#> 3 standalone-lazyev… R/st… 50ce…  2313 http… https:/… https:… https://raw… file 
#> 4 standalone-lifecy… R/st… 70f0…  6411 http… https:/… https:… https://raw… file 
#> 5 standalone-linked… R/st… 9ab2…  2167 http… https:/… https:… https://raw… file 
#> 6 standalone-obj-ty… R/st… e9c3…  7175 http… https:/… https:… https://raw… file
```

``` r

try(browse_standalone()) |> head()
#> ℹ Searching GitHub for standalone-*.R files
#> ■■■■■■■■■■■■■■■■                  50% | 100/200 items, page 1/2 | ETA  0s
#> Error in gh::gh("/search/code", q = "filename:standalone- language:R -filename:import-",  : 
#>   GitHub API error (429): try again in 11.168037061s
#> ℹ Read more at <https://docs.github.com/rest/search/search#search-code>
#> [1] "Error in gh::gh(\"/search/code\", q = \"filename:standalone- language:R -filename:import-\",  : \n  \033[1m\033[22mGitHub API error (429): try again in 11.168037061s\n\033[36mℹ\033[39m Read more at \033[3m\033[34m<https://docs.github.com/rest/search/search#search-code>\033[39m\033[23m\n"
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
