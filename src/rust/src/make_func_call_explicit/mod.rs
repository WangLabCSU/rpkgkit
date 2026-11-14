use extendr_api::prelude::*;

pub mod mfce;

extendr_module! {
    mod make_func_call_explicit;
    use mfce;
}
