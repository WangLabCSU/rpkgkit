use extendr_api::prelude::*;

pub mod dpac;

extendr_module! {
    mod detect_print_and_cat;
    use dpac;
}
