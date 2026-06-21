## R CMD check results

0 errors | 0 warnings | 1 notes

* This is a resubmission.
* Apologies for the oversight in the previous submission — 'pedant' was
  inadvertently left in Suggests despite its code being vendored into the
  package. This has now been corrected.

## Changes

* Removed 'pedant' from Suggests. The required functionality from pedant
  has been vendored into the package (see R/vendor-pedant.R) under its
  original MIT license, with full copyright attribution to the original
  authors in the DESCRIPTION file.

## Notes

* The NOTE "New submission" is expected for first-time CRAN submissions and will be
  resolved once the package is accepted.

## Reverse Dependencies

There are no reverse dependencies.

## Method References

This package implements original functionality for R package development
workflows. There are no published references describing the methods in this
package.
