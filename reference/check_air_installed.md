# Check that the air formatter is installed

Verifies that `air` (the R code formatter from Posit) is available on
the system PATH. If not, provides OS-specific installation instructions
and aborts with an informative error.

## Usage

``` r
check_air_installed()
```

## Value

Invisibly returns `TRUE` if `air` is found.

## Details

Installation methods per OS:

**Linux:**
`curl -LsSf https://github.com/posit-dev/air/releases/latest/download/air-installer.sh | sh`

**Windows:**
`powershell -ExecutionPolicy Bypass -c "irm https://github.com/posit-dev/air/releases/latest/download/air-installer.ps1 | iex"`

**macOS (Homebrew):** `brew install air`

**All platforms (uv):** `uv tool install air-formatter`
