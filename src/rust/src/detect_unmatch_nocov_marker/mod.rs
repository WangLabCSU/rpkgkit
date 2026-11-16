use extendr_api::prelude::*;

pub mod dunm;

extendr_module! {
    mod detect_unmatch_nocov_marker;
    use dunm;
}
