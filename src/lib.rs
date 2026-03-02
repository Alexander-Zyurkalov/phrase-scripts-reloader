mod backend;
mod file_changes_monitor;
mod indexes;
mod instrument_registry;
mod script_paths;

use crate::backend::Backend;
use crate::indexes::{InstrumentId, InstrumentIndex, PhraseId};
use anyhow::{anyhow, Context, Error, Result};
use std::ffi::{c_longlong, c_void, CStr};
use std::fmt::Display;
use std::os::raw::{c_char, c_int};
use std::path::Path;
use std::ptr::{null, null_mut};
use std::rc::Rc;
use std::time::Duration;

#[repr(C)]
#[allow(non_camel_case_types)]
pub struct lua_State {
    _private: [u8; 0],
}

#[allow(non_camel_case_types)]
#[allow(non_snake_case)]
type lua_CFunction = *const unsafe extern "C" fn(L: *mut lua_State) -> c_int;

#[repr(C)]
#[allow(non_camel_case_types)]
pub struct luaL_Reg {
    name: *const c_char,
    func: lua_CFunction,
}

#[allow(non_snake_case)]
unsafe extern "C" {
    fn lua_pushinteger(L: *mut lua_State, n: i64);
    fn lua_pushnil(L: *mut lua_State);
    fn lua_pushvalue(L: *mut lua_State, index: c_int);
    fn lua_tolstring(L: *mut lua_State, index: c_int, len: *mut usize) -> *const c_char;
    fn lua_settable(L: *mut lua_State, index: c_int);
    fn lua_pushcclosure(
        L: *mut lua_State,
        f: unsafe extern "C" fn(*mut lua_State) -> c_int,
        n: c_int,
    );
    fn lua_pushstring(L: *mut lua_State, s: *const c_char) -> *const c_char;
    fn lua_createtable(L: *mut lua_State, narr: c_int, nrec: c_int);
    fn lua_newuserdata(L: *mut lua_State, size: usize) -> *mut c_void;
    fn luaL_newmetatable(L: *mut lua_State, tname: *const c_char) -> c_int;
    fn lua_getfield(L: *mut lua_State, index: c_int, k: *const c_char);
    fn lua_setmetatable(L: *mut lua_State, objindex: c_int) -> c_int;
    fn luaL_setmetatable(L: *mut lua_State, tname: *const c_char);
    fn lua_settop(L: *mut lua_State, index: c_int);
    fn lua_touserdata(L: *mut lua_State, index: c_int) -> *mut std::ffi::c_void;
    fn luaL_checklstring(L: *mut lua_State, arg: c_int, l: *mut usize) -> *const c_char;
    fn luaL_checkinteger(L: *mut lua_State, arg: c_int) -> c_longlong;
    fn luaL_register(L: *mut lua_State, libname: *const c_char, l: *const luaL_Reg);
    fn luaL_error(L: *mut lua_State, fmt: *const c_char, ...) -> c_int;
    fn lua_rawgeti(L: *mut lua_State, index: c_int, n: c_int);
    fn lua_gettop(L: *mut lua_State) -> c_int;
    fn lua_tointeger(L: *mut lua_State, index: c_int) -> i64;
    fn lua_type(L: *mut lua_State, index: c_int) -> c_int;
    fn lua_objlen(L: *mut lua_State, index: c_int) -> usize; // Lua 5.1
}

const LUA_REGISTRYINDEX: c_int = -10000;
const BACKEND_CLASS_MT_NAME: *const c_char = b"RustBackend\0".as_ptr() as *const c_char;

#[allow(non_snake_case)]
unsafe extern "C" fn new(L: *mut lua_State) -> c_int {
    unsafe {
        let c_song_path: *const c_char = luaL_checklstring(L, 1, null_mut());

        let path = match CStr::from_ptr(c_song_path).to_str() {
            Ok(str) => str.to_owned(),
            Err(err_text) => {
                return luaL_error(
                    L,
                    b"Invalid UTF-8 in path: %s\0".as_ptr() as *const c_char,
                    err_text,
                );
            }
        };
        let c_seconds = luaL_checkinteger(L, 2);

        let backend = Box::new(Backend::new(path, Duration::from_secs(c_seconds as u64)));
        std::ptr::write(
            lua_newuserdata(L, size_of::<*mut Backend>()) as *mut *mut Backend,
            Box::into_raw(backend),
        );
        lua_getfield(L, LUA_REGISTRYINDEX, BACKEND_CLASS_MT_NAME);
        lua_setmetatable(L, -2);
    }
    1
}

#[inline]
#[allow(non_snake_case)]
unsafe fn lua_pop(L: *mut lua_State, n: c_int) {
    lua_settop(L, -n - 1);
}

// #[allow(non_snake_case)]
// unsafe extern "C" fn update_song_path(L: *mut lua_State) -> c_int {
//     unsafe {
//     }
// }
//
// #[allow(non_snake_case)]
// unsafe fn update_song_path_inner(L: *mut lua_State) -> Result<()> {
//     unsafe {
//         let song_path = luaL_checklstring(L, 1, null_mut());
//
//     }
//  }

#[allow(non_snake_case)]
unsafe extern "C" fn set_new_instrument_indexes(L: *mut lua_State) -> c_int {
    unsafe {
        match set_new_instrument_indexes_inner(L) {
            Ok(()) => 0,
            Err(err) => make_lua_error(L, err)
        }
    }
}

unsafe fn make_lua_error(L: *mut lua_State, err: Error) -> c_int {
    lua_pushnil(L);
    let err_cstring = std::ffi::CString::new(err.to_string()).unwrap_or_else(|err| {
        std::ffi::CString::new("Can't event make an error message".to_string())
            .unwrap()
    });
    lua_pushstring(L, err_cstring.as_ptr());
    2
}

#[allow(non_snake_case)]
unsafe fn set_new_instrument_indexes_inner(L: *mut lua_State) -> Result<()> {
    unsafe {
        let len = lua_objlen(L, 2) as c_int;
        let mut pairs: Vec<(InstrumentId, InstrumentIndex)> = Vec::with_capacity(len as usize);

        for i in 1..=len {
            lua_rawgeti(L, 2, i);
            lua_rawgeti(L, -1, 1);
            let id = lua_tointeger(L, -1);
            lua_pop(L, 1);
            lua_rawgeti(L, -1, 2);
            let index = lua_tointeger(L, -1);
            lua_pop(L, 1);
            lua_pop(L, 1);

            let instrument_index = InstrumentIndex::try_from(index)?;
            pairs.push((InstrumentId::from(id as usize), instrument_index));
        }

        let backend = get_backend(L)?;
        backend.set_new_instrument_indexes(pairs);
        Ok(())
    }
}

#[allow(non_snake_case)]
unsafe fn get_backend(L: *mut lua_State) -> Result<&'static mut Backend> {
    let user_data = lua_touserdata(L, 1) as *mut *mut Backend;
    if user_data.is_null() || (*user_data).is_null() {
        return Err(anyhow!("Invalid Backend userdata"));
    }
    let backend = &mut **user_data;
    Ok(backend)
}

unsafe extern "C" fn register_script(L: *mut lua_State) -> c_int {
    unsafe {
        match register_script_inner(L) {
            Ok(_) => 1,
            Err(err) => make_lua_error(L, err),
        }
    }
}

unsafe fn register_script_inner(L: *mut lua_State) -> Result<()> {
    let instrument_id = lua_tointeger(L, 2);
    let instrument_name = lua_tolstring(L, 3, null_mut());
    let phrase_id = lua_tointeger(L, 4);
    let phrase_name = lua_tolstring(L, 5, null_mut());
    let script_body = lua_tolstring(L, 6, null_mut());

    // let instrument_id: InstrumentId = InstrumentId::from(instrument_id);
    // let phrase_id = PhraseId::from(phrase_id);

    println!("Instrument ID = {}", instrument_id);
    println!("Instrument name = {:?}", instrument_name);
    let backed = get_backend(L)?;

    Err(anyhow!("Upps"))
}

/// __gc metamethod: reconstructs the Box and drops it
#[allow(non_snake_case)]
unsafe extern "C" fn backend_gc(L: *mut lua_State) -> c_int {
    println!("Destructor was called");
    unsafe {
        let ud = lua_touserdata(L, 1) as *mut *mut Backend;
        if !ud.is_null() && !(*ud).is_null() {
            drop(Box::from_raw(*ud));
            *ud = null_mut();
        }
    }
    0
}

const RUST_BACKEND_OBJECT_META: [luaL_Reg; 4] = [
    luaL_Reg { name: b"__gc\0".as_ptr() as *const c_char, func: backend_gc as lua_CFunction },
    luaL_Reg {
        name: b"set_new_instrument_indexes\0".as_ptr() as *const c_char,
        func: set_new_instrument_indexes as lua_CFunction,
    },
    luaL_Reg {
        name: b"register_script\0".as_ptr() as *const c_char,
        func: register_script as lua_CFunction,
    },
    luaL_Reg { name: null(), func: null() },
];

const RUST_BACKEND_CLASS_META: [luaL_Reg; 2] = [
    luaL_Reg { name: b"new\0".as_ptr() as *const c_char, func: new as lua_CFunction },
    luaL_Reg { name: null(), func: null() },
];

#[unsafe(no_mangle)]
#[allow(non_snake_case)]
pub unsafe extern "C" fn luaopen_rust_backend(L: *mut lua_State) -> c_int {
    unsafe {
        luaL_newmetatable(L, BACKEND_CLASS_MT_NAME);
        luaL_register(L, null(), RUST_BACKEND_OBJECT_META.as_ptr());
        lua_pushstring(L, b"__index\0".as_ptr() as *const c_char);
        lua_pushvalue(L, -2);
        lua_settable(L, -3);

        lua_pop(L, 1);
        let library_name = b"rust_backend".as_ptr() as *const c_char;
        luaL_register(L, library_name, RUST_BACKEND_CLASS_META.as_ptr());
    }
    1
}
