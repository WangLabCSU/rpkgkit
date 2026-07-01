# Create Multilingual README Files

Creates translated README files under `inst/` for a target R package and
prints badges that can be pasted into the main `README.md` to link to
each translation.

The five non-English United Nations official languages are used by
default: Chinese (`zh-cn`), Spanish (`es`), French (`fr`), Arabic
(`ar`), and Russian (`ru`). Any language code (including non-UN
languages) can be supplied via the `lang` argument.

## Usage

``` r
use_multilanguage_readme(
  lang = c("zh-cn", "es", "fr", "ar", "ru"),
  color = "blue",
  ...,
  path = NULL,
  overwrite = FALSE
)
```

## Arguments

- lang:

  Character vector of language codes (e.g. `"zh-cn"`, `"ja"`). Defaults
  to the five non-English UN official languages. Codes must be supported
  by the internal name mapping (see **Language Codes** below) or they
  will be used as-is for badge labels.

- color:

  Color of badge. Defaults to `"blue"`

- ...:

  Not used.

- path:

  Character. Path to the package root directory. If `NULL` (the
  default), uses the current working directory.

- overwrite:

  Logical. If `TRUE`, overwrite existing README translation files.
  Defaults to `FALSE`.

## Value

Invisibly returns a character vector of paths to the created files.

## Language Codes

The following codes have built-in display name mappings:

|         |                       |
|---------|-----------------------|
| Code    | Display Name          |
| `en`    | English               |
| `zh-cn` | Chinese (Simplified)  |
| `zh-tw` | Chinese (Traditional) |
| `es`    | Spanish               |
| `fr`    | French                |
| `de`    | German                |
| `pt`    | Portuguese            |
| `ja`    | Japanese              |
| `ko`    | Korean                |
| `ar`    | Arabic                |
| `ru`    | Russian               |
| `it`    | Italian               |
| `nl`    | Dutch                 |
| `pl`    | Polish                |
| `tr`    | Turkish               |
| `vi`    | Vietnamese            |
| `th`    | Thai                  |
| `id`    | Indonesian            |
| `hi`    | Hindi                 |

Unrecognised codes are used verbatim as badge labels.

## Examples

``` r
if (FALSE) { # \dontrun{
dir <- tempdir()
usethis::create_package(dir)
use_multilanguage_readme(path = dir)

# Custom languages
use_multilanguage_readme(c("de", "ja", "ko"), path = dir)
} # }
```
