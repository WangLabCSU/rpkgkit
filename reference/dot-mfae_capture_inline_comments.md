# Extract trailing inline comments from source lines.

Returns a named list: line_number (character) -\> trailing comment text
(including the `#` and leading whitespace). Only lines that have
non-whitespace code before the first `#` are captured (i.e., full-line
comments are excluded).

## Usage

``` r
.mfae_capture_inline_comments(lines)
```
