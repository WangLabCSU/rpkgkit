# Note: Any variables prefixed with `.` are used for text
# replacement in the Makevars.in and Makevars.win.in

# check the packages MSRV first
source("tools/msrv.R")

# check DEBUG and NOT_CRAN environment variables
env_debug <- Sys.getenv("DEBUG")
env_not_cran <- Sys.getenv("NOT_CRAN")

# check if the vendored zip file exists
vendor_exists <- file.exists("src/rust/vendor.tar.xz")

is_not_cran <- env_not_cran != ""
is_debug <- env_debug != ""

if (is_debug) {
  # if we have DEBUG then we set not cran to true
  # CRAN is always release build
  is_not_cran <- TRUE
  message("Creating DEBUG build.")
}

if (!is_not_cran) {
  message("Building for CRAN.")
}

# we set cran flags only if NOT_CRAN is empty and if
# the vendored crates are present.
.cran_flags <- ifelse(
  !is_not_cran && vendor_exists,
  "-j 2 --offline",
  ""
)

# when DEBUG env var is present we use `--debug` build
.profile <- ifelse(is_debug, "", "--release")
.clean_targets <- ifelse(is_debug, "", "$(TARGET_DIR)")

# We specify this target when building for webR
webr_target <- "wasm32-unknown-emscripten"

# here we check if the platform we are building for is webr
is_wasm <- identical(R.version$platform, webr_target)

# print to terminal to inform we are building for webr
if (is_wasm) {
  message("Building for WebR")
}

# we check if we are making a debug build or not
# if so, the LIBDIR environment variable becomes:
# LIBDIR = $(TARGET_DIR)/{wasm32-unknown-emscripten}/debug
# this will be used to fill out the LIBDIR env var for Makevars.in
target_libpath <- if (is_wasm) "wasm32-unknown-emscripten" else NULL
cfg <- if (is_debug) "debug" else "release"

# used to replace @LIBDIR@
.libdir <- paste(c(target_libpath, cfg), collapse = "/")

# use this to replace @TARGET@
# we specify the target _only_ on webR
# there may be use cases later where this can be adapted or expanded
.target <- ifelse(is_wasm, paste0("--target=", webr_target), "")

# add panic exports only for WASM builds
.panic_exports <- ifelse(
  is_wasm,
  "CARGO_PROFILE_DEV_PANIC=\"abort\" CARGO_PROFILE_RELEASE_PANIC=\"abort\" ",
  ""
)

# macOS: crates such as `ring` (rustls' crypto backend) compile C and assembly
# sources at build time. Without an explicit deployment target those objects
# inherit the SDK default (e.g. 26.5 with Xcode 26), which can be newer than the
# minimum macOS version R itself links against (e.g. 26.0). ld then warns for
# every object and `R CMD check` reports a WARNING, so pin the cargo build to
# the minimum macOS version R records for itself.
#
# This is resolved here instead of inside the Makevars because `R CMD check`
# treats GNU make functions in Makefiles as non-portable extensions.
.detect_macosx_min <- function(
  lib = file.path(R.home("lib"), "libR.dylib"),
  otool = Sys.which("otool")
) {
  if (!file.exists(lib) || !nzchar(otool)) {
    return("")
  }

  out <- suppressWarnings(
    system2(otool, c("-l", shQuote(lib)), stdout = TRUE, stderr = FALSE)
  )
  if (!length(out)) {
    return("")
  }

  # old binaries carry LC_VERSION_MIN_MACOSX, current ones LC_BUILD_VERSION
  field_after <- function(cmd, field) {
    start <- grep(cmd, out, fixed = TRUE)
    if (!length(start)) {
      return("")
    }
    hit <- grep(
      sprintf("^ *%s ", field),
      out[start[1]:length(out)],
      value = TRUE
    )
    if (!length(hit)) {
      return("")
    }
    trimws(sub(sprintf("^ *%s ", field), "", hit[1]))
  }

  min <- field_after("LC_BUILD_VERSION", "minos")
  if (!nzchar(min)) {
    min <- field_after("LC_VERSION_MIN_MACOSX", "version")
  }

  if (grepl("^[0-9]+(\\.[0-9]+)*$", min)) min else ""
}

.macosx_min <- .detect_macosx_min()

# used to replace @MACOSX_ENV@
.macosx_env <- if (nzchar(.macosx_min)) {
  message("Pinning MACOSX_DEPLOYMENT_TARGET to ", .macosx_min, ".")
  paste0("export MACOSX_DEPLOYMENT_TARGET=", .macosx_min, " && ")
} else {
  ""
}

# read in the Makevars.in file checking
is_windows <- .Platform[["OS.type"]] == "windows"

# if windows we replace in the Makevars.win.in
mv_fp <- ifelse(
  is_windows,
  "src/Makevars.win.in",
  "src/Makevars.in"
)

# set the output file
mv_ofp <- ifelse(
  is_windows,
  "src/Makevars.win",
  "src/Makevars"
)

# delete the existing Makevars{.win/.wasm}
if (file.exists(mv_ofp)) {
  message("Cleaning previous `", mv_ofp, "`.")
  invisible(file.remove(mv_ofp))
}

# read as a single string
mv_txt <- readLines(mv_fp)

# replace placeholder values
new_txt <- gsub("@CRAN_FLAGS@", .cran_flags, mv_txt) |>
  gsub("@PROFILE@", .profile, x = _) |>
  gsub("@CLEAN_TARGET@", .clean_targets, x = _) |>
  gsub("@LIBDIR@", .libdir, x = _) |>
  gsub("@TARGET@", .target, x = _) |>
  gsub("@MACOSX_ENV@", .macosx_env, x = _) |>
  gsub("@PANIC_EXPORTS@", .panic_exports, x = _)

message("Writing `", mv_ofp, "`.")
con <- file(mv_ofp, open = "wb")
writeLines(new_txt, con, sep = "\n")
close(con)

message("`tools/config.R` has finished.")
