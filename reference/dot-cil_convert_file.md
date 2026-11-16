# Internal: rewrite the integer literals of one file

Reads `path` once, rewrites it and writes it back only when something
changed, so already-converted files keep their modification time.

## Usage

``` r
.cil_convert_file(path, verbose = FALSE)
```

## Arguments

- path:

  Character string; path to an R file.

- verbose:

  Logical; report the outcome with `cli`.

## Value

`TRUE` when the file was rewritten, `FALSE` otherwise.
