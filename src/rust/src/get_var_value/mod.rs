use extendr_api::prelude::*;

pub mod gvv;

extendr_module! {
    mod get_var_value;
    use gvv;
}
