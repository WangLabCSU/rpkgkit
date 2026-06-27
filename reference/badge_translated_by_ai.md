# Generate AI Translation Disclaimer Badge

Prints a shields.io badge and a blockquote note for each specified
language that can be copied into a translated README file to indicate
the content was AI-translated and has not been reviewed.

Each language entry consists of:

- A badge:
  `[![AI|<LANG>](https://img.shields.io/badge/AI-<LANG>-yellow)]()`

- A blockquote with the full disclaimer text in that language

## Usage

``` r
badge_translated_by_ai(lang = "en", color = "yellow")
```

## Arguments

- lang:

  Character vector of language codes (e.g. `"zh-cn"`, `"ja"`). Defaults
  to `NULL`, which outputs disclaimers for **all** 19 supported
  languages. Pass a single code to get one entry only.

- color:

  Color of badge. Defaults to `"yellow"`

## Value

Invisibly returns a named list of character vectors, where each element
contains the badge line and blockquote note for one language.

## Examples

``` r
if (FALSE) { # \dontrun{
# All 19 languages
badge_translated_by_ai()

# Just one language
badge_translated_by_ai("de")

# A few languages
badge_translated_by_ai(c("ja", "ko"))
} # }
```
