# Tests for check_sysdeps() and its helpers from R/92_check_sysdeps.R

# ---- sysdeps_managers() ----

test_that("sysdeps_managers() returns all supported managers", {
  managers <- rpkgkit:::sysdeps_managers()

  expect_type(managers, "character")
  expect_setequal(managers, c("dpkg", "rpm", "pacman", "apk", "brew"))
  expect_false(anyDuplicated(managers) > 0L)
})

# ---- sysdeps_defaults() ----

test_that("sysdeps_defaults() has a valid default set per manager", {
  defaults <- rpkgkit:::sysdeps_defaults()

  expect_type(defaults, "list")
  expect_setequal(names(defaults), rpkgkit:::sysdeps_managers())

  for (manager in names(defaults)) {
    deps <- defaults[[manager]]
    expect_type(deps, "character")
    expect_gt(length(deps), 0L)
    expect_false(anyNA(deps))
    expect_true(all(nzchar(deps)))
    expect_equal(anyDuplicated(deps), 0L)
  }
})

test_that("sysdeps_defaults() covers the graphics stack for each manager", {
  defaults <- rpkgkit:::sysdeps_defaults()

  expect_match(defaults$rpm, "^freetype-devel$", all = FALSE)
  expect_match(defaults$dpkg, "^libfreetype-dev$", all = FALSE)
  expect_match(defaults$pacman, "^freetype2$", all = FALSE)
  expect_match(defaults$apk, "^freetype-dev$", all = FALSE)
  expect_match(defaults$brew, "^freetype$", all = FALSE)

  for (manager in names(defaults)) {
    expect_match(defaults[[manager]], "fontconfig", all = FALSE)
  }
})

# ---- sysdeps_detect_manager() ----

test_that("sysdeps_detect_manager() returns brew on macOS", {
  local_mocked_bindings(
    Sys.info = function() c(sysname = "Darwin"),
    Sys.which = function(x) "/opt/homebrew/bin/brew",
    .package = "base"
  )

  expect_equal(rpkgkit:::sysdeps_detect_manager(), "brew")
})

test_that("sysdeps_detect_manager() probes Linux managers in order", {
  probed <- new.env(parent = emptyenv())
  local_mocked_bindings(
    Sys.info = function() c(sysname = "Linux"),
    Sys.which = function(x) {
      probed$candidates <- x
      ifelse(x == "pacman", "/usr/bin/pacman", "")
    },
    .package = "base"
  )

  expect_equal(rpkgkit:::sysdeps_detect_manager(), "pacman")
  expect_equal(probed$candidates, c("dpkg", "rpm", "pacman", "apk"))
})

test_that("sysdeps_detect_manager() prefers the first available Linux manager", {
  local_mocked_bindings(
    Sys.info = function() c(sysname = "Linux"),
    Sys.which = function(x) {
      ifelse(x %in% c("dpkg", "apk"), paste0("/usr/bin/", x), "")
    },
    .package = "base"
  )

  expect_equal(rpkgkit:::sysdeps_detect_manager(), "dpkg")
})

test_that("sysdeps_detect_manager() aborts on an unsupported OS", {
  local_mocked_bindings(
    Sys.info = function() c(sysname = "Windows"),
    Sys.which = function(x) "",
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
    Sys.info = function() c(sysname = "Linux"),
    Sys.which = function(x) "",
    .package = "base"
  )

  expect_error(
    rpkgkit:::sysdeps_detect_manager(),
    "No supported package manager found",
    class = "rlang_error"
  )
  expect_error(
    rpkgkit:::sysdeps_detect_manager(),
    "manager",
    class = "rlang_error"
  )
})

# ---- sysdeps_is_installed() ----

test_that("sysdeps_is_installed() checks rpm with -q", {
  calls <- new.env(parent = emptyenv())
  local_mocked_bindings(
    system2 = function(command, args, stdout = "", stderr = "") {
      calls$command <- command
      calls$args <- args
      calls$stdout <- stdout
      calls$stderr <- stderr
      0L
    },
    .package = "base"
  )

  expect_true(rpkgkit:::sysdeps_is_installed("libpng-devel", "rpm"))
  expect_equal(calls$command, "rpm")
  expect_equal(calls$args, c("-q", "libpng-devel"))
  expect_false(calls$stdout)
  expect_false(calls$stderr)
})

test_that("sysdeps_is_installed() reports FALSE for a non-zero rpm status", {
  local_mocked_bindings(
    system2 = function(command, args, stdout = "", stderr = "") 1L,
    .package = "base"
  )

  expect_false(rpkgkit:::sysdeps_is_installed("libpng-devel", "rpm"))
})

test_that("sysdeps_is_installed() checks dpkg status output", {
  calls <- new.env(parent = emptyenv())
  local_mocked_bindings(
    system2 = function(command, args, stdout = "", stderr = "") {
      calls$command <- command
      calls$args <- args
      calls$stdout <- stdout
      c("Package: libpng-dev", "Status: install ok installed")
    },
    .package = "base"
  )

  expect_true(rpkgkit:::sysdeps_is_installed("libpng-dev", "dpkg"))
  expect_equal(calls$command, "dpkg")
  expect_equal(calls$args, c("-s", "libpng-dev"))
  expect_true(calls$stdout)
})

test_that("sysdeps_is_installed() rejects deinstalled dpkg packages", {
  local_mocked_bindings(
    system2 = function(command, args, stdout = "", stderr = "") {
      c("Package: libpng-dev", "Status: deinstall ok config-files")
    },
    .package = "base"
  )

  expect_false(rpkgkit:::sysdeps_is_installed("libpng-dev", "dpkg"))
})

test_that("sysdeps_is_installed() handles empty dpkg output", {
  local_mocked_bindings(
    system2 = function(command, args, stdout = "", stderr = "") {
      character()
    },
    .package = "base"
  )

  expect_false(rpkgkit:::sysdeps_is_installed("libpng-dev", "dpkg"))
})

test_that("sysdeps_is_installed() uses the right query per manager", {
  calls <- new.env(parent = emptyenv())
  local_mocked_bindings(
    system2 = function(command, args, stdout = "", stderr = "") {
      calls[[command]] <- args
      0L
    },
    .package = "base"
  )

  expect_true(rpkgkit:::sysdeps_is_installed("pkg", "pacman"))
  expect_equal(calls$pacman, c("-Q", "pkg"))

  expect_true(rpkgkit:::sysdeps_is_installed("pkg", "apk"))
  expect_equal(calls$apk, c("info", "-e", "pkg"))

  expect_true(rpkgkit:::sysdeps_is_installed("pkg", "brew"))
  expect_equal(calls$brew, c("list", "--formula", "pkg"))
})

test_that("sysdeps_is_installed() returns FALSE for failed pacman/apk/brew", {
  local_mocked_bindings(
    system2 = function(command, args, stdout = "", stderr = "") 1L,
    .package = "base"
  )

  expect_false(rpkgkit:::sysdeps_is_installed("pkg", "pacman"))
  expect_false(rpkgkit:::sysdeps_is_installed("pkg", "apk"))
  expect_false(rpkgkit:::sysdeps_is_installed("pkg", "brew"))
})

# ---- sysdeps_install_cmd() ----

test_that("sysdeps_install_cmd() builds the install command per manager", {
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
})

test_that("sysdeps_install_cmd() handles a single package", {
  expect_equal(
    rpkgkit:::sysdeps_install_cmd("brew", "freetype"),
    "brew install freetype"
  )
})

# ---- check_sysdeps() ----

test_that("check_sysdeps() returns a named logical vector invisibly", {
  local_mocked_bindings(
    sysdeps_is_installed = function(pkg, manager) pkg == "a"
  )

  ok <- withVisible(check_sysdeps(
    c("a", "b"),
    manager = "dpkg",
    verbose = FALSE
  ))

  expect_false(ok$visible)
  expect_type(ok$value, "logical")
  expect_named(ok$value, c("a", "b"))
  expect_equal(unname(ok$value), c(TRUE, FALSE))
})

test_that("check_sysdeps() passes the manager to every check", {
  seen <- character()
  local_mocked_bindings(
    sysdeps_is_installed = function(pkg, manager) {
      seen <<- c(seen, manager)
      TRUE
    }
  )

  check_sysdeps(c("a", "b"), manager = "apk", verbose = FALSE)

  expect_equal(seen, c("apk", "apk"))
})

test_that("check_sysdeps() drops duplicated dependencies", {
  checked <- character()
  local_mocked_bindings(
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
    sysdeps_is_installed = function(pkg, manager) pkg == "a",
    sysdeps_install_cmd = function(manager, pkgs) {
      stop("sysdeps_install_cmd() must not be called when verbose = FALSE.")
    }
  )

  expect_silent(check_sysdeps(c("a", "b"), manager = "dpkg", verbose = FALSE))
})

test_that("check_sysdeps() reports the package manager and each dependency", {
  local_mocked_bindings(
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

  expect_match(plural, "All 2 system dependencies installed")
  expect_match(singular, "All 1 system dependency installed")
})

test_that("check_sysdeps() reports missing dependencies and the install command", {
  local_mocked_bindings(
    sysdeps_is_installed = function(pkg, manager) pkg == "a"
  )

  msgs <- paste(
    capture_messages(check_sysdeps(c("a", "b", "c"), manager = "dpkg")),
    collapse = ""
  )

  expect_match(msgs, "Missing 2 dependencies")
  expect_match(msgs, "Try installing with")
  expect_match(msgs, "sudo apt install -y b c")
  expect_false(grepl("All 3 system dependencies installed", msgs, fixed = TRUE))
})

test_that("check_sysdeps() uses the singular form for one missing dependency", {
  local_mocked_bindings(
    sysdeps_is_installed = function(pkg, manager) pkg == "a"
  )

  msgs <- paste(
    capture_messages(check_sysdeps(c("a", "b"), manager = "brew")),
    collapse = ""
  )

  expect_match(msgs, "Missing 1 dependency: b")
})

test_that("check_sysdeps() rejects a non-logical verbose", {
  expect_error(
    check_sysdeps(verbose = "yes"),
    class = "rlang_error"
  )
  expect_error(
    check_sysdeps(verbose = NA),
    class = "rlang_error"
  )
})

test_that("check_sysdeps() rejects an unknown manager", {
  expect_error(
    check_sysdeps("a", manager = "yum"),
    "must be one of",
    class = "rlang_error"
  )
})

test_that("check_sysdeps() rejects invalid deps", {
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
})
