# Load the language dictionary

Builds language display names and AI-disclaimer text using
[`intToUtf8()`](https://rdrr.io/r/base/utf8Conversion.html) to avoid any
non-ASCII characters in `R/` source code, which would trigger
`R CMD check` warnings.

## Usage

``` r
load_language_dict()
```

## Value

A named list with two elements:

- `lang_names`:

  A named character vector mapping language codes (e.g. `"zh-cn"`,
  `"de"`) to their display names.

- `ai_note`:

  A named character vector mapping language codes to the full
  AI-disclaimer text in that language.
