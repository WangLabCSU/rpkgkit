use extendr_api::prelude::*;

pub mod implement;

extendr_module! {
    mod zeallot;
    use implement;
}
