#' Check whether system development dependencies are installed
#'
#' Detects the system package manager, checks each system dependency, and
#' reports the result with \pkg{cli}. Argument validation uses \pkg{rlang}.
#' On Windows, `winget`, `choco` and `scoop` are supported (`scoop` is queried
#' through PowerShell).
#'
#' @param deps A character vector of system package names to check. Names must
#'   match the naming convention of the package manager in use. Alternative
#'   names can be given as `"a|b"`: the dependency counts as installed if any
#'   alternative is installed, and the first one is used in the install hint.
#'   If `NULL`, a built-in list of graphics and font related dependencies is
#'   used. There is no built-in list for `"winget"`, `"choco"` and `"scoop"`,
#'   so `deps` must be supplied for them.
#' @param manager The package manager: one of `"dpkg"`, `"rpm"`, `"pacman"`,
#'   `"apk"`, `"brew"`, `"winget"`, `"choco"`, or `"scoop"`. If `NULL`, it is
#'   detected automatically (on Linux via `/etc/os-release`, falling back to
#'   whichever manager is on the `PATH`).
#' @param verbose Logical. If `TRUE` (the default), print the check results.
#'   If `FALSE`, no messages are printed.
#'
#' @return A named logical vector (package name -> installed or not),
#'   returned invisibly. It carries the attribute `"manager"` (the manager
#'   used) and, if anything is missing, `"install_cmd"` (a suggested install
#'   command).
#' @export
#'
#' @examples
#' \donttest{
#' # `deps` must follow the naming convention of the manager in use, and the
#' # managers themselves are OS specific, so every example runs only where the
#' # matching executable is available.
#'
#' # Fedora / RHEL / openSUSE
#' if (nzchar(Sys.which("rpm"))) {
#'   check_sysdeps(c("freetype-devel", "libwebp-devel"), manager = "rpm")
#' }
#'
#' # Debian / Ubuntu, with an alternative name for freetype
#' if (nzchar(Sys.which("dpkg"))) {
#'   check_sysdeps(
#'     c("libfreetype-dev|libfreetype6-dev", "libpng-dev"),
#'     manager = "dpkg"
#'   )
#' }
#'
#' # macOS
#' if (nzchar(Sys.which("brew"))) {
#'   check_sysdeps(manager = "brew")
#' }
#'
#' # Windows: `winget`, `choco` and `scoop` have no built-in dependency list,
#' # so `deps` is always required.
#' if (nzchar(Sys.which("winget"))) {
#'   check_sysdeps(c("Git.Git", "Kitware.CMake"), manager = "winget")
#' }
#'
#' # The result is a named logical vector that carries the manager used, so the
#' # missing dependencies can be extracted and reused in a script.
#' default_managers <- c("dpkg", "rpm", "pacman", "apk", "brew")
#' available <- default_managers[nzchar(Sys.which(default_managers))]
#' if (length(available) > 0L) {
#'   ok <- check_sysdeps(manager = available[[1L]], verbose = FALSE)
#'   attr(ok, "manager")
#'   ok[!ok]
#' }
#' }
check_sysdeps <- function(deps = NULL, manager = NULL, verbose = TRUE) {
  # ---- Argument checks (rlang) ----
  rlang::check_bool(verbose)
  if (is.null(manager)) {
    manager <- sysdeps_detect_manager()
  } else {
    manager <- rlang::arg_match(manager, sysdeps_managers())
    if (!sysdeps_has_cmd(manager)) {
      cli::cli_abort("{.code {manager}} was not found on this system.")
    }
  }
  if (is.null(deps)) {
    deps <- sysdeps_defaults()[[manager]]
    if (is.null(deps)) {
      cli::cli_abort(c(
        "No built-in dependency list for {.val {manager}}.",
        "i" = "Supply {.arg deps} explicitly."
      ))
    }
  } else {
    valid <- rlang::is_character(deps) &&
      length(deps) > 0L &&
      !anyNA(deps) &&
      all(nzchar(deps))
    if (!valid) {
      cli::cli_abort(
        "{.arg deps} must be a non-empty character vector without missing values."
      )
    }
    bad <- !grepl(sysdeps_name_regex(), deps)
    if (any(bad)) {
      cli::cli_abort(c(
        "{cli::qty(sum(bad))} {.arg deps} contains invalid package name{?s}.",
        "x" = "Invalid: {.val {deps[bad]}}",
        "i" = "Allowed characters: letters, digits, and {.code . _ + @ / - |}."
      ))
    }
  }
  deps <- unique(deps)

  # ---- Check each dependency ----
  ok <- vapply(deps, sysdeps_is_installed, logical(1L), manager = manager)
  absent <- deps[!ok]
  cmd <- if (length(absent) > 0L) sysdeps_install_cmd(manager, absent)

  # ---- Report (cli) ----
  if (verbose) {
    cli::cli_text("Package manager: {.field {manager}}")
    for (i in seq_along(deps)) {
      if (ok[[i]]) {
        cli::cli_alert_success("{.pkg {deps[[i]]}}")
      } else {
        cli::cli_alert_danger("{.pkg {deps[[i]]}}")
      }
    }
    if (length(absent) == 0L) {
      cli::cli_alert_success(
        "All {length(deps)} system dependenc{?y/ies} installed."
      )
    } else {
      cli::cli_alert_warning(
        "Missing {length(absent)} dependenc{?y/ies}: {.pkg {absent}}"
      )
      cli::cli_alert_info("Try installing with: {.code {cmd}}")
    }
  }

  attr(ok, "manager") <- manager
  if (!is.null(cmd)) {
    attr(ok, "install_cmd") <- cmd
  }
  invisible(ok)
}

# ---- Internal helpers ----

sysdeps_managers <- function() {
  c("dpkg", "rpm", "pacman", "apk", "brew", "winget", "choco", "scoop")
}

# Package names: letters/digits first, then . _ + @ / -, optional "a|b" alternatives.
# Strict on purpose: names are passed to system commands / PowerShell.
sysdeps_name_regex <- function() {
  one <- "[A-Za-z0-9][A-Za-z0-9._+@/-]*"
  paste0("^", one, "(\\|", one, ")*$")
}

# Does an executable exist? scoop is a .cmd/.ps1 shim on Windows, so try
# those extensions too.
sysdeps_has_cmd <- function(x) {
  any(nzchar(Sys.which(c(x, paste0(x, ".cmd"), paste0(x, ".ps1")))))
}

# Thin wrapper around system2(); mock this in tests.
sysdeps_run <- function(cmd, args = character(), capture = FALSE) {
  suppressWarnings(
    system2(cmd, args, stdout = if (capture) TRUE else FALSE, stderr = FALSE)
  )
}

sysdeps_powershell <- function() {
  ps <- Sys.which(c("pwsh", "powershell")) # prefer PowerShell 7+
  ps <- ps[nzchar(ps)]
  if (length(ps) == 0L) {
    cli::cli_abort("PowerShell ({.code pwsh} or {.code powershell}) not found.")
  }
  unname(ps[[1L]])
}

sysdeps_run_ps <- function(script) {
  sysdeps_run(
    sysdeps_powershell(),
    c(
      "-NoProfile",
      "-NonInteractive",
      "-Command",
      shQuote(script, type = "cmd")
    )
  )
}

# Read ID and ID_LIKE from /etc/os-release as a lower-case character vector.
sysdeps_os_release_ids <- function(path = "/etc/os-release") {
  if (!file.exists(path)) {
    return(character())
  }
  lines <- readLines(path, warn = FALSE)
  kv <- Filter(length, regmatches(lines, regexec("^(ID|ID_LIKE)=(.*)$", lines)))
  if (length(kv) == 0L) {
    return(character())
  }
  vals <- vapply(
    kv,
    function(x) gsub("^[\"']|[\"']$", "", x[[3L]]),
    character(1L)
  )
  unlist(strsplit(tolower(vals), "[[:space:]]+"), use.names = FALSE)
}

sysdeps_linux_manager <- function() {
  map <- c(
    debian = "dpkg",
    ubuntu = "dpkg",
    linuxmint = "dpkg",
    pop = "dpkg",
    raspbian = "dpkg",
    fedora = "rpm",
    rhel = "rpm",
    centos = "rpm",
    rocky = "rpm",
    almalinux = "rpm",
    ol = "rpm",
    amzn = "rpm",
    suse = "rpm",
    opensuse = "rpm",
    sles = "rpm",
    arch = "pacman",
    manjaro = "pacman",
    endeavouros = "pacman",
    alpine = "apk"
  )
  hit <- unique(unname(map[intersect(sysdeps_os_release_ids(), names(map))]))
  hit <- hit[vapply(hit, sysdeps_has_cmd, logical(1L))]
  if (length(hit) > 0L) hit[[1L]] else NULL
}

sysdeps_detect_manager <- function() {
  sysname <- Sys.info()[["sysname"]]
  if (sysname == "Linux") {
    hit <- sysdeps_linux_manager()
    if (!is.null(hit)) {
      return(hit)
    }
  }
  candidates <- switch(
    sysname,
    Darwin = "brew",
    Linux = c("dpkg", "rpm", "pacman", "apk"),
    Windows = c("winget", "choco", "scoop"),
    cli::cli_abort("Unsupported operating system: {.val {sysname}}.")
  )
  hit <- candidates[vapply(candidates, sysdeps_has_cmd, logical(1L))]
  if (length(hit) == 0L) {
    cli::cli_abort(c(
      "No supported package manager found.",
      "i" = "Set {.arg manager} explicitly."
    ))
  }
  hit[[1L]]
}

# No built-in lists for winget / choco / scoop: on Windows these libraries are
# normally bundled with CRAN binaries or provided by Rtools (MSYS2).
sysdeps_defaults <- function() {
  list(
    rpm = c(
      "freetype-devel",
      "libjpeg-turbo-devel",
      "libpng-devel",
      "libtiff-devel",
      "libwebp-devel",
      "harfbuzz-devel",
      "fribidi-devel",
      "fontconfig-devel"
    ),
    dpkg = c(
      "libfreetype-dev|libfreetype6-dev",
      "libjpeg-dev",
      "libpng-dev",
      "libtiff-dev",
      "libwebp-dev",
      "libharfbuzz-dev",
      "libfribidi-dev",
      "libfontconfig1-dev"
    ),
    pacman = c(
      "freetype2",
      "libjpeg-turbo",
      "libpng",
      "libtiff",
      "libwebp",
      "harfbuzz",
      "fribidi",
      "fontconfig"
    ),
    apk = c(
      "freetype-dev",
      "libjpeg-turbo-dev",
      "libpng-dev",
      "tiff-dev",
      "libwebp-dev",
      "harfbuzz-dev",
      "fribidi-dev",
      "fontconfig-dev"
    ),
    brew = c(
      "freetype",
      "jpeg-turbo",
      "libpng",
      "libtiff",
      "webp",
      "harfbuzz",
      "fribidi",
      "fontconfig"
    )
  )
}

# `pkg` may contain "a|b" alternatives: installed if any alternative is.
sysdeps_is_installed <- function(pkg, manager) {
  alts <- strsplit(pkg, "|", fixed = TRUE)[[1L]]
  any(vapply(alts, sysdeps_is_installed_one, logical(1L), manager = manager))
}

sysdeps_is_installed_one <- function(pkg, manager) {
  switch(
    manager,
    rpm = identical(sysdeps_run("rpm", c("-q", pkg)), 0L),
    dpkg = {
      out <- sysdeps_run(
        "dpkg-query",
        c("-W", shQuote("-f=${Status}"), pkg),
        capture = TRUE
      )
      any(grepl("install ok installed", out, fixed = TRUE))
    },
    pacman = identical(sysdeps_run("pacman", c("-Q", pkg)), 0L),
    apk = identical(sysdeps_run("apk", c("info", "-e", pkg)), 0L),
    brew = identical(sysdeps_run("brew", c("list", "--formula", pkg)), 0L),
    winget = identical(
      sysdeps_run(
        "winget",
        c(
          "list",
          "--id",
          pkg,
          "--exact",
          "--accept-source-agreements",
          "--disable-interactivity"
        )
      ),
      0L
    ),
    choco = {
      out <- sysdeps_run(
        "choco",
        c("list", "--local-only", "--exact", "--limit-output", pkg),
        capture = TRUE
      )
      any(startsWith(tolower(out), paste0(tolower(pkg), "|")))
    },
    scoop = identical(
      sysdeps_run_ps(sprintf(
        "if (scoop list | Where-Object { $_.Name -eq '%s' }) { exit 0 } else { exit 1 }",
        pkg
      )),
      0L
    ),
    FALSE
  )
}

sysdeps_install_cmd <- function(manager, pkgs) {
  # Use the first alternative of each "a|b" entry.
  pkgs <- vapply(strsplit(pkgs, "|", fixed = TRUE), `[[`, character(1L), 1L)
  if (manager == "winget") {
    # Joined with ";" (PowerShell syntax); winget handles one id per call.
    return(paste0("winget install --id ", pkgs, " -e", collapse = "; "))
  }
  sudo <- if (identical(Sys.info()[["effective_user"]], "root")) "" else "sudo "
  prefix <- switch(
    manager,
    rpm = paste0(sudo, "dnf install -y"),
    dpkg = paste0(sudo, "apt install -y"),
    pacman = paste0(sudo, "pacman -S --needed"),
    apk = paste0(sudo, "apk add"),
    brew = "brew install",
    choco = "choco install -y", # run in an elevated PowerShell
    scoop = "scoop install"
  )
  paste(prefix, paste(pkgs, collapse = " "))
}
