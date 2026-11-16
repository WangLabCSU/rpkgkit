//! GitHub crawlers behind `inquire_standalone()` and `browse_standalone()`.
//!
//! The R functions only validate their arguments and turn the returned columns
//! into a tibble: every request, every result page and every JSON field is
//! handled here.

use extendr_api::prelude::*;

pub mod browse_standalone;
pub mod columns;
pub mod http;
pub mod inquire_standalone;
pub mod parse;

extendr_module! {
    mod r_standalone;
    use browse_standalone;
    use inquire_standalone;
}
