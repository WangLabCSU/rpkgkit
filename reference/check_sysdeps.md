# Check whether system development dependencies are installed

Detects the system package manager, checks each system dependency, and
reports the result with cli. Argument validation uses rlang. On Windows,
`winget`, `choco` and `scoop` are supported (`scoop` is queried through
PowerShell).

## Usage

``` r
check_sysdeps(deps = NULL, manager = NULL, verbose = TRUE)
```

## Arguments

- deps:

  A character vector of system package names to check. Names must match
  the naming convention of the package manager in use. Alternative names
  can be given as `"a|b"`: the dependency counts as installed if any
  alternative is installed, and the first one is used in the install
  hint. If `NULL`, a built-in list of graphics and font related
  dependencies is used. There is no built-in list for `"winget"`,
  `"choco"` and `"scoop"`, so `deps` must be supplied for them.

- manager:

  The package manager: one of `"dpkg"`, `"rpm"`, `"pacman"`, `"apk"`,
  `"brew"`, `"winget"`, `"choco"`, or `"scoop"`. If `NULL`, it is
  detected automatically (on Linux via `/etc/os-release`, falling back
  to whichever manager is on the `PATH`).

- verbose:

  Logical. If `TRUE` (the default), print the check results. If `FALSE`,
  no messages are printed.

## Value

A named logical vector (package name -\> installed or not), returned
invisibly. It carries the attribute `"manager"` (the manager used) and,
if anything is missing, `"install_cmd"` (a suggested install command).

## Examples

``` r
# \donttest{
# `deps` must follow the naming convention of the manager in use, and the
# managers themselves are OS specific, so every example runs only where the
# matching executable is available.

# Fedora / RHEL / openSUSE
if (nzchar(Sys.which("rpm"))) {
  check_sysdeps(c("freetype-devel", "libwebp-devel"), manager = "rpm")
}
#> Package manager: rpm
#> ✖ freetype-devel
#> ✖ libwebp-devel
#> ! Missing 2 dependencies: freetype-devel and libwebp-devel
#> ℹ Try installing with: `sudo dnf install -y freetype-devel libwebp-devel`

# Debian / Ubuntu, with an alternative name for freetype
if (nzchar(Sys.which("dpkg"))) {
  check_sysdeps(
    c("libfreetype-dev|libfreetype6-dev", "libpng-dev"),
    manager = "dpkg"
  )
}
#> Package manager: dpkg
#> ✔ libfreetype-dev|libfreetype6-dev
#> ✔ libpng-dev
#> ✔ All 2 system dependencies installed.

# macOS
if (nzchar(Sys.which("brew"))) {
  check_sysdeps(manager = "brew")
}

# Windows: `winget`, `choco` and `scoop` have no built-in dependency list,
# so `deps` is always required.
if (nzchar(Sys.which("winget"))) {
  check_sysdeps(c("Git.Git", "Kitware.CMake"), manager = "winget")
}

# The result is a named logical vector that carries the manager used, so the
# missing dependencies can be extracted and reused in a script.
default_managers <- c("dpkg", "rpm", "pacman", "apk", "brew")
available <- default_managers[nzchar(Sys.which(default_managers))]
if (length(available) > 0L) {
  ok <- check_sysdeps(manager = available[[1L]], verbose = FALSE)
  attr(ok, "manager")
  ok[!ok]
}
#> named logical(0)
# }
```
