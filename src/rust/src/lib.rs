use extendr_api::prelude::*;

mod convert_func_syntax;
mod convert_int_literal;
mod convert_pipe;
mod detect_fn_arg_path;
mod detect_lost_glue_brace;
mod detect_print_and_cat;
mod detect_unmatch_nocov_marker;
mod make_func_call_explicit;
mod optimize_rmd_yaml;
mod r_syntax;
mod rename_func;
mod use_air_table;

// Macro to generate exports.
// This ensures exported functions are registered with R.
// See corresponding C code in `entrypoint.c`.
extendr_module! {
    mod rpkgkit;
    use convert_func_syntax;
    use convert_int_literal;
    use convert_pipe;
    use detect_fn_arg_path;
    use detect_lost_glue_brace;
    use detect_print_and_cat;
    use detect_unmatch_nocov_marker;
    use make_func_call_explicit;
    use optimize_rmd_yaml;
    use rename_func;
    use use_air_table;
}
