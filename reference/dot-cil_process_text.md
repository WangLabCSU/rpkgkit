# Internal: character-level integer-literal rewrite (implemented in Rust)

The character state machine (strings, raw strings, comments, hex/decimal
literals, signed exponents and the `# rpkgkit: not int` opt-out) now
lives in
[`cil_process_text_rs()`](https://wanglabcsu.github.io/rpkgkit/reference/cil_process_text_rs.md).

## Usage

``` r
.cil_process_text(text)
```
