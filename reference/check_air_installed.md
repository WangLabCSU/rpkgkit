# Check that the air formatter is installed

Verifies that `air` (the R code formatter from Posit) is available on
the system PATH. In an interactive session, offers to install it when
missing. This prompt is skipped while tests are running. Otherwise, it
aborts with OS-specific installation instructions.

## Usage

``` r
check_air_installed()
```

## Value

Invisibly returns `TRUE` if `air` is found.

## Details

Installation methods per OS:

**Linux:**
`curl --proto '=https' --tlsv1.2 -LsSf https://github.com/posit-dev/air/releases/latest/download/air-installer.sh | sh`

**Windows:**
`powershell -ExecutionPolicy Bypass -c "irm https://github.com/posit-dev/air/releases/latest/download/air-installer.ps1 | iex"`

**macOS:**
`curl --proto '=https' --tlsv1.2 -LsSf https://github.com/posit-dev/air/releases/latest/download/air-installer.sh | sh`
