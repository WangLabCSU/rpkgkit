//! Named-column helpers shared by the two crawlers.
//!
//! R turns the returned list into a data frame, so both crawlers must emit
//! columns of the same length with the same `NA` encoding.

use extendr_api::prelude::*;

/// A character column built from owned strings.
pub(super) fn text(values: impl IntoIterator<Item = String>) -> Robj {
    let values: Vec<String> = values.into_iter().collect();
    Robj::from(Strings::from_values(values))
}

/// A character column where `None` becomes `NA_character_`.
pub(super) fn optional_text(values: impl IntoIterator<Item = Option<String>>) -> Robj {
    // The owned buffers must outlive the `&str` column, so they are kept here
    // until `Robj::from` has copied them into R memory.
    let owned: Vec<Option<String>> = values.into_iter().collect();
    let na = <&str>::na();
    let column: Vec<&str> = owned
        .iter()
        .map(|value| value.as_deref().unwrap_or(na))
        .collect();
    Robj::from(Strings::from_values(column))
}
