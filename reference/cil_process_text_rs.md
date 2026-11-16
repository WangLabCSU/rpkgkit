# Add the explicit integer suffix `L` to bare integer literals.

Rust rewrite of `rpkgkit:::.cil_process_text()`. Strings, raw strings
and comments are copied verbatim; a literal is left alone when it
already carries `L` / `l`, when it is a float, a scientific notation, a
complex literal, or when it is glued to an identifier character.

## Usage

``` r
cil_process_text_rs(text)
```

## Details

A line preceded by a `# rpkgkit: not int` comment is left unchanged, so
a literal whose type has to stay double can be opted out line by line.
