# Code Convertion

``` r

library(rpkgkit)
#> ✔ rpkgkit v0.1.21 loaded [2 ms]
```

## Qualify package function calls

[`make_func_call_explicit()`](https://wanglabcsu.github.io/rpkgkit/reference/make_func_call_explicit.md)
adds namespace qualifiers to calls from selected packages.
[`package_func_call_explicit()`](https://wanglabcsu.github.io/rpkgkit/reference/make_func_call_explicit.md)
applies the same operation throughout a package.

``` r

file <- tempfile(fileext = ".R")
writeLines(
  c(
    "starwars |>",
    "  mutate(name, bmi = mass / ((height / 100)^2)) |>",
    "  select(name:mass, bmi)"
  ),
  file
)

make_func_call_explicit(file, use_packages = "dplyr")
#> ℹ Retrieving function calls from dplyr
#> ✔ Successfully made function call explicit in /tmp/RtmpapMdEy/file205677948b42.R
readLines(file) |> cli::cli_code()
#> dplyr::starwars |>
#>   dplyr::mutate(name, bmi = mass / ((height / 100)^2)) |>
#>   dplyr::select(name:mass, bmi)
```

## Find unmatched glue braces

[`detect_lost_glue_brace()`](https://wanglabcsu.github.io/rpkgkit/reference/detect_lost_glue_brace.md)
checks one file;
[`package_lost_glue_brace()`](https://wanglabcsu.github.io/rpkgkit/reference/detect_lost_glue_brace.md)
checks an entire package. Both support `glue` and `cli` expressions.

``` r

file <- tempfile(fileext = ".R")
writeLines(
  c(
    'name <- "world"',
    'msg <- glue::glue("Hello, {name!")',
    'cli::cli_alert_warning("{.field warning}}")'
  ),
  file
)

detect_lost_glue_brace(file)
#> msg <- glue::glue("Hello, {name!")
#>                           ^^^^^^
#> cli::cli_alert_warning("{.field warning}}")
#>                         ^^^^^^^^^^^^^^^^^
#> ✖ Found 2 lines with mismatched braces: 2 and 3
```

## Name positional arguments

[`make_func_arg_explicit()`](https://wanglabcsu.github.io/rpkgkit/reference/make_func_arg_explicit.md)
makes arguments in one file explicit, and
[`package_func_arg_explicit()`](https://wanglabcsu.github.io/rpkgkit/reference/make_func_arg_explicit.md)
applies this transformation across a package.

``` r

file <- tempfile(fileext = ".R")
writeLines("vapply(1:9, function(x) x * 2, numeric(1))", file)
make_func_arg_explicit(file)
#> ✔ Made function arguments explicit in /tmp/RtmpapMdEy/file20562e3825c6.R
readLines(file) |> cli::cli_code()
#> vapply(X = 1:9, FUN = function(x) x * 2, FUN.VALUE = numeric(length = 1))
```

## Rename functions

Use
[`rename_func()`](https://wanglabcsu.github.io/rpkgkit/reference/rename_func.md)
to apply a naming style to function definitions in a file.

``` r

file <- tempfile(fileext = ".R")
writeLines("this_is_a_function <- function() message('Hello, world')", file)
rename_func(file, style = "camelCase")
#> ✔ Renamed 1 function to "camelCase" style in /tmp/RtmpapMdEy/file2056598afbb5.R
readLines(file) |> cli::cli_code()
#> thisIsAFunction <- function() message('Hello, world')
```

## Detect print() and cat()

[`detect_print_and_cat()`](https://wanglabcsu.github.io/rpkgkit/reference/detect_print_and_cat.md)
reports [`print()`](https://rdrr.io/r/base/print.html) and
[`cat()`](https://rdrr.io/r/base/cat.html) calls in one file.
[`package_print_and_cat()`](https://wanglabcsu.github.io/rpkgkit/reference/detect_print_and_cat.md)
checks an entire package. Set `fix = TRUE` to replace those calls in the
selected file with [`message()`](https://rdrr.io/r/base/message.html).

``` r

file <- tempfile(fileext = ".R")
writeLines("print('Hello, world')", file)
detect_print_and_cat(file)
#> print('Hello, world') [message]
#> ^^^^^^
#> ✖ Found 1 unsupported call on line 1.
```

``` r

detect_print_and_cat(file, fix = TRUE)
#> ✔ Fixed 1 line in file2056b292452.R.
#> print('Hello, world') [message]
#> ^^^^^^
#> ✖ Found 1 unsupported call on line 1.
readLines(file) |> cli::cli_code()
#> message('Hello, world')
```

## Detect unmatched nocov markers

[`detect_unmatched_nocov_marker()`](https://wanglabcsu.github.io/rpkgkit/reference/detect_unmatched_nocov_marker.md)
checks the `# nocov start` and `# nocov end` markers of one file, and
[`package_unmatched_nocov_marker()`](https://wanglabcsu.github.io/rpkgkit/reference/detect_unmatched_nocov_marker.md)
checks a whole package. A file may hold at most one marker of each kind,
so every further start or end is reported with its line and column,
together with a start or an end that has no counterpart and an end
placed before the start. Both counts must therefore match: an unclosed
start is reported as well, because `covr::package_coverage()` aborts on
such a range with a “range start but only range ends” error.

Detection is purely textual, so a marker inside a string literal or a
roxygen comment is reported as well (as covr does); such a marker has no
effect on coverage, so it is usually a leftover to remove. Nothing is
rewritten — the offending comment is pointed at and the fix is left to
you.

``` r

file <- tempfile(fileext = ".R")
writeLines(
  c(
    "# nocov start",
    "f <- function(x) x + 1",
    "# nocov start",
    "# nocov end"
  ),
  file
)

detect_unmatched_nocov_marker(file)
#> ✖ `nocov start` at line 3, column 1: only one `nocov start` is allowed per file, the first is `nocov start` at line 1, column 1.
#> # nocov start
#> ^^^^^^^^^^^^^
#> ✖ Found 1 mismatched `nocov` marker on line 3.
```

A `# nocov start` that is never closed is reported as well:

``` r

writeLines(c("# nocov start", "g <- function(y) y"), file)
detect_unmatched_nocov_marker(file)
#> ✖ `nocov start` at line 1, column 1 has no matching `nocov end`.
#> # nocov start
#> ^^^^^^^^^^^^^
#> ✖ Found 1 mismatched `nocov` marker on line 1.
```

``` r

pkg <- file.path(tempdir(), "demo")
dir.create(file.path(pkg, "R"), recursive = TRUE, showWarnings = FALSE)
writeLines(
  c("Package: demo", "Version: 0.0.1"),
  file.path(pkg, "DESCRIPTION")
)
writeLines(c("g <- function(y) y", "# nocov end"), file.path(pkg, "R", "g.R"))

package_unmatched_nocov_marker(pkg)
#> R/g.R: 2:
#> ✖ `nocov end` at line 2, column 1 has no matching `nocov start`.
#> # nocov end
#> ^^^^^^^^^^^
#> ✖ Found 1 mismatched `nocov` marker in 1 of 1 file.
```

## Convert function syntax

Convert between `function()` and the short `\()` syntax.

``` r

file <- tempfile(fileext = ".R")
writeLines("f <- function(x) x^2", file)
convert_func_syntax(file, "to_lambda")
#> ✔ Converted function definitions in /tmp/RtmpapMdEy/file20562dd39b63.R to "to_lambda"
readLines(file) |> cli::cli_code()
#> f <- \(x) x^2
```

``` r

convert_func_syntax(file, "to_explicit")
#> ✔ Converted function definitions in /tmp/RtmpapMdEy/file20562dd39b63.R to "to_explicit"
readLines(file) |> cli::cli_code()
#> f <- function(x) x^2
```

## Modernize knitr chunk headers

[`convert_knitr_chunk_header()`](https://wanglabcsu.github.io/rpkgkit/reference/convert_knitr_chunk_header.md)
converts legacy R Markdown chunk options to the current comment-based
syntax.

``` r

file <- tempfile(fileext = ".Rmd")
writeLines(c("```{r, echo=TRUE, fig.width=10}", "x <- 1", "```"), file)
convert_knitr_chunk_header(file)
```

    #> ℹ Converting knitr chunk headers in /tmp/RtmpapMdEy/file2056737d5d66.Rmd
    readLines(file) |> cli::cli_code()

    #> ```{r}
    #> #| echo = TRUE,
    #> #| fig.width = 10
    #> x <- 1
    #> ```

## Switch pipe operators

[`convert_pipe()`](https://wanglabcsu.github.io/rpkgkit/reference/convert_pipe.md)
rewrites pipes in one file between `%>%` and `|>`. Strings, comments,
and the other magrittr operators (`%<>%`, `%$%`) are left unchanged.

``` r

file <- tempfile(fileext = ".R")
writeLines("mtcars %>% dplyr::filter(cyl > 4)", file)
convert_pipe(file, direction = "to_base")
#> ✔ Converted pipes in /tmp/RtmpapMdEy/file205626337e4.R ("to_base")
readLines(file) |> cli::cli_code()
#> mtcars |> dplyr::filter(cyl > 4)
```

Use
[`package_convert_pipe()`](https://wanglabcsu.github.io/rpkgkit/reference/convert_pipe.md)
to process `.R` and `.r` files below a package’s `R/` directory.

``` r

package_convert_pipe(".", direction = "to_base")
```

## Add integer suffixes

[`convert_int_literals()`](https://wanglabcsu.github.io/rpkgkit/reference/convert_int_literals.md)
adds `L` to bare integer literals while leaving strings, comments,
floating-point values, and existing suffixes unchanged.

``` r

file <- tempfile(fileext = ".R")
writeLines("x <- seq_len(10) # length 10", file)
convert_int_literals(file)
#> ✔ Added explicit integer suffixes in /tmp/RtmpapMdEy/file20565c0117c8.R
readLines(file) |> cli::cli_code()
#> x <- seq_len(10L) # length 10
```

Use
[`package_convert_int_literals()`](https://wanglabcsu.github.io/rpkgkit/reference/convert_int_literals.md)
to process `.R` and `.r` files below a package’s `R/` and `tests/`
directories.

``` r

package_convert_int_literals(".")
```

## Convert non-ASCII source code

[`convert_nonascii_code()`](https://wanglabcsu.github.io/rpkgkit/reference/convert_nonascii_code.md)
converts non-ASCII source to Unicode escape sequences when needed for
CRAN-compatible source files. It accepts either a file path or an R
expression.

``` r

file <- tempfile()
writeLines("foo <- \\() message('滚滚长江东逝水')", file)
convert_nonascii_code(file, overwrite = TRUE)
#> ℹ Converted content written to /tmp/RtmpapMdEy/file20567d0fb2b9
readLines(file) |> cli::cli_code()
#> foo <- \() message('\u6eda\u6eda\u957f\u6c5f\u4e1c\u901d\u6c34')
```

``` r

convert_nonascii_code({
  cli::cli_alert_info("明月几时有")
  cli::cli_alert_warning("把酒问青天")
})
#> ℹ Converted code (copy from console):
#> {
#>   cli::cli_alert_info("\u660e\u6708\u51e0\u65f6\u6709")
#>   cli::cli_alert_warning("\u628a\u9152\u95ee\u9752\u5929")
#> }
```
