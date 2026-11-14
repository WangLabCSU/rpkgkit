if (requireNamespace('spelling', quietly = TRUE)) {
  # spelling::spell_check_test() finds the sources through the R CMD check
  # layout (../00_pkg_src, or a "tests" directory next to DESCRIPTION). Other
  # tools run the tests from a different layout - covr, for instance, copies
  # them to "<pkg>-tests" - where that lookup fails and only warns, so the
  # spelling check cannot run at all. Skip it there instead of failing.
  not_cran <- tolower(Sys.getenv('NOT_CRAN')) %in% c('1', 'yes', 'true')

  check_dir <- dirname(getwd())
  has_sources <- length(list.files('../00_pkg_src')) > 0L ||
    (grepl('\\.Rcheck$', check_dir) &&
      dir.exists(sub('\\.Rcheck$', '', check_dir))) ||
    (identical(basename(getwd()), 'tests') && file.exists('../DESCRIPTION'))

  if (not_cran && has_sources) {
    spelling::spell_check_test(
      vignettes = TRUE,
      error = FALSE,
      skip_on_cran = TRUE
    )
  } else {
    message('All Done!\n')
  }
}
