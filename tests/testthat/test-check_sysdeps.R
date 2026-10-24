# Tests for check_sysdeps() and its helpers from R/92_check_sysdeps.R

# ---- sysdeps_managers() ----

test_that("sysdeps_managers() returns all supported managers", {
  managers <- rpkgkit:::sysdeps_managers()

  expect_type(managers, "character")
  expect_setequal(
    managers,
    c("dpkg", "rpm", "pacman", "apk", "brew", "winget", "choco", "scoop")
  )
  expect_equal(anyDuplicated(managers), 0L)
})

# ---- sysdeps_name_regex() ----

test_that("sysdeps_name_regex() accepts the package names of every manager", {
  pattern <- rpkgkit:::sysdeps_name_regex()

  valid <- c(
    "libpng-dev",
    "freetype-devel",
    "freetype2",
    "gtk+",
    "libpng12-0",
    "r-base@4.5",
    "Git.Git",
    "Kitware.CMake",
    "cask/cask",
    "libfreetype-dev|libfreetype6-dev",
    "a|b|c"
  )

  expect_true(all(grepl(pattern, valid)))
})

test_that("sysdeps_name_regex() rejects shell metacharacters", {
  pattern <- rpkgkit:::sysdeps_name_regex()

  invalid <- c(
    "",
    " ",
    "lib png",
    "-rf",
    "a;b",
    "a&&b",
    "a`id`",
    "a$(rm -rf /)",
    "libpng*",
    "a|",
    "|a",
    "a b|c"
  )

  expect_false(any(grepl(pattern, invalid)))
})

# ---- sysdeps_defaults() ----

test_that("sysdeps_defaults() has a valid default set per manager", {
  defaults <- rpkgkit:::sysdeps_defaults()
  managers <- rpkgkit:::sysdeps_managers()
  pattern <- rpkgkit:::sysdeps_name_regex()

  expect_type(defaults, "list")
  expect_setequal(names(defaults), c("rpm", "dpkg", "pacman", "apk", "brew"))
  expect_true(all(names(defaults) %in% managers))

  for (manager in names(defaults)) {
    deps <- defaults[[manager]]
    expect_type(deps, "character")
    expect_gt(length(deps), 0L)
    expect_false(anyNA(deps))
    expect_true(all(nzchar(deps)))
    expect_equal(anyDuplicated(deps), 0L)
    expect_true(all(grepl(pattern, deps)))
  }
})

test_that("sysdeps_defaults() has no built-in list for the Windows managers", {
  defaults <- rpkgkit:::sysdeps_defaults()

  expect_false(any(c("winget", "choco", "scoop") %in% names(defaults)))
})

test_that("sysdeps_defaults() covers the graphics stack for each manager", {
  defaults <- rpkgkit:::sysdeps_defaults()

  expect_in("freetype-devel", defaults$rpm)
  expect_in("freetype2", defaults$pacman)
  expect_in("freetype-dev", defaults$apk)
  expect_in("freetype", defaults$brew)
  expect_in("libfreetype-dev|libfreetype6-dev", defaults$dpkg)

  for (manager in names(defaults)) {
    expect_match(defaults[[manager]], "fontconfig", all = FALSE)
  }
})

test_that("sysdeps_defaults() only uses alternatives for dpkg", {
  defaults <- rpkgkit:::sysdeps_defaults()

  expect_match(defaults$dpkg, "|", fixed = TRUE, all = FALSE)

  for (manager in setdiff(names(defaults), "dpkg")) {
    expect_no_match(defaults[[manager]], "|", fixed = TRUE)
  }
})

# ---- sysdeps_has_cmd() ----

test_that("sysdeps_has_cmd() looks for executables on the PATH", {
  seen <- NULL
  local_mocked_bindings(
    Sys.which = function(x) {
      seen <<- x
      ifelse(x == "dpkg", "/usr/bin/dpkg", "")
    },
    .package = "base"
  )

  expect_true(rpkgkit:::sysdeps_has_cmd("dpkg"))
  expect_equal(seen, c("dpkg", "dpkg.cmd", "dpkg.ps1"))
})

test_that("sysdeps_has_cmd() accepts .cmd and .ps1 shims", {
  local_mocked_bindings(
    Sys.which = function(x) ifelse(x == "scoop.ps1", "C:/scoop.ps1", ""),
    .package = "base"
  )

  expect_true(rpkgkit:::sysdeps_has_cmd("scoop"))
})

test_that("sysdeps_has_cmd() is FALSE when nothing is found", {
  local_mocked_bindings(
    Sys.which = function(x) rep("", length(x)),
    .package = "base"
  )

  expect_false(rpkgkit:::sysdeps_has_cmd("dpkg"))
})

# ---- sysdeps_os_release_ids() ----

test_that("sysdeps_os_release_ids() reads ID and ID_LIKE", {
  path <- withr::local_tempfile(
    lines = c('NAME="Ubuntu"', "ID=ubuntu", 'ID_LIKE="debian"')
  )

  expect_equal(rpkgkit:::sysdeps_os_release_ids(path), c("ubuntu", "debian"))
})

test_that("sysdeps_os_release_ids() lower-cases and splits every value", {
  path <- withr::local_tempfile(
    lines = c('ID="Fedora"', "ID_LIKE='rhel centos'")
  )

  expect_equal(
    rpkgkit:::sysdeps_os_release_ids(path),
    c("fedora", "rhel", "centos")
  )
})

test_that("sysdeps_os_release_ids() returns nothing without usable keys", {
  missing_path <- file.path(withr::local_tempdir(), "nope")
  expect_equal(rpkgkit:::sysdeps_os_release_ids(missing_path), character())

  unkeyed <- withr::local_tempfile(lines = c('NAME="Ubuntu"', "VERSION=24.04"))
  expect_equal(rpkgkit:::sysdeps_os_release_ids(unkeyed), character())
})

# ---- sysdeps_linux_manager() ----

test_that("sysdeps_linux_manager() maps IDs to managers", {
  lookup <- function(ids) {
    local_mocked_bindings(
      sysdeps_os_release_ids = function(path) ids,
      sysdeps_has_cmd = function(x) TRUE
    )
    rpkgkit:::sysdeps_linux_manager()
  }

  expect_equal(lookup("ubuntu"), "dpkg")
  expect_equal(lookup("linuxmint"), "dpkg")
  expect_equal(lookup("fedora"), "rpm")
  expect_equal(lookup("almalinux"), "rpm")
  expect_equal(lookup("manjaro"), "pacman")
  expect_equal(lookup("alpine"), "apk")
})

test_that("sysdeps_linux_manager() is NULL for an unknown distribution", {
  local_mocked_bindings(
    sysdeps_os_release_ids = function(path) "gentoo",
    sysdeps_has_cmd = function(x) TRUE
  )

  expect_null(rpkgkit:::sysdeps_linux_manager())
})

test_that("sysdeps_linux_manager() skips managers that are not installed", {
  local_mocked_bindings(
    sysdeps_os_release_ids = function(path) "fedora",
    sysdeps_has_cmd = function(x) FALSE
  )

  expect_null(rpkgkit:::sysdeps_linux_manager())
})

test_that("sysdeps_linux_manager() picks the first available candidate", {
  local_mocked_bindings(
    sysdeps_os_release_ids = function(path) c("linuxmint", "ubuntu", "debian"),
    sysdeps_has_cmd = function(x) TRUE
  )

  expect_equal(rpkgkit:::sysdeps_linux_manager(), "dpkg")
})

# ---- sysdeps_detect_manager() ----

test_that("sysdeps_detect_manager() returns brew on macOS", {
  local_mocked_bindings(
    Sys.info = function() c(sysname = "Darwin"),
    .package = "base"
  )
  local_mocked_bindings(sysdeps_has_cmd = function(x) TRUE)

  expect_equal(rpkgkit:::sysdeps_detect_manager(), "brew")
})

test_that("sysdeps_detect_manager() trusts /etc/os-release on Linux", {
  probed <- FALSE
  local_mocked_bindings(
    Sys.info = function() c(sysname = "Linux"),
    .package = "base"
  )
  local_mocked_bindings(
    sysdeps_linux_manager = function() "rpm",
    sysdeps_has_cmd = function(x) {
      probed <<- TRUE
    }
  )

  expect_equal(rpkgkit:::sysdeps_detect_manager(), "rpm")
  expect_false(probed)
})

test_that("sysdeps_detect_manager() probes Linux managers in order", {
  probed <- NULL
  local_mocked_bindings(
    Sys.info = function() c(sysname = "Linux"),
    .package = "base"
  )
  local_mocked_bindings(
    sysdeps_linux_manager = function() NULL,
    sysdeps_has_cmd = function(x) {
      probed <<- c(probed, x)
      ifelse(x == "pacman", TRUE, FALSE)
    }
  )

  expect_equal(rpkgkit:::sysdeps_detect_manager(), "pacman")
  expect_equal(probed, c("dpkg", "rpm", "pacman", "apk"))
})

test_that("sysdeps_detect_manager() prefers the first available Linux manager", {
  local_mocked_bindings(
    Sys.info = function() c(sysname = "Linux"),
    .package = "base"
  )
  local_mocked_bindings(
    sysdeps_linux_manager = function() NULL,
    sysdeps_has_cmd = function(x) x %in% c("dpkg", "apk")
  )

  expect_equal(rpkgkit:::sysdeps_detect_manager(), "dpkg")
})

test_that("sysdeps_detect_manager() prefers winget on Windows", {
  local_mocked_bindings(
    Sys.info = function() c(sysname = "Windows"),
    .package = "base"
  )
  local_mocked_bindings(sysdeps_has_cmd = function(x) TRUE)

  expect_equal(rpkgkit:::sysdeps_detect_manager(), "winget")
})

test_that("sysdeps_detect_manager() falls back to choco or scoop on Windows", {
  local_mocked_bindings(
    Sys.info = function() c(sysname = "Windows"),
    .package = "base"
  )

  local_mocked_bindings(sysdeps_has_cmd = function(x) x == "choco")
  expect_equal(rpkgkit:::sysdeps_detect_manager(), "choco")

  local_mocked_bindings(sysdeps_has_cmd = function(x) x == "scoop")
  expect_equal(rpkgkit:::sysdeps_detect_manager(), "scoop")
})

test_that("sysdeps_detect_manager() aborts on an unsupported OS", {
  local_mocked_bindings(
    Sys.info = function() c(sysname = "SunOS"),
    .package = "base"
  )

  expect_error(
    rpkgkit:::sysdeps_detect_manager(),
    "Unsupported operating system",
    class = "rlang_error"
  )
})

test_that("sysdeps_detect_manager() aborts when no manager is installed", {
  local_mocked_bindings(
    Sys.info = function() c(sysname = "Darwin"),
    .package = "base"
  )
  local_mocked_bindings(sysdeps_has_cmd = function(x) FALSE)

  expect_error(
    rpkgkit:::sysdeps_detect_manager(),
    "No supported package manager found",
    class = "rlang_error"
  )
  expect_error(
    rpkgkit:::sysdeps_detect_manager(),
    "Set `manager` explicitly",
    class = "rlang_error"
  )
})

# ---- sysdeps_powershell() ----

test_that("sysdeps_powershell() prefers pwsh over powershell", {
  local_mocked_bindings(
    Sys.which = function(x) {
      ifelse(
        x == "pwsh",
        "/usr/bin/pwsh",
        ifelse(x == "powershell", "/usr/bin/powershell", "")
      )
    },
    .package = "base"
  )

  expect_equal(rpkgkit:::sysdeps_powershell(), "/usr/bin/pwsh")
})

test_that("sysdeps_powershell() falls back to powershell", {
  local_mocked_bindings(
    Sys.which = function(x) ifelse(x == "powershell", "C:/powershell.exe", ""),
    .package = "base"
  )

  expect_equal(rpkgkit:::sysdeps_powershell(), "C:/powershell.exe")
})

test_that("sysdeps_powershell() aborts when PowerShell is missing", {
  local_mocked_bindings(
    Sys.which = function(x) rep("", length(x)),
    .package = "base"
  )

  expect_error(
    rpkgkit:::sysdeps_powershell(),
    "PowerShell",
    class = "rlang_error"
  )
})

# ---- sysdeps_run_ps() ----

test_that("sysdeps_run_ps() builds a non-interactive PowerShell command", {
  calls <- new.env(parent = emptyenv())
  local_mocked_bindings(
    sysdeps_powershell = function() "/usr/bin/pwsh",
    sysdeps_run = function(cmd, args = character(), capture = FALSE) {
      calls$cmd <- cmd
      calls$args <- args
      0L
    }
  )

  expect_equal(rpkgkit:::sysdeps_run_ps("Get-Date"), 0L)
  expect_equal(calls$cmd, "/usr/bin/pwsh")
  expect_equal(
    calls$args[1:3],
    c("-NoProfile", "-NonInteractive", "-Command")
  )
  expect_equal(calls$args[[4L]], shQuote("Get-Date", type = "cmd"))
})

# ---- sysdeps_is_installed() ----

test_that("sysdeps_is_installed() checks rpm with -q", {
  calls <- new.env(parent = emptyenv())
  local_mocked_bindings(
    sysdeps_run = function(cmd, args = character(), capture = FALSE) {
      calls$cmd <- cmd
      calls$args <- args
      calls$capture <- capture
      0L
    }
  )

  expect_true(rpkgkit:::sysdeps_is_installed("libpng-devel", "rpm"))
  expect_equal(calls$cmd, "rpm")
  expect_equal(calls$args, c("-q", "libpng-devel"))
  expect_false(calls$capture)
})

test_that("sysdeps_is_installed() checks pacman, apk and brew arguments", {
  calls <- new.env(parent = emptyenv())
  local_mocked_bindings(
    sysdeps_run = function(cmd, args = character(), capture = FALSE) {
      calls[[cmd]] <- args
      0L
    }
  )

  expect_true(rpkgkit:::sysdeps_is_installed("pkg", "pacman"))
  expect_equal(calls$pacman, c("-Q", "pkg"))

  expect_true(rpkgkit:::sysdeps_is_installed("pkg", "apk"))
  expect_equal(calls$apk, c("info", "-e", "pkg"))

  expect_true(rpkgkit:::sysdeps_is_installed("pkg", "brew"))
  expect_equal(calls$brew, c("list", "--formula", "pkg"))
})

test_that("sysdeps_is_installed() checks dpkg status output", {
  calls <- new.env(parent = emptyenv())
  local_mocked_bindings(
    sysdeps_run = function(cmd, args = character(), capture = FALSE) {
      calls$cmd <- cmd
      calls$args <- args
      calls$capture <- capture
      c("Package: libpng-dev", "Status: install ok installed")
    }
  )

  expect_true(rpkgkit:::sysdeps_is_installed("libpng-dev", "dpkg"))
  expect_equal(calls$cmd, "dpkg-query")
  expect_equal(calls$args[[1L]], "-W")
  expect_equal(calls$args[[3L]], "libpng-dev")
  expect_match(calls$args[[2L]], "Status", fixed = TRUE)
  expect_true(calls$capture)
})

test_that("sysdeps_is_installed() rejects deinstalled dpkg packages", {
  local_mocked_bindings(
    sysdeps_run = function(...) {
      c("Package: libpng-dev", "Status: deinstall ok config-files")
    }
  )

  expect_false(rpkgkit:::sysdeps_is_installed("libpng-dev", "dpkg"))
})

test_that("sysdeps_is_installed() handles empty dpkg output", {
  local_mocked_bindings(sysdeps_run = function(...) character())

  expect_false(rpkgkit:::sysdeps_is_installed("libpng-dev", "dpkg"))
})

test_that("sysdeps_is_installed() checks winget with --exact", {
  calls <- new.env(parent = emptyenv())
  local_mocked_bindings(
    sysdeps_run = function(cmd, args = character(), capture = FALSE) {
      calls$cmd <- cmd
      calls$args <- args
      calls$capture <- capture
      0L
    }
  )

  expect_true(rpkgkit:::sysdeps_is_installed("Git.Git", "winget"))
  expect_equal(calls$cmd, "winget")
  expect_equal(
    calls$args,
    c(
      "list",
      "--id",
      "Git.Git",
      "--exact",
      "--accept-source-agreements",
      "--disable-interactivity"
    )
  )
  expect_false(calls$capture)
})

test_that("sysdeps_is_installed() parses choco local package output", {
  calls <- new.env(parent = emptyenv())
  local_mocked_bindings(
    sysdeps_run = function(cmd, args = character(), capture = FALSE) {
      calls$cmd <- cmd
      calls$args <- args
      calls$capture <- capture
      c("git|2.44.0", "cmake|3.29.0")
    }
  )

  expect_true(rpkgkit:::sysdeps_is_installed("git", "choco"))
  expect_equal(calls$cmd, "choco")
  expect_equal(
    calls$args,
    c("list", "--local-only", "--exact", "--limit-output", "git")
  )
  expect_true(calls$capture)

  expect_false(rpkgkit:::sysdeps_is_installed("cmake2", "choco"))
})

test_that("sysdeps_is_installed() matches choco package names case-insensitively", {
  local_mocked_bindings(
    sysdeps_run = function(...) c("Git|2.44.0")
  )

  expect_true(rpkgkit:::sysdeps_is_installed("git", "choco"))
})

test_that("sysdeps_is_installed() queries scoop through PowerShell", {
  scripts <- character()
  local_mocked_bindings(
    sysdeps_run_ps = function(script) {
      scripts <<- c(scripts, script)
      0L
    }
  )

  expect_true(rpkgkit:::sysdeps_is_installed("git", "scoop"))
  expect_length(scripts, 1L)
  expect_match(scripts, "scoop list", fixed = TRUE)
  expect_match(scripts, "$_.Name -eq 'git'", fixed = TRUE)
  expect_match(scripts, "exit 0", fixed = TRUE)
})

test_that("sysdeps_is_installed() reports FALSE for a non-zero status", {
  local_mocked_bindings(sysdeps_run = function(...) 1L)

  expect_false(rpkgkit:::sysdeps_is_installed("pkg", "rpm"))
  expect_false(rpkgkit:::sysdeps_is_installed("pkg", "pacman"))
  expect_false(rpkgkit:::sysdeps_is_installed("pkg", "apk"))
  expect_false(rpkgkit:::sysdeps_is_installed("pkg", "brew"))
  expect_false(rpkgkit:::sysdeps_is_installed("pkg", "winget"))
  expect_false(rpkgkit:::sysdeps_is_installed("pkg", "scoop"))
})

test_that("sysdeps_is_installed() accepts alternatives", {
  queried <- character()
  local_mocked_bindings(
    sysdeps_run = function(cmd, args = character(), capture = FALSE) {
      queried <<- c(queried, args[[2L]])
      ifelse(args[[2L]] == "b", 0L, 1L)
    }
  )

  expect_true(rpkgkit:::sysdeps_is_installed("a|b", "pacman"))
  expect_equal(queried, c("a", "b"))
})

test_that("sysdeps_is_installed() is FALSE when no alternative is installed", {
  queried <- character()
  local_mocked_bindings(
    sysdeps_run = function(cmd, args = character(), capture = FALSE) {
      queried <<- c(queried, args[[2L]])
      1L
    }
  )

  expect_false(rpkgkit:::sysdeps_is_installed("a|b|c", "pacman"))
  expect_equal(queried, c("a", "b", "c"))
})

test_that("sysdeps_is_installed() is FALSE for an unknown manager", {
  local_mocked_bindings(
    sysdeps_run = function(...) stop("sysdeps_run() must not be called.")
  )

  expect_false(rpkgkit:::sysdeps_is_installed("pkg", "yum"))
})

# ---- sysdeps_install_cmd() ----

test_that("sysdeps_install_cmd() builds the install command per manager", {
  local_mocked_bindings(
    Sys.info = function() c(sysname = "Linux", effective_user = "yyx"),
    .package = "base"
  )

  expect_equal(
    rpkgkit:::sysdeps_install_cmd("rpm", c("a", "b")),
    "sudo dnf install -y a b"
  )
  expect_equal(
    rpkgkit:::sysdeps_install_cmd("dpkg", c("a", "b")),
    "sudo apt install -y a b"
  )
  expect_equal(
    rpkgkit:::sysdeps_install_cmd("pacman", c("a", "b")),
    "sudo pacman -S --needed a b"
  )
  expect_equal(
    rpkgkit:::sysdeps_install_cmd("apk", c("a", "b")),
    "sudo apk add a b"
  )
  expect_equal(
    rpkgkit:::sysdeps_install_cmd("brew", c("a", "b")),
    "brew install a b"
  )
  expect_equal(
    rpkgkit:::sysdeps_install_cmd("choco", c("a", "b")),
    "choco install -y a b"
  )
  expect_equal(
    rpkgkit:::sysdeps_install_cmd("scoop", c("a", "b")),
    "scoop install a b"
  )
})

test_that("sysdeps_install_cmd() handles a single package", {
  expect_equal(
    rpkgkit:::sysdeps_install_cmd("brew", "freetype"),
    "brew install freetype"
  )
})

test_that("sysdeps_install_cmd() issues one winget call per package", {
  expect_equal(
    rpkgkit:::sysdeps_install_cmd("winget", c("Git.Git", "Kitware.CMake")),
    paste(
      "winget install --id Git.Git -e;",
      "winget install --id Kitware.CMake -e"
    )
  )
})

test_that("sysdeps_install_cmd() uses the first alternative", {
  expect_equal(
    rpkgkit:::sysdeps_install_cmd(
      "dpkg",
      c("libfreetype-dev|libfreetype6-dev", "libpng-dev")
    ),
    "sudo apt install -y libfreetype-dev libpng-dev"
  )
})

test_that("sysdeps_install_cmd() drops sudo for root", {
  local_mocked_bindings(
    Sys.info = function() c(sysname = "Linux", effective_user = "root"),
    .package = "base"
  )

  expect_equal(
    rpkgkit:::sysdeps_install_cmd("dpkg", "a"),
    "apt install -y a"
  )
  expect_equal(
    rpkgkit:::sysdeps_install_cmd("brew", "a"),
    "brew install a"
  )
})

# ---- check_sysdeps() ----

test_that("check_sysdeps() returns a named logical vector invisibly", {
  local_mocked_bindings(
    sysdeps_has_cmd = function(x) TRUE,
    sysdeps_is_installed = function(pkg, manager) pkg == "a"
  )

  ok <- withVisible(
    check_sysdeps(c("a", "b"), manager = "dpkg", verbose = FALSE)
  )

  expect_false(ok$visible)
  expect_type(ok$value, "logical")
  expect_named(ok$value, c("a", "b"))
  expect_equal(as.vector(ok$value), c(TRUE, FALSE))
})

test_that("check_sysdeps() attaches the manager and the install command", {
  local_mocked_bindings(
    sysdeps_has_cmd = function(x) TRUE,
    sysdeps_is_installed = function(pkg, manager) pkg == "a"
  )

  ok <- check_sysdeps(c("a", "b"), manager = "dpkg", verbose = FALSE)

  expect_equal(attr(ok, "manager"), "dpkg")
  expect_match(attr(ok, "install_cmd"), "apt install -y b", fixed = TRUE)
})

test_that("check_sysdeps() omits the install command when nothing is missing", {
  local_mocked_bindings(
    sysdeps_has_cmd = function(x) TRUE,
    sysdeps_is_installed = function(pkg, manager) TRUE
  )

  ok <- check_sysdeps(c("a", "b"), manager = "brew", verbose = FALSE)

  expect_equal(attr(ok, "manager"), "brew")
  expect_null(attr(ok, "install_cmd"))
})

test_that("check_sysdeps() passes the manager to every check", {
  seen <- character()
  local_mocked_bindings(
    sysdeps_has_cmd = function(x) TRUE,
    sysdeps_is_installed = function(pkg, manager) {
      seen <<- c(seen, manager)
      TRUE
    }
  )

  check_sysdeps(c("a", "b"), manager = "apk", verbose = FALSE)

  expect_equal(seen, c("apk", "apk"))
})

test_that("check_sysdeps() verifies that the manager is installed", {
  local_mocked_bindings(sysdeps_has_cmd = function(x) FALSE)

  expect_error(
    check_sysdeps("a", manager = "brew"),
    "was not found on this system",
    class = "rlang_error"
  )
})

test_that("check_sysdeps() drops duplicated dependencies", {
  checked <- character()
  local_mocked_bindings(
    sysdeps_has_cmd = function(x) TRUE,
    sysdeps_is_installed = function(pkg, manager) {
      checked <<- c(checked, pkg)
      TRUE
    }
  )

  ok <- check_sysdeps(c("a", "a", "b"), manager = "rpm", verbose = FALSE)

  expect_equal(checked, c("a", "b"))
  expect_named(ok, c("a", "b"))
})

test_that("check_sysdeps() uses the default set for the given manager", {
  checked <- character()
  local_mocked_bindings(
    sysdeps_has_cmd = function(x) TRUE,
    sysdeps_defaults = function() list(dpkg = c("x", "y", "z")),
    sysdeps_is_installed = function(pkg, manager) {
      checked <<- c(checked, pkg)
      TRUE
    }
  )

  ok <- check_sysdeps(manager = "dpkg", verbose = FALSE)

  expect_equal(checked, c("x", "y", "z"))
  expect_named(ok, c("x", "y", "z"))
})

test_that("check_sysdeps() aborts when a manager has no default list", {
  local_mocked_bindings(
    sysdeps_has_cmd = function(x) TRUE,
    sysdeps_is_installed = function(pkg, manager) TRUE
  )

  expect_error(
    check_sysdeps(manager = "winget"),
    "No built-in dependency list",
    class = "rlang_error"
  )
  expect_error(
    check_sysdeps(manager = "scoop"),
    "Supply `deps` explicitly",
    class = "rlang_error"
  )

  # Supplying deps explicitly is the supported path for these managers.
  ok <- check_sysdeps("Git.Git", manager = "winget", verbose = FALSE)
  expect_named(ok, "Git.Git")
})

test_that("check_sysdeps() detects the manager when manager is NULL", {
  local_mocked_bindings(
    sysdeps_detect_manager = function() "brew",
    sysdeps_defaults = function() list(brew = c("freetype", "libpng")),
    sysdeps_is_installed = function(pkg, manager) {
      stopifnot(identical(manager, "brew"))
      TRUE
    }
  )

  ok <- check_sysdeps(verbose = FALSE)

  expect_named(ok, c("freetype", "libpng"))
})

test_that("check_sysdeps(verbose = FALSE) prints nothing", {
  local_mocked_bindings(
    sysdeps_has_cmd = function(x) TRUE,
    sysdeps_is_installed = function(pkg, manager) pkg == "a"
  )

  expect_silent(check_sysdeps(c("a", "b"), manager = "dpkg", verbose = FALSE))
})

test_that("check_sysdeps() reports the package manager and each dependency", {
  local_mocked_bindings(
    sysdeps_has_cmd = function(x) TRUE,
    sysdeps_is_installed = function(pkg, manager) pkg == "a"
  )

  msgs <- paste(
    capture_messages(check_sysdeps(c("a", "b"), manager = "rpm")),
    collapse = ""
  )

  expect_match(msgs, "Package manager: rpm")
  expect_match(msgs, "\\ba\\b")
  expect_match(msgs, "\\bb\\b")
})

test_that("check_sysdeps() reports success when everything is installed", {
  local_mocked_bindings(
    sysdeps_has_cmd = function(x) TRUE,
    sysdeps_is_installed = function(pkg, manager) TRUE
  )

  plural <- paste(
    capture_messages(check_sysdeps(c("a", "b"), manager = "dpkg")),
    collapse = ""
  )
  singular <- paste(
    capture_messages(check_sysdeps("a", manager = "dpkg")),
    collapse = ""
  )

  expect_match(plural, "All 2 system dependencies installed", fixed = TRUE)
  expect_match(singular, "All 1 system dependency installed", fixed = TRUE)
})

test_that("check_sysdeps() reports missing dependencies and the install command", {
  local_mocked_bindings(
    sysdeps_has_cmd = function(x) TRUE,
    sysdeps_is_installed = function(pkg, manager) pkg == "a"
  )

  msgs <- paste(
    capture_messages(check_sysdeps(c("a", "b", "c"), manager = "dpkg")),
    collapse = ""
  )

  expect_match(msgs, "Missing 2 dependencies", fixed = TRUE)
  expect_match(msgs, "Try installing with", fixed = TRUE)
  expect_match(msgs, "apt install -y b c", fixed = TRUE)
  expect_no_match(msgs, "All 3 system dependencies installed", fixed = TRUE)
})

test_that("check_sysdeps() uses the singular form for one missing dependency", {
  local_mocked_bindings(
    sysdeps_has_cmd = function(x) TRUE,
    sysdeps_is_installed = function(pkg, manager) pkg == "a"
  )

  msgs <- paste(
    capture_messages(check_sysdeps(c("a", "b"), manager = "brew")),
    collapse = ""
  )

  expect_match(msgs, "Missing 1 dependency", fixed = TRUE)
})

test_that("check_sysdeps() rejects a non-logical verbose", {
  expect_error(check_sysdeps(verbose = "yes"), class = "rlang_error")
  expect_error(check_sysdeps(verbose = NA), class = "rlang_error")
  expect_error(check_sysdeps(verbose = 1), class = "rlang_error")
})

test_that("check_sysdeps() rejects an unknown manager", {
  expect_error(
    check_sysdeps("a", manager = "yum"),
    "must be one of",
    class = "rlang_error"
  )
})

test_that("check_sysdeps() rejects invalid deps", {
  local_mocked_bindings(sysdeps_has_cmd = function(x) TRUE)

  expect_error(
    check_sysdeps(character(), manager = "dpkg"),
    "non-empty character vector",
    class = "rlang_error"
  )
  expect_error(
    check_sysdeps(NA_character_, manager = "dpkg"),
    "non-empty character vector",
    class = "rlang_error"
  )
  expect_error(
    check_sysdeps(1:3, manager = "dpkg"),
    "non-empty character vector",
    class = "rlang_error"
  )
  expect_error(
    check_sysdeps(list("a"), manager = "dpkg"),
    "non-empty character vector",
    class = "rlang_error"
  )
  expect_error(
    check_sysdeps(c("a", ""), manager = "dpkg"),
    "non-empty character vector",
    class = "rlang_error"
  )
  expect_error(
    check_sysdeps(c("a", NA), manager = "dpkg"),
    "non-empty character vector",
    class = "rlang_error"
  )
})

test_that("check_sysdeps() rejects deps with unsafe characters", {
  local_mocked_bindings(
    sysdeps_has_cmd = function(x) TRUE,
    sysdeps_is_installed = function(pkg, manager) {
      stop("sysdeps_is_installed() must not be called.")
    }
  )

  expect_error(
    check_sysdeps("lib png", manager = "dpkg"),
    "invalid package name.",
    class = "rlang_error",
    fixed = TRUE
  )
  expect_error(
    check_sysdeps(c("ok", "a;b", "c d"), manager = "dpkg"),
    "invalid package names.",
    class = "rlang_error",
    fixed = TRUE
  )
  expect_error(
    check_sysdeps(c("ok", "a;b"), manager = "dpkg"),
    "Invalid:",
    class = "rlang_error"
  )
  expect_error(
    check_sysdeps("-rf", manager = "dpkg"),
    "allowed characters",
    class = "rlang_error",
    ignore.case = TRUE
  )
})

test_that("check_sysdeps() accepts dependencies with alternatives", {
  seen <- character()
  local_mocked_bindings(
    sysdeps_has_cmd = function(x) TRUE,
    sysdeps_is_installed = function(pkg, manager) {
      seen <<- c(seen, pkg)
      TRUE
    }
  )

  ok <- check_sysdeps(
    c("libfreetype-dev|libfreetype6-dev", "libpng-dev"),
    manager = "dpkg",
    verbose = FALSE
  )

  expect_named(ok, c("libfreetype-dev|libfreetype6-dev", "libpng-dev"))
  expect_equal(seen, c("libfreetype-dev|libfreetype6-dev", "libpng-dev"))
})

test_that("check_sysdeps() validates arguments before touching the system", {
  local_mocked_bindings(
    sysdeps_is_installed = function(pkg, manager) {
      stop("sysdeps_is_installed() must not be called for invalid input.")
    }
  )

  expect_error(
    check_sysdeps(character(), manager = "dpkg"),
    class = "rlang_error"
  )
  expect_error(
    check_sysdeps("a", manager = "yum"),
    class = "rlang_error"
  )
  expect_error(
    check_sysdeps("a", manager = "dpkg", verbose = NA),
    class = "rlang_error"
  )
})
