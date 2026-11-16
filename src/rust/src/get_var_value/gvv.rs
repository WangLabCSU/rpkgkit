use extendr_api::prelude::*;
use extendr_api::{lang, Result};
use std::collections::HashMap;

/// Guard of the `while` / `repeat` unrollers, mirroring the R helper.
const MAX_ITERATIONS: usize = 10_000;

/// Longer sequences are not unrolled: the body is walked once instead.
const MAX_SEQUENCE: usize = 100_000;

/// Variable definitions collected from the formals and the body of a function.
///
/// `values` plays the role of the R definition environment: a name maps to the
/// (already resolved) expression that produces it. `loop_break` is the
/// `.loop_break` flag used to stop the statements of a `{` block after a
/// `break`, `env` is the environment where conditions and loop sequences are
/// evaluated and `error_handler` is the `function(e) NULL` handler used to
/// evaluate them without letting an error escape.
struct DefEnv {
    values: HashMap<String, Robj>,
    loop_break: bool,
    env: Environment,
    error_handler: Robj,
}

impl DefEnv {
    fn new(env: Environment) -> Self {
        DefEnv {
            values: HashMap::new(),
            loop_break: false,
            env,
            error_handler: R!("function(e) NULL").unwrap_or_else(|_| Robj::from(())),
        }
    }

    /// Record the default of every formal of `fmls`.
    ///
    /// Rust rewrite of `rpkgkit:::.gvv_init_def_env()`: `...` has no
    /// accessible value and a formal without a default is left out.
    fn init_formals(&mut self, fmls: &Robj) {
        let formals = match fmls.as_pairlist() {
            Some(formals) => formals,
            None => return,
        };
        for (name, default) in formals.iter() {
            if name.is_empty() || name == "..." {
                continue;
            }
            if default.is_missing_arg() {
                continue;
            }
            if let Some(sym) = default.as_symbol() {
                if sym.as_str().is_empty() {
                    continue;
                }
            }
            self.values.insert(name.to_string(), default);
        }
    }
}

/// Trace the expression that produces a variable inside a function.
///
/// Rust rewrite of the extraction half of `rpkgkit:::get_var_value()`: the
/// definition environment is built from the formals of the function, its body
/// is walked to record every assignment, and the target expression is resolved
/// by substituting the known variables. The resolved expression is returned
/// instead of its value, so that the final `eval()` runs in R and a failing
/// evaluation keeps its original condition.
///
/// Returns a list with `found` (whether `var_name` is a parameter with a
/// default or is assigned in the body) and `expr` (the resolved expression,
/// `NULL` when it was not found).
///
/// @param var_name Name of the target variable.
/// @param fmls Formals of the function, as returned by `formals()`.
/// @param body Body of the function, as returned by `body()`.
/// @param env Environment used to evaluate conditions and loop sequences.
///
/// @keywords internal
#[extendr]
pub fn gvv_trace_rs(var_name: &str, fmls: Robj, body: Robj, env: Environment) -> Result<List> {
    let mut def_env = DefEnv::new(env);
    def_env.init_formals(&fmls);
    extract(&body, &mut def_env)?;

    let target = match def_env.values.get(var_name) {
        Some(target) => target.clone(),
        None => {
            return Ok(List::from_pairs([
                ("found", Robj::from(false)),
                ("expr", Robj::from(())),
            ]))
        }
    };

    let resolved = resolve(&target, &def_env.values, &mut Vec::new())?;
    Ok(List::from_pairs([
        ("found", Robj::from(true)),
        ("expr", resolved),
    ]))
}

// ---------------------------------------------------------------------------
// Expression tree helpers
// ---------------------------------------------------------------------------

/// Values and tags of a call, the head included, or `None` when `expr` is not
/// a call.
fn call_parts(expr: &Robj) -> Option<(Vec<Robj>, Vec<String>)> {
    let language = expr.as_language()?;
    let mut values = Vec::new();
    let mut tags = Vec::new();
    for (tag, value) in language.iter() {
        tags.push(tag.to_string());
        values.push(value);
    }
    Some((values, tags))
}

/// Rebuild a call from its values and tags, the tags being the argument names.
///
/// `as.call()` preserves the names of a list, which is how `pkg::fun(x, y = 1)`
/// keeps `y` named after a rewrite.
fn make_call(values: &[Robj], tags: &[String]) -> Result<Robj> {
    if tags.iter().all(|tag| tag.is_empty()) {
        return Ok(Robj::from(Language::from_values(values.iter().cloned())));
    }
    let list = List::from_names_and_values(tags.iter().cloned(), values.iter().cloned())?;
    lang!("as.call", list).eval()
}

/// Name of a symbol or first element of a character vector, as `as.character()`
/// would produce it for a call head.
fn as_name(x: &Robj) -> Option<String> {
    if let Some(sym) = x.as_symbol() {
        return Some(sym.as_str().to_string());
    }
    x.as_str().map(|value| value.to_string())
}

/// Name of a symbol, or `None` for every other object.
fn symbol_name(x: &Robj) -> Option<String> {
    x.as_symbol().map(|sym| sym.as_str().to_string())
}

/// `pkg::fun` when the head of a call is a namespace access, `None` otherwise.
fn namespace_name(head: &Robj) -> Option<String> {
    let (parts, _) = call_parts(head)?;
    if parts.len() < 3 || symbol_name(&parts[0]).as_deref() != Some("::") {
        return None;
    }
    let package = as_name(&parts[1])?;
    let function = as_name(&parts[2])?;
    Some(format!("{}::{}", package, function))
}

/// `return()`, `stop()`, `abort()`, `cli_abort()` or their `pkg::` form.
fn terminates(expr: &Robj) -> bool {
    let (parts, _) = match call_parts(expr) {
        Some(parts) => parts,
        None => return false,
    };
    if parts.is_empty() {
        return false;
    }
    if parts[0].is_language() {
        return matches!(
            namespace_name(&parts[0]).as_deref(),
            Some("rlang::abort") | Some("cli::cli_abort")
        );
    }
    matches!(
        as_name(&parts[0]).as_deref(),
        Some("return") | Some("stop") | Some("abort") | Some("cli_abort")
    )
}

/// `isTRUE(x)`: a length-one logical `TRUE`, `NA` excluded.
fn is_true_value(x: &Robj) -> bool {
    x.len() == 1
        && x.as_logical_slice()
            .map(|slice| slice[0].is_true())
            .unwrap_or(false)
}

/// `identical(x, FALSE)`: a length-one logical `FALSE`.
fn is_false_value(x: &Robj) -> bool {
    x.len() == 1
        && x.as_logical_slice()
            .map(|slice| slice[0].is_false())
            .unwrap_or(false)
}

/// `is.atomic()` restricted to the types a `for` loop may iterate over.
fn is_atomic(x: &Robj) -> bool {
    matches!(
        x.rtype(),
        Rtype::Null
            | Rtype::Logicals
            | Rtype::Integers
            | Rtype::Doubles
            | Rtype::Complexes
            | Rtype::Strings
            | Rtype::Raw
    )
}

/// Elements of an atomic vector, as `as.list()` would return them.
fn atomic_elements(x: &Robj) -> Option<Vec<Robj>> {
    let list = lang!("as.list", x.clone()).eval().ok()?.as_list()?;
    Some(list.values().collect())
}

/// `eval()` in the traced environment, returning `NULL` instead of propagating
/// an error.
///
/// Rust rewrite of `rpkgkit:::.gvv_eval_safe()`: a condition or a loop sequence
/// that cannot be evaluated statically simply yields `NULL`, which the callers
/// treat as "unknown". The expression is wrapped in `tryCatch()` so that R does
/// not report the error on the console.
fn eval_safe(expr: &Robj, def_env: &DefEnv) -> Robj {
    let values = [
        Robj::from(Symbol::from_string("tryCatch".to_string())),
        expr.clone(),
        def_env.error_handler.clone(),
    ];
    let tags = [String::new(), String::new(), "error".to_string()];
    match make_call(&values, &tags) {
        Ok(call) => call
            .eval_with_env(&def_env.env)
            .unwrap_or_else(|_| Robj::from(())),
        Err(_) => Robj::from(()),
    }
}

// ---------------------------------------------------------------------------
// Expression resolution
// ---------------------------------------------------------------------------

/// Replace every symbol of `expr` that has a definition in `values` by that
/// definition, walking the chain until only literals and unknown symbols
/// remain.
///
/// Rust rewrite of `rpkgkit:::.gvv_resolve()`; `visited` detects circular
/// definitions.
fn resolve(expr: &Robj, values: &HashMap<String, Robj>, visited: &mut Vec<String>) -> Result<Robj> {
    if let Some(name) = symbol_name(expr) {
        if visited.iter().any(|seen| seen == &name) {
            return Err(format!("Circular dependency detected for variable: '{}'", name).into());
        }
        match values.get(&name) {
            Some(definition) => {
                visited.push(name);
                let resolved = resolve(definition, values, visited);
                visited.pop();
                resolved
            }
            None => Ok(expr.clone()),
        }
    } else if expr.is_language() {
        let (mut parts, tags) = match call_parts(expr) {
            Some(parts) => parts,
            None => return Ok(expr.clone()),
        };
        for part in parts.iter_mut().skip(1) {
            *part = resolve(part, values, visited)?;
        }
        make_call(&parts, &tags)
    } else {
        Ok(expr.clone())
    }
}

// ---------------------------------------------------------------------------
// Assignment extraction
// ---------------------------------------------------------------------------

/// Walk the expression tree and record every assignment in `def_env`.
///
/// Rust rewrite of `rpkgkit:::.gvv_extract()`: control-flow constructs are
/// dispatched to their own handler so that iterative and conditional
/// assignments are applied, and statements after `return()` / `stop()` or
/// after a `break` are ignored.
fn extract(expr: &Robj, def_env: &mut DefEnv) -> Result<()> {
    let (parts, _tags) = match call_parts(expr) {
        Some(parts) => parts,
        None => return Ok(()),
    };
    if parts.is_empty() {
        return Ok(());
    }

    // The function position is itself a call: `pkg::fun()` or an anonymous
    // function. Neither can contain an assignment.
    if parts[0].is_language() {
        return Ok(());
    }

    let op = match as_name(&parts[0]) {
        Some(op) => op,
        None => return Ok(()),
    };

    match op.as_str() {
        "return" | "stop" | "abort" | "cli_abort" | "next" => return Ok(()),
        "break" => {
            def_env.loop_break = true;
            return Ok(());
        }
        "<-" | "=" | "<<-" => {
            if parts.len() >= 3 {
                assign(&parts[1], &parts[2], def_env)?;
            }
        }
        "{" => {
            extract_block(&parts, def_env)?;
            return Ok(());
        }
        "for" => {
            extract_for(&parts, def_env)?;
            return Ok(());
        }
        "while" => {
            extract_while(&parts, def_env)?;
            return Ok(());
        }
        "repeat" => {
            extract_repeat(&parts, def_env)?;
            return Ok(());
        }
        "if" => {
            extract_if(&parts, def_env)?;
            return Ok(());
        }
        "::" | ":::" => return Ok(()),
        _ => {}
    }

    // Default: recurse into the arguments, so that nested assignments in the
    // right-hand side of an assignment are caught as well.
    for part in parts.iter().skip(1) {
        extract(part, def_env)?;
    }
    Ok(())
}

/// Record `lhs <- rhs`.
///
/// A subset assignment `x[i, j] <- value` is not a plain assignment: it is
/// rewritten as `x <- \`[<-\`(x, i, j, value)` and the whole replacement call
/// is stored under the base variable, exactly like the R helper does.
fn assign(lhs: &Robj, rhs: &Robj, def_env: &mut DefEnv) -> Result<()> {
    if lhs.is_language() {
        let (parts, tags) = match call_parts(lhs) {
            Some(parts) => parts,
            None => return Ok(()),
        };
        if parts.len() < 2 {
            return Ok(());
        }
        let op = match as_name(&parts[0]) {
            Some(op) => op,
            None => return Ok(()),
        };
        if !matches!(op.as_str(), "[" | "[[" | "$") {
            // Replacement functions such as `names(x) <- ...` have no single
            // base variable to describe; they are not tracked.
            return Ok(());
        }
        let base = match as_name(&parts[1]) {
            Some(base) => base,
            None => return Ok(()),
        };

        let mut values = Vec::with_capacity(parts.len() + 2);
        let mut call_tags = Vec::with_capacity(parts.len() + 2);
        values.push(Robj::from(Symbol::from_string(format!("{}<-", op))));
        call_tags.push(String::new());
        values.push(parts[1].clone());
        call_tags.push(String::new());
        for index in 2..parts.len() {
            values.push(parts[index].clone());
            call_tags.push(tags[index].clone());
        }
        values.push(rhs.clone());
        call_tags.push(String::new());

        let replacement = make_call(&values, &call_tags)?;
        let resolved = resolve(&replacement, &def_env.values, &mut Vec::new())?;
        def_env.values.insert(base, resolved);
        return Ok(());
    }

    if let Some(name) = symbol_name(lhs) {
        let resolved = resolve(rhs, &def_env.values, &mut Vec::new())?;
        def_env.values.insert(name, resolved);
    }
    Ok(())
}

/// Statements of a `{` block, in order.
fn extract_block(parts: &[Robj], def_env: &mut DefEnv) -> Result<()> {
    for child in parts.iter().skip(1) {
        extract(child, def_env)?;
        if terminates(child) {
            break;
        }
        if def_env.loop_break {
            break;
        }
    }
    Ok(())
}

/// `for (var in seq) body`: the body is walked once per element when the
/// sequence can be evaluated statically, and once otherwise.
fn extract_for(parts: &[Robj], def_env: &mut DefEnv) -> Result<()> {
    if parts.len() < 4 {
        return Ok(());
    }
    let loop_var = match as_name(&parts[1]) {
        Some(name) => name,
        None => return Ok(()),
    };
    let sequence = resolve(&parts[2], &def_env.values, &mut Vec::new())?;
    let body = &parts[3];

    let value = eval_safe(&sequence, def_env);
    let length = value.len();
    if is_atomic(&value) && length > 0 && length < MAX_SEQUENCE {
        if let Some(elements) = atomic_elements(&value) {
            for element in elements {
                def_env.values.insert(loop_var.clone(), element);
                extract(body, def_env)?;
            }
            return Ok(());
        }
    }

    extract(body, def_env)
}

/// `while (cond) body`: the condition is re-evaluated after every iteration
/// until it stops being `TRUE`.
fn extract_while(parts: &[Robj], def_env: &mut DefEnv) -> Result<()> {
    if parts.len() < 3 {
        return Ok(());
    }
    let condition = &parts[1];
    let body = &parts[2];

    for iteration in 1..=MAX_ITERATIONS {
        let resolved = resolve(condition, &def_env.values, &mut Vec::new())?;
        let value = eval_safe(&resolved, def_env);
        if !is_true_value(&value) {
            break;
        }

        extract(body, def_env)?;
        if def_env.loop_break {
            def_env.loop_break = false;
            return Ok(());
        }
        if iteration == MAX_ITERATIONS {
            warn("Reached iteration limit (10000) for while loop");
        }
    }
    Ok(())
}

/// `repeat body`: walked until a `break` is hit.
fn extract_repeat(parts: &[Robj], def_env: &mut DefEnv) -> Result<()> {
    if parts.len() < 2 {
        return Ok(());
    }
    let body = &parts[1];

    for iteration in 1..=MAX_ITERATIONS {
        extract(body, def_env)?;
        if def_env.loop_break {
            def_env.loop_break = false;
            return Ok(());
        }
        if iteration == MAX_ITERATIONS {
            warn("Reached iteration limit (10000) for repeat loop, result may be unpredictable");
        }
    }
    Ok(())
}

/// `if (cond) then else else`: the surviving branch is walked when the
/// condition can be evaluated statically, and both branches otherwise.
fn extract_if(parts: &[Robj], def_env: &mut DefEnv) -> Result<()> {
    if parts.len() < 3 {
        return Ok(());
    }
    let resolved = resolve(&parts[1], &def_env.values, &mut Vec::new())?;
    let value = eval_safe(&resolved, def_env);

    if is_true_value(&value) {
        extract(&parts[2], def_env)?;
    } else if is_false_value(&value) {
        if parts.len() >= 4 {
            extract(&parts[3], def_env)?;
        }
    } else {
        // Unknown branch, be conservative.
        extract(&parts[2], def_env)?;
        if parts.len() >= 4 {
            extract(&parts[3], def_env)?;
        }
    }
    Ok(())
}

/// Emit an R warning for a loop that hit the iteration limit.
fn warn(message: &str) {
    let _ = lang!("warning", message).eval();
}

extendr_module! {
    mod gvv;
    fn gvv_trace_rs;
}
