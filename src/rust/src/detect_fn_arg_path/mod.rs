use extendr_api::prelude::*;

pub mod dfap;

extendr_module! {
    mod detect_fn_arg_path;
    use dfap;
}
