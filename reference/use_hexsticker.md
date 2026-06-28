# Use Hex Sticker in README

Adds a hex sticker image (optionally wrapped in a hyperlink) at the end
of the top-level heading (the line starting with `# `) in `README.md`.
This is a common pattern for R package README files.

## Usage

``` r
use_hexsticker(
  img_path,
  url = NULL,
  alt_text = "package logo",
  height = 139,
  align = "right",
  path = ".",
  ...
)
```

## Arguments

- img_path:

  Character. Path to the image file (e.g., `"man/figures/logo.png"`).

- url:

  Character. URL the image should link to. If `NULL` (default), no
  hyperlink is added.

- alt_text:

  Character. Alt text for the image. Defaults to `"package logo"`.

- height:

  Numeric or character. Image height in pixels. Defaults to `139`.

- align:

  Character. Image alignment attribute. Defaults to `"right"`.

- path:

  Character. Path to the package root directory. Defaults to the current
  working directory (`"."`).

- ...:

  Additional HTML attributes to include in the `<img>` tag as named
  arguments.

## Value

Invisibly returns `TRUE` on success.

## Examples

``` r
# \donttest{
temp <- tempdir()
writeLines("# Package Name", file.path(temp, "README.md"))
file.create(file.path(temp, "logo.png"))
#> [1] TRUE
use_hexsticker(file.path(temp, "logo.png"), url = "https://my-pkg-website.com", path = temp)
#> ✔ Added hex sticker reference to /tmp/RtmpIzFtE5/README.md
#> → Image: /tmp/RtmpIzFtE5/logo.png
# }
```
