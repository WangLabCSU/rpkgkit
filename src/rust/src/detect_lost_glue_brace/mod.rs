use extendr_api::prelude::*;

pub mod detect;

extendr_module! {
    mod detect_lost_glue_brace;
    use detect;
}
