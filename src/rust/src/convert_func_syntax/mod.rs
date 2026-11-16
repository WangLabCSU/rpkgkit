use extendr_api::prelude::*;

pub mod cfs;

extendr_module! {
    mod convert_func_syntax;
    use cfs;
}
