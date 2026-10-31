# rpkgkit standalone scripts

``` r

library(rpkgkit)
#> ✔ rpkgkit v0.1.22 loaded [1 ms]
dir <- file.path(tempdir(), "example")
usethis::create_package(dir, open = FALSE)
#> ✔ Creating /tmp/RtmpCTsYN5/example/.
#> ✔ Setting active project to "/tmp/RtmpCTsYN5/example".
#> ✔ Creating R/.
#> ✔ Writing DESCRIPTION.
#> Package: example
#> Title: What the Package Does (One Line, Title Case)
#> Version: 0.0.0.9000
#> Authors@R (parsed):
#>     * First Last <first.last@example.com> [aut, cre]
#> Description: What the package does (one paragraph).
#> License: `use_mit_license()`, `use_gpl3_license()` or friends to
#>     pick a license
#> Config/roxygen2/version: 8.1.1
#> Encoding: UTF-8
#> Roxygen: list(markdown = TRUE)
#> ✔ Writing NAMESPACE.
#> ✔ Setting active project to "<no active project>".
usethis::local_project(dir)
#> ✔ Setting active project to "/tmp/RtmpCTsYN5/example".
usethis::use_readme_md(open = FALSE)
#> ✔ Writing README.md.
#> ☐ Update README.md to include installation instructions.
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

try(list2env(validate_add(), envir = environment()))
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
#> ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■  100% | 200/200 items, page 2/2 | ETA  0s
#> # A tibble: 6 × 9
#>   repo        name  path  sha   url   html_url git_url repo_url repo_description
#>   <chr>       <chr> <chr> <chr> <chr> <chr>    <chr>   <chr>    <chr>           
#> 1 tidymodels… stan… R/st… 3f38… http… https:/… https:… https:/… A tidy unified …
#> 2 r-lib/rlang stan… R/st… 14c6… http… https:/… https:… https:/… Low-level API f…
#> 3 r-lib/rlang stan… R/st… a789… http… https:/… https:… https:/… Low-level API f…
#> 4 r-lib/rlang stan… R/st… 4da3… http… https:/… https:… https:/… Low-level API f…
#> 5 r-lib/rlang stan… R/st… 03ee… http… https:/… https:… https:/… Low-level API f…
#> 6 r-lib/rlang stan… R/st… 0c1d… http… https:/… https:… https:/… Low-level API f…
```

Create a local standalone file with a standard metadata header:

``` r

create_standalone("foo", path = file.path(dir, "R"), open = FALSE)
#> Warning in system2("git", c("-C", dirname(path), "remote", "get-url",
#> "origin"), : running command ''git' -C /tmp/RtmpCTsYN5/example remote get-url
#> origin' had status 128
#> ✔ Created standalone file: /tmp/RtmpCTsYN5/example/R/standalone-foo.R
```

### Validate the standalone file layout

[`check_standalone()`](https://wanglabcsu.github.io/rpkgkit/reference/check_standalone.md)
verifies that a custom standalone file follows the layout consumed by
[`usethis::use_standalone()`](https://usethis.r-lib.org/reference/use_standalone.html).
It checks the `# ---` header (the required `repo`, `file`,
`last-updated` and `license` slots, the optional `imports` slot, and the
format of each value), that every documented function carries `@noRd`,
and that a `# nocov start` marker precedes all functions.

``` r

check_standalone(path = file.path(dir, "R/standalone-foo.R"))
#> ── standalone check results ──────────────────────────────── standalone-foo.R ──
#> ❯ The header is missing the required slot `repo`. ... ERROR
#> ❯ The header slot `imports` is empty; remove it if there are no dependencies.
#> ... NOTE
#> ❯ The header has non-standard slots: `dependency`. ... NOTE
#> ❯ No top-level function definitions found. ... NOTE
#> ✔ nocoverage start marker
#> 
#> Duration: 0.01s
#> 1 error ✖ | 0 warning ✔ | 3 notes ✖
```

Findings are printed in the style of
[`devtools::check()`](https://devtools.r-lib.org/reference/check.html),
and the counts are returned invisibly as
`list(error = , warning = , note = )`. An error in a check point skips
the remaining ones, while warnings and notes never stop the run.

After editing standalone files, refresh their `last-updated` field:

``` r

update_time_in_standalone(path = file.path(dir, "R/standalone-foo.R"))
#> ✔ Updated last-updated to "2026-10-31" in 1 file.
```

Add a dated changelog entry to one or more standalone files:

``` r

add_changelog_in_standalone(
  path = file.path(dir, "R/standalone-foo.R"),
  "Added foo function"
)
```
