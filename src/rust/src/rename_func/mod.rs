use extendr_api::prelude::*;

pub mod rf;

extendr_module! {
    mod rename_func;
    use rf;
}
