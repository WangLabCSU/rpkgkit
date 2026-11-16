use extendr_api::prelude::*;

pub mod cp;

extendr_module! {
    mod convert_pipe;
    use cp;
}
