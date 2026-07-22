# Make Function Arguments Explicit

Transform function calls in R source code so that all arguments are
passed with explicit parameter names. Uses a recursive tree-walking
approach: every function call node is inspected, the called function's
formals are retrieved, and positional arguments are given their formal
parameter name.

Transformation preserves all content outside the expression boundaries
(roxygen docs, section comments, blank lines). Inline comments on the
last line of a transformed expression are re-attached to the output.

If the function has a `...` formal, unmatched positional and named
arguments are left in place as-is (they are captured by `...`).

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

## Single-file operation

Operates on one R file. When `path` is `NULL` and RStudio is available,
the currently active document is used automatically.

## Examples

``` r
# \donttest{
tf <- tempfile(fileext = ".R")
writeLines("vapply(1:9, function(x) x*2, numeric(1))", tf)
make_func_arg_explicit(tf)
#> ✔ Made function arguments explicit in /tmp/RtmpSQrRz1/file1a43583f2bc9.R
cat(readLines(tf), sep = "\n")
#> vapply(X = 1:9, FUN = function(x) x * 2, FUN.VALUE = numeric(length = 1))
# vapply(X = 1:9, FUN = function(x) x*2, FUN.VALUE = numeric(1))
# }
```
