use extendr_api::prelude::*;

pub mod ory;

extendr_module! {
    mod optimize_rmd_yaml;
    use ory;
}
