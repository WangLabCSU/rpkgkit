# Make Function Arguments Explicit

Transform function calls in R source code so that all arguments are
passed with explicit parameter names.

The transformation is a minimal, position-based text edit: only the
missing `argument = ` prefixes are inserted into the original source.
Everything else is preserved verbatim, including comments inside
function bodies, blank lines, indentation and operator spacing.

If the function has a `...` formal, positional arguments that are
captured by `...` are left in place as-is. Calls that forward `...`
literally (e.g. `g(...)`) are skipped, because the number of arguments
that `...` expands to cannot be known statically.

Operators (`+`, `-`, `*`, `/`, etc.), subset operators (`[`, `[[`, `$`),
assignment (`<-`, `=`, `<<-`), and special syntax (`if`, `for`, `while`,
`repeat`, `{`, `(`, `function`) are not transformed.

## Usage

``` r
package_func_arg_explicit(path = NULL, skip_functions = NULL, ...)

make_func_arg_explicit(path = NULL, skip_functions = NULL, ...)
```

## Arguments

- path:

  Path to an R file to modify. If `NULL` and RStudio is available, the
  active document path is used.

- skip_functions:

  Optional character vector of function or operator names to skip during
  transformation (e.g. `c("my_special_fn")`). In addition to
  user-provided names, all built-in operators (`+`, `-`, etc.), special
  syntax forms (`if`, `for`, `{`, etc.), and all `%...%` infix operators
  (`%in%`, `%>%`, `%||%`, etc.) are always skipped automatically.

- ...:

  Additional arguments. Currently unused and must be empty.

## Value

Invisible `NULL`, called for its side effect of writing the transformed
code back to the file.

## Functions

- `package_func_arg_explicit()`: Processes all `.R` files in a package's
  `R/` directory, making function arguments explicit.

## Pipes and placeholders

The right-hand side of a pipe receives an extra argument from its
left-hand side, so that argument is counted during positional matching:
`x %>% str_remove("a")` becomes `x %>% str_remove(pattern = "a")`,
because the piped-in data already fills the first formal (`string`).

Placeholders are honoured. When a native pipe (`|>`) uses the `_`
placeholder, the piped value fills the formal named next to `_`, so no
leading argument is pre-claimed and the remaining positional arguments
are still matched: `x |> lm(y ~ z, data = _)` becomes
`x |> lm(formula = y ~ z, data = _)`. When a magrittr pipe (`%>%`,
`%<>%`, `%T>%`) contains `.` anywhere in its right-hand side, the piped
value is substituted at `.` instead of being inserted as the first
argument, and again no formal is pre-claimed: `x %>% f(., y)` becomes
`x %>% f(a = ., b = y)`.

## Single-file operation

Operates on one R file. When `path` is `NULL` and RStudio is available,
the currently active document is used automatically.

## Examples

``` r
# \donttest{
tf <- tempfile(fileext = ".R")
writeLines("vapply(1:9, function(x) x*2, numeric(1))", tf)
make_func_arg_explicit(tf)
#> ✔ Made function arguments explicit in /tmp/RtmplPre7l/file1ad236eb9324.R
cat(readLines(tf), sep = "\n")
#> vapply(X = 1:9, FUN = function(x) x*2, FUN.VALUE = numeric(length = 1))
# vapply(X = 1:9, FUN = function(x) x*2, FUN.VALUE = numeric(length = 1))
# }
```
