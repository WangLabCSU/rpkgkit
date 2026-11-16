use extendr_api::prelude::*;
use extendr_api::Result;
use extendr_ffi as ffi;
use ffi::{R_xlen_t, SEXP, SEXPTYPE};
use std::ffi::CStr;

// ---------- 基础辅助 ----------

/// 取出符号的打印名。
///
/// # Safety
///
/// `s` 必须是符号（`SYMSXP`）。R 的符号表是全局强引用，符号一旦驻留就不会被
/// 回收，其打印名（CHARSXP）随之存活，因此返回的 `&'static CStr` 不会悬垂。
/// 把非符号传进来会读到非法内存。
unsafe fn sym_name(s: SEXP) -> &'static CStr {
    debug_assert!(ffi::TYPEOF(s) == SEXPTYPE::SYMSXP);
    CStr::from_ptr(ffi::R_CHAR(ffi::PRINTNAME(s)))
}

unsafe fn is_c_call(expr: SEXP) -> bool {
    // `c"c"` 是 NUL 结尾的 C 字符串字面量，自 Rust 1.77 起可用，与声明的 MSRV 一致。
    ffi::TYPEOF(expr) == SEXPTYPE::LANGSXP && ffi::CAR(expr) == ffi::Rf_install(c"c".as_ptr())
}

fn is_supported_rhs(t: SEXPTYPE) -> bool {
    matches!(
        t,
        SEXPTYPE::VECSXP
            | SEXPTYPE::LGLSXP
            | SEXPTYPE::INTSXP
            | SEXPTYPE::REALSXP
            | SEXPTYPE::CPLXSXP
            | SEXPTYPE::STRSXP
            | SEXPTYPE::RAWSXP
    )
}

/// 检查类型并返回长度
unsafe fn checked_len(x: SEXP) -> Result<R_xlen_t> {
    if !is_supported_rhs(ffi::TYPEOF(x)) {
        return Err(Error::Other("Unsupported rhs type".into()));
    }
    Ok(ffi::Rf_xlength(x))
}

unsafe fn is_collector(arg: SEXP) -> bool {
    if ffi::TYPEOF(arg) != SEXPTYPE::SYMSXP {
        return false;
    }
    let b = sym_name(arg).to_bytes();
    // `..` / `..name` 是收集器；`...` 是 dots，不是收集器。
    b == b".." || (b.len() > 2 && b.starts_with(b"..") && b != b"...")
}

// ---------- 元素提取 ----------

/// 复制 `x[index]` 到一个新的标量对象，语义等价于原子向量的 `x[[index]]`。
unsafe fn scalar_element(x: SEXP, index: R_xlen_t, ty: SEXPTYPE) -> SEXP {
    let out = ffi::Rf_allocVector(ty, 1);
    match ty {
        SEXPTYPE::LGLSXP => *ffi::LOGICAL(out) = *ffi::LOGICAL(x).offset(index),
        SEXPTYPE::INTSXP => *ffi::INTEGER(out) = *ffi::INTEGER(x).offset(index),
        SEXPTYPE::REALSXP => *ffi::REAL(out) = *ffi::REAL(x).offset(index),
        SEXPTYPE::CPLXSXP => *ffi::COMPLEX(out) = *ffi::COMPLEX(x).offset(index),
        SEXPTYPE::STRSXP => ffi::SET_STRING_ELT(out, 0, ffi::STRING_ELT(x, index)),
        SEXPTYPE::RAWSXP => *ffi::RAW(out) = *ffi::RAW(x).offset(index),
        _ => {}
    }
    out
}

/// `size` 由调用方传入（已用 [`checked_len`] 校验），避免逐个元素重复校验。
unsafe fn get_element(x: SEXP, index: R_xlen_t, size: R_xlen_t) -> Result<Robj> {
    if index < 0 || index >= size {
        return Err(Error::Other(format!(
            "Cannot unpack element {} from an object of length {}",
            index + 1,
            size
        )));
    }
    let ty = ffi::TYPEOF(x);
    let s = match ty {
        SEXPTYPE::VECSXP => ffi::VECTOR_ELT(x, index),
        SEXPTYPE::LGLSXP
        | SEXPTYPE::INTSXP
        | SEXPTYPE::REALSXP
        | SEXPTYPE::CPLXSXP
        | SEXPTYPE::STRSXP
        | SEXPTYPE::RAWSXP => scalar_element(x, index, ty),
        _ => return Err(Error::Other("Unsupported rhs type".into())),
    };
    Ok(Robj::from_sexp(s)) // 接管保护，防止后续分配时被 GC
}

unsafe fn get_named_element(x: SEXP, name: SEXP) -> Result<Robj> {
    let size = checked_len(x)?;
    let names = ffi::Rf_getAttrib(x, ffi::R_NamesSymbol);
    let want = sym_name(name);
    if ffi::TYPEOF(names) != SEXPTYPE::STRSXP {
        return Err(Error::Other(format!(
            "Cannot unpack named element '{}' from an unnamed object",
            want.to_string_lossy()
        )));
    }
    for i in 0..size {
        let ch = ffi::STRING_ELT(names, i);
        if ch != ffi::R_NaString && CStr::from_ptr(ffi::R_CHAR(ch)) == want {
            return get_element(x, i, size);
        }
    }
    Err(Error::Other(format!(
        "Named element '{}' was not found",
        want.to_string_lossy()
    )))
}

/// 拷贝 `n` 个元素。`n == 0` 时直接返回：空向量的数据指针不保证可解引用，
/// 而 `copy_nonoverlapping` 要求两个指针都合法。
unsafe fn copy_slice<T>(src: *const T, dst: *mut T, n: usize) {
    if n > 0 {
        std::ptr::copy_nonoverlapping(src, dst, n);
    }
}

unsafe fn collect_elements(x: SEXP, start: R_xlen_t, length: R_xlen_t) -> Result<Robj> {
    let size = checked_len(x)?;
    if start < 0 || length < 0 || start > size || length > size - start {
        return Err(Error::Other("Invalid collector range".into()));
    }

    let ty = ffi::TYPEOF(x);
    // `from_sexp` 会把 out 注册进保护表，随后分配 names 时不会被 GC 回收
    let out = Robj::from_sexp(ffi::Rf_allocVector(ty, length));
    let o = out.get();
    let (s, n) = (start, length as usize);

    match ty {
        SEXPTYPE::VECSXP => {
            for i in 0..length {
                ffi::SET_VECTOR_ELT(o, i, ffi::VECTOR_ELT(x, start + i));
            }
        }
        SEXPTYPE::LGLSXP => copy_slice(ffi::LOGICAL(x).offset(s), ffi::LOGICAL(o), n),
        SEXPTYPE::INTSXP => copy_slice(ffi::INTEGER(x).offset(s), ffi::INTEGER(o), n),
        SEXPTYPE::REALSXP => copy_slice(ffi::REAL(x).offset(s), ffi::REAL(o), n),
        SEXPTYPE::CPLXSXP => copy_slice(ffi::COMPLEX(x).offset(s), ffi::COMPLEX(o), n),
        SEXPTYPE::RAWSXP => copy_slice(ffi::RAW(x).offset(s), ffi::RAW(o), n),
        SEXPTYPE::STRSXP => {
            for i in 0..length {
                ffi::SET_STRING_ELT(o, i, ffi::STRING_ELT(x, start + i));
            }
        }
        _ => return Err(Error::Other("Unsupported rhs type".into())),
    }

    let names = ffi::Rf_getAttrib(x, ffi::R_NamesSymbol);
    if ffi::TYPEOF(names) == SEXPTYPE::STRSXP {
        let out_names = Robj::from_sexp(ffi::Rf_allocVector(SEXPTYPE::STRSXP, length));
        for i in 0..length {
            ffi::SET_STRING_ELT(out_names.get(), i, ffi::STRING_ELT(names, start + i));
        }
        ffi::Rf_setAttrib(o, ffi::R_NamesSymbol, out_names.get());
    }
    Ok(out)
}

// ---------- 赋值 / 解构 ----------

unsafe fn assign_symbol(target: SEXP, value: SEXP, env: SEXP) -> Result<()> {
    if ffi::TYPEOF(target) != SEXPTYPE::SYMSXP {
        return Err(Error::Other("Invalid destructuring target".into()));
    }
    // `c(a, )` 的空槽位在 R 里是 R_MissingArg（一个空名符号），必须拒绝，
    // 否则会给 `""` 这个变量赋值。
    if target == ffi::R_MissingArg {
        return Err(Error::Other(
            "Empty slot in the left-hand side of the destructuring assignment".into(),
        ));
    }
    let n = sym_name(target).to_bytes();
    if n.is_empty() {
        return Err(Error::Other(
            "Empty slot in the left-hand side of the destructuring assignment".into(),
        ));
    }
    if n == b"." || n == b"_" {
        return Ok(()); // 占位符，跳过
    }
    if n == b"..." {
        return Err(Error::Other(
            "`...` cannot be used as a destructuring target".into(),
        ));
    }
    ffi::Rf_defineVar(target, value, env);
    Ok(())
}

unsafe fn unpack_target(target: SEXP, value: SEXP, env: SEXP) -> Result<()> {
    if ffi::TYPEOF(target) == SEXPTYPE::SYMSXP {
        assign_symbol(target, value, env)
    } else if is_c_call(target) {
        unpack_call(target, value, env)
    } else {
        Err(Error::Other("Invalid destructuring target".into()))
    }
}

unsafe fn unpack_call(target: SEXP, value: SEXP, env: SEXP) -> Result<()> {
    let nil = ffi::R_NilValue;
    let size = checked_len(value)?;

    // 第一遍：定位收集器，统计其后的位置参数个数、位置目标个数与具名目标个数。
    // 具名目标（`c(cyl =)`）按名字取值，不占用位置，因此不能算进位置目标数。
    let mut collector = nil;
    let mut trailing: R_xlen_t = 0;
    let mut targets: R_xlen_t = 0;
    let mut named: R_xlen_t = 0;
    let mut node = ffi::CDR(target);
    while node != nil {
        let arg = ffi::CAR(node);
        if ffi::TAG(node) != nil {
            named += 1;
        } else if is_collector(arg) {
            if collector != nil {
                return Err(Error::Other(
                    "Only one collector is allowed in each c() target".into(),
                ));
            }
            collector = node;
            trailing = 0;
        } else {
            targets += 1;
            if collector != nil {
                trailing += 1;
            }
        }
        node = ffi::CDR(node);
    }

    // 第二遍：实际赋值
    let mut position: R_xlen_t = 0;
    let mut node = ffi::CDR(target);
    while node != nil {
        let arg = ffi::CAR(node);
        let tag = ffi::TAG(node);

        if tag != nil {
            if arg != ffi::R_MissingArg {
                return Err(Error::Other(
                    "Named unpacking targets must omit their right-hand side".into(),
                ));
            }
            let selected = get_named_element(value, tag)?;
            assign_symbol(tag, selected.get(), env)?;
        } else if node == collector {
            if position + trailing > size {
                return Err(Error::Other(format!(
                    "Cannot unpack {} trailing elements from an object of length {}",
                    trailing, size
                )));
            }
            let length = size - position - trailing;
            let collected = collect_elements(value, position, length)?;

            let name = sym_name(arg);
            if name.to_bytes() != b".." {
                // 去掉前缀 ".."
                let sym = ffi::Rf_install(name.as_ptr().add(2));
                ffi::Rf_defineVar(sym, collected.get(), env);
            }
            position += length;
        } else {
            let selected = get_element(value, position, size)?;
            unpack_target(arg, selected.get(), env)?;
            position += 1;
        }
        node = ffi::CDR(node);
    }

    // 没有收集器、也没有具名目标时左右两侧长度必须一致（同 rlang::`%<-%`），
    // 否则多出的元素会被静默丢弃。含具名目标时右侧是按键取值的容器
    // （如 `c(cyl =, wt =) %<-% mtcars`），长度相等没有意义，不做校验。
    if collector == nil && named == 0 && targets != size {
        return Err(Error::Other(format!(
            "The left- and right-hand sides of the destructuring assignment must be the same length ({} target(s) vs {} element(s))",
            targets, size
        )));
    }

    Ok(())
}

// ---------- 导出 ----------

/// @keywords internal
#[extendr]
fn unpack_assign_rs(lhs: Robj, rhs: Robj, env: Robj) -> Result<()> {
    unsafe {
        if ffi::TYPEOF(lhs.get()) != SEXPTYPE::LANGSXP || !is_c_call(lhs.get()) {
            return Err(Error::Other(
                "The left-hand side of a destructuring assignment must be a call to `c()`".into(),
            ));
        }
        if ffi::TYPEOF(env.get()) != SEXPTYPE::ENVSXP {
            return Err(Error::Other("`env` must be an environment".into()));
        }
        unpack_call(lhs.get(), rhs.get(), env.get())
    }
}

extendr_module! {
    mod implement;
    fn unpack_assign_rs;
}
