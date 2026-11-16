# Locate path-like defaults in the arguments of exported functions.

A top-level `name <- function(...)` definition is found with the
tokenizer of `crate::r_syntax`, its formals are split on top-level
commas, and every formal whose name matches `arg_pattern` and whose
default (as written in the source, whitespace collapsed) is not in
`allow` is reported. `exports = NULL` together with an empty
`export_patterns` means "check every top-level function".

## Usage

``` r
dfap_scan_text_rs(text, arg_pattern, exports, export_patterns, allow)
```

## Details

Character arguments are taken as `Vec<String>` (not `Strings`):
iterating a zero-length `Strings` panics in debug builds, and
`export_patterns` / `allow` are empty in the common case.
