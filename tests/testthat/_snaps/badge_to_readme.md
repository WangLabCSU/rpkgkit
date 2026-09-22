# badge_to_readme validates the package root and badge

    Code
      badge_to_readme("badge", "not-a-package")
    Condition
      Error in `badge_to_readme()`:
      x 'not-a-package' is not an R package root.
      > No 'DESCRIPTION' found.

---

    Code
      badge_to_readme("", path)
    Condition
      Error in `badge_to_readme()`:
      ! `badge` must be a non-empty string.

---

    Code
      badge_to_readme(c("one", "two"), path)
    Condition
      Error in `badge_to_readme()`:
      ! `badge` must be a non-empty string.

---

    Code
      badge_to_readme("badge", path, unused = TRUE)
    Condition
      Error in `badge_to_readme()`:
      ! `...` must be empty.
      x Problematic argument:
      * unused = TRUE

# badge_to_readme requires a README with one valid badges block

    Code
      badge_to_readme("badge", ".")
    Condition
      Error in `badge_to_readme()`:
      x No README found in '.'.
      > Expected 'README.Rmd' or 'README.md'.

---

    Code
      badge_to_readme("badge", ".")
    Condition
      Error in `badge_to_readme()`:
      x Could not find a unique badges block in './README.md'.
      i Need one <!-- badges: start --> and one <!-- badges: end -->.

---

    Code
      badge_to_readme("badge", ".")
    Condition
      Error in `badge_to_readme()`:
      x Could not find a unique badges block in './README.md'.
      i Need one <!-- badges: start --> and one <!-- badges: end -->.

