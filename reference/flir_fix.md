# Fix R code or package using flir

Automatically detect the type of path (file, package, or directory) and
apply the appropriate flir fix function.

## Usage

``` r
flir_fix(path = NULL, ...)
```

## Arguments

- path:

  A file path, package directory path, or NULL. If NULL and running in
  RStudio, uses the active document path.

- ...:

  Additional arguments passed to the underlying flir fix function.

## Value

Invisibly returns the result from the called flir function.

## Details

The function determines the fix strategy based on the path type:

- If `path` points to an existing file, calls
  [`flir::fix()`](https://flir.etiennebacher.com/reference/fix.html)

- If `path` is a package directory (contains DESCRIPTION), calls
  [`flir::fix_package()`](https://flir.etiennebacher.com/reference/fix.html)

- If `path` is a directory, calls
  [`flir::fix_dir()`](https://flir.etiennebacher.com/reference/fix.html)

## Examples

``` r
tmp <- tempfile(fileext = ".R")
writeLines("a<-1+1", tmp)
flir_fix(tmp)
#> ℹ Fixing R code in /tmp/Rtmp88Qrsk/file1b196a060cad.R
#> ℹ Going to check 1 file.
#> ✔ No fixes needed.
cat(readLines(tmp, warn = FALSE), sep = "\n")
#> a<-1+1
```
