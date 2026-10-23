#' Check whether system development dependencies are installed
#'
#' Detects the system package manager, checks each system dependency, and
#' reports the result with \pkg{cli}. Argument validation uses \pkg{rlang}.
#'
#' @param deps A character vector of system package names to check. Names must
#'   match the naming convention of the package manager in use. If `NULL`, a
#'   built-in list of graphics and font related dependencies is used.
#' @param manager The package manager: one of `"dpkg"`, `"rpm"`, `"pacman"`,
#'   `"apk"`, or `"brew"`. If `NULL`, it is detected automatically.
#' @param verbose Logical. If `TRUE` (the default), print the check results.
#'   If `FALSE`, no messages are printed.
#'
#' @return A named logical vector (package name -> installed or not),
#'   returned invisibly.
#' @export
#'
#' @examples
#' \donttest{
#' check_sysdeps()
#' check_sysdeps(c("freetype-devel", "libwebp-devel"), manager = "rpm")
#' ok <- check_sysdeps(verbose = FALSE)
#' ok[!ok]
#' }
check_sysdeps <- function(deps = NULL, manager = NULL, verbose = TRUE) {
  # ---- Argument checks (rlang) ----
  rlang::check_bool(verbose)
  if (!is.null(manager)) {
    manager <- rlang::arg_match(manager, sysdeps_managers())
  } else {
    manager <- sysdeps_detect_manager()
  }
  if (is.null(deps)) {
    deps <- sysdeps_defaults()[[manager]]
  } else if (
    !rlang::is_character(deps) ||
      length(deps) == 0L ||
      anyNA(deps) ||
      !all(nzchar(deps))
  ) {
    cli::cli_abort(
      "{.arg deps} must be a non-empty character vector without missing values."
    )
  }
  deps <- unique(deps)

  # ---- Check each dependency ----
  ok <- vapply(deps, sysdeps_is_installed, logical(1L), manager = manager)

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
    missing <- deps[!ok]
    if (length(missing) == 0L) {
      cli::cli_alert_success(
        "All {length(deps)} system dependenc{?y/ies} installed."
      )
    } else {
      cmd <- sysdeps_install_cmd(manager, missing)
      cli::cli_alert_warning(
        "Missing {length(missing)} dependenc{?y/ies}: {.pkg {missing}}"
      )
      cli::cli_alert_info("Try installing with: {.code {cmd}}")
    }
  }

  invisible(ok)
}

# ---- Internal helpers ----

sysdeps_managers <- function() c("dpkg", "rpm", "pacman", "apk", "brew")

sysdeps_detect_manager <- function() {
  sysname <- Sys.info()[["sysname"]]
  candidates <- switch(
    sysname,
    Darwin = "brew",
    Linux = c("dpkg", "rpm", "pacman", "apk"),
    cli::cli_abort("Unsupported operating system: {.val {sysname}}.")
  )
  hit <- candidates[nzchar(Sys.which(candidates))]
  if (length(hit) == 0L) {
    cli::cli_abort(c(
      "No supported package manager found.",
      "i" = "Set {.arg manager} explicitly."
    ))
  }
  hit[[1L]]
}

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
      "libfreetype-dev",
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

sysdeps_is_installed <- function(pkg, manager) {
  quiet_run <- function(cmd, args, capture = FALSE) {
    suppressWarnings(
      system2(cmd, args, stdout = if (capture) TRUE else FALSE, stderr = FALSE)
    )
  }
  switch(
    manager,
    rpm = identical(quiet_run("rpm", c("-q", pkg)), 0L),
    dpkg = {
      out <- quiet_run("dpkg", c("-s", pkg), capture = TRUE)
      any(grepl("^Status: install ok installed", out))
    },
    pacman = identical(quiet_run("pacman", c("-Q", pkg)), 0L),
    apk = identical(quiet_run("apk", c("info", "-e", pkg)), 0L),
    brew = identical(quiet_run("brew", c("list", "--formula", pkg)), 0L)
  )
}

sysdeps_install_cmd <- function(manager, pkgs) {
  prefix <- switch(
    manager,
    rpm = "sudo dnf install -y",
    dpkg = "sudo apt install -y",
    pacman = "sudo pacman -S --needed",
    apk = "sudo apk add",
    brew = "brew install"
  )
  paste(prefix, paste(pkgs, collapse = " "))
}
