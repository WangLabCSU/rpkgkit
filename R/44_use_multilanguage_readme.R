#' Create Multilingual README Files
#'
#' @description
#' Creates translated README files under `inst/` for a target R package and
#' prints badges that can be pasted into the main `README.md` to link to each
#' translation.
#'
#' The five non-English United Nations official languages are used by
#' default: Chinese (`zh-cn`), Spanish (`es`), French (`fr`),
#' Arabic (`ar`), and Russian (`ru`). Any language code (including
#' non-UN languages) can be supplied via the `lang` argument.
#'
#' @param lang Character vector of language codes (e.g. `"zh-cn"`, `"ja"`).
#'   Defaults to the five non-English UN official languages. Codes must be
#'   supported by the internal name mapping (see **Language Codes** below)
#'   or they will be used as-is for badge labels.
#'
#' @param color Color of badge. Defaults to `"blue"`
#' @param ... Not used.
#' @param path Character. Path to the package root directory. Defaults to
#'   the current working directory (`"."`).
#' @param overwrite Logical. If `TRUE`, overwrite existing README translation
#'   files. Defaults to `FALSE`.
#'
#' @section Language Codes:
#' The following codes have built-in display name mappings:
#'
#' | Code   | Display Name       |
#' |--------|--------------------|
#' | `en`   | English            |
#' | `zh-cn`| 简体中文           |
#' | `zh-tw`| 繁體中文           |
#' | `es`   | Español            |
#' | `fr`   | Français           |
#' | `de`   | Deutsch            |
#' | `pt`   | Português          |
#' | `ja`   | 日本語             |
#' | `ko`   | 한국어             |
#' | `ar`   | العربية           |
#' | `ru`   | Русский            |
#' | `it`   | Italiano           |
#' | `nl`   | Nederlands         |
#' | `pl`   | Polski             |
#' | `tr`   | Türkçe             |
#' | `vi`   | Tiếng Việt         |
#' | `th`   | ไทย               |
#' | `id`   | Bahasa Indonesia   |
#' | `hi`   | हिन्दी            |
#'
#' Unrecognised codes are used verbatim as badge labels.
#'
#' @return Invisibly returns a character vector of paths to the created files.
#' @export
#'
#' @examples
#' \dontrun{
#' dir <- tempdir()
#' usethis::create_package(dir)
#' use_multilanguage_readme(path = dir)
#'
#' # Custom languages
#' use_multilanguage_readme(c("de", "ja", "ko"), path = dir)
#' }
use_multilanguage_readme <- function(
  lang = c("zh-cn", "es", "fr", "ar", "ru"),
  color = "blue",
  ...,
  path = ".",
  overwrite = FALSE
) {
  rlang::check_dots_empty0()

  # -- Validate package root --
  if (!is_pkg(path)) {
    cli::cli_abort(c(
      "x" = "{.path {path}} is not an R package root.",
      ">" = "No {.file DESCRIPTION} found."
    ))
  }

  # -- Language display-name map --
  lang_names <- c(
    "en" = "English",
    "zh-cn" = "\u7b80\u4f53\u4e2d\u6587",
    "zh-tw" = "\u7e41\u9ad4\u4e2d\u6587",
    "es" = "Espa\u00f1ol",
    "fr" = "Fran\u00e7ais",
    "de" = "Deutsch",
    "pt" = "Portugu\u00eas",
    "ja" = "\u65e5\u672c\u8a9e",
    "ko" = "\ud55c\uad6d\uc5b4",
    "ar" = "\u0627\u0644\u0639\u0631\u0628\u064a\u0629",
    "ru" = "\u0420\u0443\u0441\u0441\u043a\u0438\u0439",
    "it" = "Italiano",
    "nl" = "Nederlands",
    "pl" = "Polski",
    "tr" = "T\u00fcrk\u00e7e",
    "vi" = "Ti\u1ebfng Vi\u1ec7t",
    "th" = "\u0e44\u0e17\u0e22",
    "id" = "Bahasa Indonesia",
    "hi" = "\u0939\u093f\u0928\u094d\u0926\u0940"
  )

  lang <- unique(lang)

  # -- Create inst/ directory if needed --
  inst_dir <- file.path(path, "inst/translations")
  dir.create(inst_dir, recursive = TRUE, showWarnings = FALSE)

  # -- Read package name from DESCRIPTION --
  desc <- read.dcf(file.path(path, "DESCRIPTION"))
  pkg <- desc[, "Package"]

  created_files <- character()

  for (code in lang) {
    display_name <- lang_names[code]
    if (is.na(display_name)) {
      display_name <- code
    }

    target_path <- file.path(inst_dir, sprintf("README.%s.md", code))

    if (file.exists(target_path)) {
      if (!isTRUE(overwrite)) {
        cli::cli_alert_info("{.file {target_path}} already exists, skipping.")
        next
      }
      cli::cli_alert_warning("Overwriting {.file {target_path}}.")
    }

    # Write a minimal template for the translator
    content <- sprintf(
      "# %s — %s\n\n<!-- TODO: Translate this README into %s -->\n",
      pkg,
      display_name,
      display_name
    )
    writeLines(content, target_path)
    cli::cli_alert_success("Created {.file {target_path}}.")
    created_files <- c(created_files, target_path)
  }

  # -- Print badges --
  badge_lines <- vapply(
    X = lang,
    FUN = function(code) {
      display_name <- lang_names[code]
      if (is.na(display_name)) {
        display_name <- code
      }

      encoded <- utils::URLencode(display_name, reserved = TRUE)
      sprintf(
        "[![%s](https://img.shields.io/badge/README-%s-$s)](inst/translations/README.%s.md)",
        display_name,
        encoded,
        color,
        code
      )
    },
    FUN.VALUE = character(1)
  )

  cli::cli_alert_success(
    "v" = "Created {length(created_files)} README translation file(s) in {.path inst/translations}.",
  )
  cli_inform_colored <- add_colors_to_cli(cli::cli_inform)
  cli_inform_colored(
    "{.red {(cli::symbol$checkbox_off)}} \
    {.cyan Consider pasting the following badges into your main {.file README.md}:}"
  )

  message("")
  message(paste(badge_lines, collapse = "\n"))
  message("")

  invisible(created_files)
}


#' Generate AI Translation Disclaimer Badge
#'
#' @description
#' Prints a shields.io badge and a blockquote note for each specified language
#' that can be copied into a translated README file to indicate the content
#' was AI-translated and has not been reviewed.
#'
#' Each language entry consists of:
#' - A badge: `[![AI|<LANG>](https://img.shields.io/badge/AI-<LANG>-yellow)]()`
#' - A blockquote with the full disclaimer text in that language
#'
#' @param lang Character vector of language codes (e.g. `"zh-cn"`, `"ja"`).
#'   Defaults to `NULL`, which outputs disclaimers for **all** 19 supported
#'   languages. Pass a single code to get one entry only.
#' @param color Color of badge. Defaults to `"yellow"`
#'
#' @return Invisibly returns a named list of character vectors, where each
#'   element contains the badge line and blockquote note for one language.
#' @export
#'
#' @examples
#' \dontrun{
#' # All 19 languages
#' badge_translated_by_ai()
#'
#' # Just one language
#' badge_translated_by_ai("de")
#'
#' # A few languages
#' badge_translated_by_ai(c("ja", "ko"))
#' }
badge_translated_by_ai <- function(lang = "en", color = "yellow") {
  # -- Language display-name map --
  lang_names <- c(
    "en" = "English",
    "zh-cn" = "\u7b80\u4f53\u4e2d\u6587",
    "zh-tw" = "\u7e41\u9ad4\u4e2d\u6587",
    "es" = "Espa\u00f1ol",
    "fr" = "Fran\u00e7ais",
    "de" = "Deutsch",
    "pt" = "Portugu\u00eas",
    "ja" = "\u65e5\u672c\u8a9e",
    "ko" = "\ud55c\uad6d\uc5b4",
    "ar" = "\u0627\u0644\u0639\u0631\u0628\u064a\u0629",
    "ru" = "\u0420\u0443\u0441\u0441\u043a\u0438\u0439",
    "it" = "Italiano",
    "nl" = "Nederlands",
    "pl" = "Polski",
    "tr" = "T\u00fcrk\u00e7e",
    "vi" = "Ti\u1ebfng Vi\u1ec7t",
    "th" = "\u0e44\u0e17\u0e22",
    "id" = "Bahasa Indonesia",
    "hi" = "\u0939\u093f\u0928\u094d\u0926\u0940"
  )

  # -- AI-disclaimer text in each language --
  ai_note <- c(
    "en" = "This content was translated by AI and has not been reviewed. It is not the author's native language and is for reference only.",
    "zh-cn" = "\u6b64\u5185\u5bb9\u7531\u4eba\u5de5\u667a\u80fd\u7ffb\u8bd1\u800c\u6210\uff0c\u975e\u539f\u4f5c\u8005\u6bcd\u8bed\u4e14\u672a\u7ecf\u5ba1\u67e5\uff0c\u8868\u8fbe\u4ec5\u4f9b\u53c2\u8003\u3002",
    "zh-tw" = "\u6b64\u5167\u5bb9\u7531\u4eba\u5de5\u667a\u80fd\u7ffb\u8b6f\u800c\u6210\uff0c\u975e\u539f\u4f5c\u8005\u6bcd\u8a9e\u4e14\u672a\u7d93\u5be9\u67e5\uff0c\u8868\u9054\u50c5\u4f9b\u53c3\u8003\u3002",
    "es" = "Este contenido ha sido traducido por IA y no ha sido revisado. No es la lengua materna del autor y es solo para referencia.",
    "fr" = "Ce contenu a \u00e9t\u00e9 traduit par IA et n'a pas \u00e9t\u00e9 r\u00e9vis\u00e9. Il ne s'agit pas de la langue maternelle de l'auteur et est fourni \u00e0 titre de r\u00e9f\u00e9rence uniquement.",
    "de" = "Dieser Inhalt wurde von KI \u00fcbersetzt und nicht \u00fcberpr\u00fcft. Es ist nicht die Muttersprache des Autors und dient nur als Referenz.",
    "pt" = "Este conte\u00fado foi traduzido por IA e n\u00e3o foi revisado. N\u00e3o \u00e9 a l\u00edngua nativa do autor e \u00e9 apenas para refer\u00eancia.",
    "ja" = "\u3053\u306e\u30b3\u30f3\u30c6\u30f3\u30c4\u306fAI\u306b\u3088\u3063\u3066\u7ffb\u8a33\u3055\u308c\u3066\u304a\u308a\u3001\u30ec\u30d3\u30e5\u30fc\u3055\u308c\u3066\u3044\u307e\u305b\u3093\u3002\u8457\u8005\u306e\u6bcd\u8a9e\u3067\u306f\u306a\u304f\u3001\u53c2\u8003\u307e\u3067\u306b\u3054\u63d0\u4f9b\u3057\u3066\u3044\u307e\u3059\u3002",
    "ko" = "\uc774 \ucee8\ud150\uce20\ub294 AI\ub85c \ubc88\uc5ed\ub418\uc5c8\uc73c\uba70 \uac80\ud1a0\ub418\uc9c0 \uc54a\uc558\uc2b5\ub2c8\ub2e4. \uc791\uc131\uc790\uc758 \ubaa8\uad6d\uc5b4\uac00 \uc544\ub2c8\uba70 \ucc38\uace0\uc6a9\uc73c\ub85c\ub9cc \uc81c\uacf5\ub429\ub2c8\ub2e4.",
    "ar" = "\u062a\u0645\u062a \u062a\u0631\u062c\u0645\u0629 \u0647\u0630\u0627 \u0627\u0644\u0645\u062d\u062a\u0648\u0649 \u0628\u0648\u0627\u0633\u0637\u0629 \u0627\u0644\u0630\u0643\u0627\u0621 \u0627\u0644\u0627\u0635\u0637\u0646\u0627\u0639\u064a \u0648\u0644\u0645 \u064a\u062a\u0645 \u0645\u0631\u0627\u062c\u0639\u062a\u0647. \u0625\u0646\u0647\u0627 \u0644\u064a\u0633\u062a \u0627\u0644\u0644\u063a\u0629 \u0627\u0644\u0623\u0645 \u0644\u0644\u0645\u0624\u0644\u0641 \u0648\u0647\u064a \u0644\u0644\u0625\u0634\u0627\u0631\u0629 \u0641\u0642\u0637.",
    "ru" = "\u042d\u0442\u043e\u0442 \u043a\u043e\u043d\u0442\u0435\u043d\u0442 \u043f\u0435\u0440\u0435\u0432\u0435\u0434\u0435\u043d \u0418\u0418 \u0438 \u043d\u0435 \u043f\u0440\u043e\u0432\u0435\u0440\u0435\u043d. \u042d\u0442\u043e \u043d\u0435 \u0440\u043e\u0434\u043d\u043e\u0439 \u044f\u0437\u044b\u043a \u0430\u0432\u0442\u043e\u0440\u0430 \u0438 \u043f\u0440\u0435\u0434\u043e\u0441\u0442\u0430\u0432\u043b\u0435\u043d\u043e \u0442\u043e\u043b\u044c\u043a\u043e \u0434\u043b\u044f \u0441\u043f\u0440\u0430\u0432\u043a\u0438.",
    "it" = "Questo contenuto \u00e8 stato tradotto da IA e non \u00e8 stato revisionato. Non \u00e8 la lingua madre dell'autore ed \u00e8 solo a scopo di riferimento.",
    "nl" = "Deze inhoud is vertaald door AI en niet beoordeeld. Het is niet de moedertaal van de auteur en is alleen ter referentie.",
    "pl" = "Ta tre\u015b\u0107 zosta\u0142a przet\u0142umaczona przez AI i nie zosta\u0142a sprawdzona. Nie jest to j\u0119zyk ojczysty autora i s\u0142u\u017cy wy\u0142\u0105cznie jako odniesienie.",
    "tr" = "Bu i\u00e7erik yapay zeka taraf\u0131ndan \u00e7evrilmi\u015ftir ve incelenmemi\u015ftir. Yazar\u0131n ana dili de\u011fildir ve yaln\u0131zca referans ama\u00e7l\u0131d\u0131r.",
    "vi" = "N\u1ed9i dung n\u00e0y \u0111\u01b0\u1ee3c d\u1ecbch b\u1edfi AI v\u00e0 ch\u01b0a \u0111\u01b0\u1ee3c xem x\u00e9t. \u0110\u00e2y kh\u00f4ng ph\u1ea3i l\u00e0 ti\u1ebfng m\u1eb9 \u0111\u1ebb c\u1ee7a t\u00e1c gi\u1ea3 v\u00e0 ch\u1ec9 mang t\u00ednh tham kh\u1ea3o.",
    "th" = "\u0e40\u0e19\u0e37\u0e49\u0e2d\u0e2b\u0e32\u0e19\u0e35\u0e49\u0e41\u0e1b\u0e25\u0e42\u0e14\u0e22 AI \u0e41\u0e25\u0e30\u0e22\u0e31\u0e07\u0e44\u0e21\u0e48\u0e44\u0e14\u0e49\u0e23\u0e31\u0e1a\u0e01\u0e32\u0e23\u0e15\u0e23\u0e27\u0e08\u0e2a\u0e2d\u0e1a \u0e44\u0e21\u0e48\u0e43\u0e0a\u0e48\u0e20\u0e32\u0e29\u0e32\u0e41\u0e21\u0e48\u0e02\u0e2d\u0e07\u0e1c\u0e39\u0e49\u0e40\u0e02\u0e35\u0e22\u0e19 \u0e41\u0e25\u0e30\u0e21\u0e35\u0e44\u0e27\u0e49\u0e40\u0e1e\u0e37\u0e48\u0e2d\u0e2d\u0e49\u0e32\u0e07\u0e2d\u0e34\u0e07\u0e40\u0e17\u0e48\u0e32\u0e19\u0e31\u0e49\u0e19",
    "id" = "Konten ini diterjemahkan oleh AI dan belum ditinjau. Ini bukan bahasa asli penulis dan hanya untuk referensi.",
    "hi" = "\u092f\u0939 \u0938\u093e\u092e\u0917\u094d\u0930\u0940 AI \u0926\u094d\u0935\u093e\u0930\u093e \u0905\u0928\u0941\u0935\u093e\u0926\u093f\u0924 \u0915\u0940 \u0917\u0908 \u0939\u0948 \u0914\u0930 \u0907\u0938\u0915\u0940 \u0938\u092e\u0940\u0915\u094d\u0937\u093e \u0928\u0939\u0940\u0902 \u0915\u0940 \u0917\u0908 \u0939\u0948\u0964 \u092f\u0939 \u0932\u0947\u0916\u0915 \u0915\u0940 \u092e\u093e\u0924\u0943\u092d\u093e\u0937\u093e \u0928\u0939\u0940\u0902 \u0939\u0948 \u0914\u0930 \u0915\u0947\u0935\u0932 \u0938\u0902\u0926\u0930\u094d\u092d \u0915\u0947 \u0932\u093f\u090f \u0939\u0948\u0964"
  )

  if (is.null(lang)) {
    lang <- names(ai_note)
  }
  lang <- intersect(lang, names(ai_note))

  cli_inform_colored <- add_colors_to_cli(cli::cli_inform)
  cli_inform_colored(
    "{.red {(cli::symbol$checkbox_off)}} \
    {.cyan Copy into the AI-translated {.file README} file(s):}"
  )
  message("")

  output <- vector(mode = "list", length = length(lang))
  for (code in lang) {
    display_name <- lang_names[code]
    if (is.na(display_name)) {
      display_name <- code
    }
    encoded <- utils::URLencode(display_name, reserved = TRUE)

    badge <- sprintf(
      "[![AI](https://img.shields.io/badge/AI-%s-%s)]()",
      encoded,
      color
    )
    note <- sprintf("> %s", ai_note[code])

    message(badge)
    message("")
    message(note)
    message("")

    output[[code]] <- c(badge, note)
  }

  invisible(output)
}
