mod backend;
mod file_changes_monitor;
mod indexes;
mod instrument_registry;
mod script_paths;

use crate::backend::Backend;
use std::ffi::{c_longlong, CStr};
use std::os::raw::{c_char, c_int};
use std::ptr::{null, null_mut};
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
    fn lua_tolstring(L: *mut lua_State, index: c_int, len: *mut usize) -> *const c_char;
    fn lua_settable(L: *mut lua_State, index: c_int);
    fn lua_pushcclosure(
        L: *mut lua_State,
        f: unsafe extern "C" fn(*mut lua_State) -> c_int,
        n: c_int,
    );
    fn lua_pushstring(L: *mut lua_State, s: *const c_char) -> *const c_char;
    fn lua_createtable(L: *mut lua_State, narr: c_int, nrec: c_int);
    fn lua_newuserdata(L: *mut lua_State, size: usize);
    fn luaL_checklstring(L: *mut lua_State, arg: c_int, l: *mut usize) -> *const c_char;
    fn luaL_checkinteger(L: *mut lua_State, arg: c_int) -> c_longlong;
    fn luaL_register(L: *mut lua_State, libname: *const c_char, l: *const luaL_Reg);
    fn luaL_error(L: *mut lua_State, fmt: *const c_char, ...) -> c_int;
}

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
        let backend = Backend::new(path, Duration::from_secs(c_seconds as u64));
    }
    1
}

const RUST_BACKEND: [luaL_Reg; 2] = [
    luaL_Reg { name: b"new\0".as_ptr() as *const c_char, func: new as lua_CFunction },
    luaL_Reg { name: null(), func: null() },
];

#[unsafe(no_mangle)]
#[allow(non_snake_case)]
pub unsafe extern "C" fn luaopen_phrase_scripts_reloader(L: *mut lua_State) -> c_int {
    luaL_register(L, b"rust_backend\0".as_ptr() as *const c_char, RUST_BACKEND.as_ptr());
    1 // Return 1 value (the table)
}
