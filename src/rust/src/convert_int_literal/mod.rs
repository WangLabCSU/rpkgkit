use extendr_api::prelude::*;

pub mod cil;

extendr_module! {
    mod convert_int_literal;
    use cil;
}
