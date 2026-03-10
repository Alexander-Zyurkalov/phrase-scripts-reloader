mod backend;
mod file_changes_monitor;
mod indexes;
mod instrument_registry;
mod script_paths;

use crate::backend::Backend;
use crate::indexes::{InstrumentId, InstrumentIndex, PhraseId, PhraseIndex};
use anyhow::{anyhow, Context, Error, Result};
use std::ffi::{c_longlong, c_void, CStr};
use std::fmt::Display;
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
const LUA_TNIL: c_int = 0;
const LUA_TSTRING: c_int = 4;

const BACKEND_CLASS_MT_NAME: *const c_char = b"RustBackend\0".as_ptr() as *const c_char;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

#[inline]
#[allow(non_snake_case)]
unsafe fn lua_pop(L: *mut lua_State, n: c_int) {
    lua_settop(L, -n - 1);
}

#[allow(non_snake_case)]
unsafe fn make_lua_error(L: *mut lua_State, err: Error) -> c_int {
    lua_pushnil(L);
    let err_cstring = std::ffi::CString::new(err.to_string()).unwrap_or_else(|_| {
        std::ffi::CString::new("Can't even make an error message".to_string()).unwrap()
    });
    lua_pushstring(L, err_cstring.as_ptr());
    2
}

#[allow(non_snake_case)]
unsafe fn get_string_or_error(L: *mut lua_State, argument_num: i32) -> Result<String> {
    unsafe {
        let c_str: *const c_char = lua_tolstring(L, argument_num, null_mut());
        if c_str.is_null() {
            return Err(anyhow!("Argument {} is not a string", argument_num));
        }
        let path = CStr::from_ptr(c_str)
            .to_str()
            .with_context(|| format!("Argument {} contains invalid UTF-8", argument_num))?
            .to_owned();
        Ok(path)
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

/// Push a Rust string onto the Lua stack via a temporary CString.
#[allow(non_snake_case)]
unsafe fn push_rust_string(L: *mut lua_State, s: &str) {
    let cstring = std::ffi::CString::new(s)
        .unwrap_or_else(|_| std::ffi::CString::new("<invalid string>").unwrap());
    lua_pushstring(L, cstring.as_ptr());
}

// ---------------------------------------------------------------------------
// new(path, seconds) -> Backend userdata
// ---------------------------------------------------------------------------

#[allow(non_snake_case)]
unsafe extern "C" fn new(L: *mut lua_State) -> c_int {
    unsafe {
        let path = match get_string_or_error(L, 1) {
            Ok(value) => value,
            Err(value) => return make_lua_error(L, value),
        };
        let c_seconds = lua_tointeger(L, 2);

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

// ---------------------------------------------------------------------------
// backend:update_song_path(path) -> nil | (nil, err)
// ---------------------------------------------------------------------------

#[allow(non_snake_case)]
unsafe extern "C" fn update_song_path(L: *mut lua_State) -> c_int {
    unsafe {
        match update_song_path_inner(L) {
            Ok(()) => 0,
            Err(err) => make_lua_error(L, err),
        }
    }
}

#[allow(non_snake_case)]
unsafe fn update_song_path_inner(L: *mut lua_State) -> Result<()> {
    unsafe {
        let song_path = get_string_or_error(L, 2)?;
        let backend = get_backend(L)?;
        backend.update_song_path(song_path)?;
        Ok(())
    }
}

// ---------------------------------------------------------------------------
// backend:set_new_instrument_indexes({{id,idx}, ...}) -> nil | (nil, err)
// ---------------------------------------------------------------------------

#[allow(non_snake_case)]
unsafe extern "C" fn set_new_instrument_indexes(L: *mut lua_State) -> c_int {
    unsafe {
        match set_new_instrument_indexes_inner(L) {
            Ok(()) => 0,
            Err(err) => make_lua_error(L, err),
        }
    }
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
            pairs.push((InstrumentId::from(id), instrument_index));
        }

        let backend = get_backend(L)?;
        backend.set_new_instrument_indexes(pairs);
        Ok(())
    }
}

// ---------------------------------------------------------------------------
// backend:set_new_phrase_indexes(instrument_id, {{id,idx}, ...}) -> nil | (nil, err)
// ---------------------------------------------------------------------------

#[allow(non_snake_case)]
unsafe extern "C" fn set_new_phrase_indexes(L: *mut lua_State) -> c_int {
    unsafe {
        match set_new_phrase_indexes_inner(L) {
            Ok(()) => 0,
            Err(err) => make_lua_error(L, err),
        }
    }
}

#[allow(non_snake_case)]
unsafe fn set_new_phrase_indexes_inner(L: *mut lua_State) -> Result<()> {
    unsafe {
        let instrument_id = InstrumentId::from(lua_tointeger(L, 2));
        let len = lua_objlen(L, 3) as c_int;
        let mut pairs: Vec<(PhraseId, PhraseIndex)> = Vec::with_capacity(len as usize);

        for i in 1..=len {
            lua_rawgeti(L, 3, i);
            lua_rawgeti(L, -1, 1);
            let id = lua_tointeger(L, -1);
            lua_pop(L, 1);
            lua_rawgeti(L, -1, 2);
            let index = lua_tointeger(L, -1);
            lua_pop(L, 1);
            lua_pop(L, 1);

            let phrase_index = PhraseIndex::try_from(index)?;
            pairs.push((PhraseId::from(id), phrase_index));
        }

        let backend = get_backend(L)?;
        backend.set_new_phrase_indexes(instrument_id, pairs);
        Ok(())
    }
}

// ---------------------------------------------------------------------------
// backend:register_script(instr_id, instr_name, phrase_id, phrase_name [, body])
//   -> path | (nil, err)
// ---------------------------------------------------------------------------

#[allow(non_snake_case)]
unsafe extern "C" fn register_script(L: *mut lua_State) -> c_int {
    unsafe {
        match register_script_inner(L) {
            Ok(_) => 1,
            Err(err) => make_lua_error(L, err),
        }
    }
}

#[allow(non_snake_case)]
unsafe fn register_script_inner(L: *mut lua_State) -> Result<()> {
    unsafe {
        let instrument_id = InstrumentId::from(lua_tointeger(L, 2));
        let instrument_name = get_string_or_error(L, 3)?;
        let phrase_id = PhraseId::from(lua_tointeger(L, 4));
        let phrase_name = get_string_or_error(L, 5)?;

        // Argument 6 is optional: nil means None
        let script_body: Option<String> = if lua_type(L, 6) == LUA_TNIL || lua_gettop(L) < 6 {
            None
        } else {
            Some(get_string_or_error(L, 6)?)
        };

        let backend = get_backend(L)?;
        let path = backend.register_script(
            instrument_id,
            &instrument_name,
            phrase_id,
            &phrase_name,
            script_body.as_deref(),
        )?;

        push_rust_string(L, &path.to_string_lossy());
        Ok(())
    }
}

// ---------------------------------------------------------------------------
// backend:unregister_script(instr_id, phrase_id) -> bak_path | (nil, err)
// ---------------------------------------------------------------------------

#[allow(non_snake_case)]
unsafe extern "C" fn unregister_script(L: *mut lua_State) -> c_int {
    unsafe {
        match unregister_script_inner(L) {
            Ok(_) => 1,
            Err(err) => make_lua_error(L, err),
        }
    }
}

#[allow(non_snake_case)]
unsafe fn unregister_script_inner(L: *mut lua_State) -> Result<()> {
    unsafe {
        let instrument_id = InstrumentId::from(lua_tointeger(L, 2));
        let phrase_id = PhraseId::from(lua_tointeger(L, 3));

        let backend = get_backend(L)?;
        let bak_path = backend.unregister_script(instrument_id, phrase_id)?;

        push_rust_string(L, &bak_path.to_string_lossy());
        Ok(())
    }
}

// ---------------------------------------------------------------------------
// backend:rename_script(instr_id, phrase_id, new_name) -> nil | (nil, err)
// ---------------------------------------------------------------------------

#[allow(non_snake_case)]
unsafe extern "C" fn rename_script(L: *mut lua_State) -> c_int {
    unsafe {
        match rename_script_inner(L) {
            Ok(()) => 0,
            Err(err) => make_lua_error(L, err),
        }
    }
}

#[allow(non_snake_case)]
unsafe fn rename_script_inner(L: *mut lua_State) -> Result<()> {
    unsafe {
        let instrument_id = InstrumentId::from(lua_tointeger(L, 2));
        let phrase_id = PhraseId::from(lua_tointeger(L, 3));
        let new_name = get_string_or_error(L, 4)?;

        let backend = get_backend(L)?;
        backend.rename_script(instrument_id, phrase_id, &new_name)?;
        Ok(())
    }
}

// ---------------------------------------------------------------------------
// backend:rename_instrument(instr_id, new_name) -> nil | (nil, err)
// ---------------------------------------------------------------------------

#[allow(non_snake_case)]
unsafe extern "C" fn rename_instrument(L: *mut lua_State) -> c_int {
    unsafe {
        match rename_instrument_inner(L) {
            Ok(()) => 0,
            Err(err) => make_lua_error(L, err),
        }
    }
}

#[allow(non_snake_case)]
unsafe fn rename_instrument_inner(L: *mut lua_State) -> Result<()> {
    unsafe {
        let instrument_id = InstrumentId::from(lua_tointeger(L, 2));
        let new_name = get_string_or_error(L, 3)?;

        let backend = get_backend(L)?;
        backend.rename_instrument(instrument_id, &new_name)?;
        Ok(())
    }
}

// ---------------------------------------------------------------------------
// backend:unregister_instrument(instr_id) -> nil | (nil, err)
// ---------------------------------------------------------------------------

#[allow(non_snake_case)]
unsafe extern "C" fn unregister_instrument(L: *mut lua_State) -> c_int {
    unsafe {
        match unregister_instrument_inner(L) {
            Ok(()) => 0,
            Err(err) => make_lua_error(L, err),
        }
    }
}

#[allow(non_snake_case)]
unsafe fn unregister_instrument_inner(L: *mut lua_State) -> Result<()> {
    unsafe {
        let instrument_id = InstrumentId::from(lua_tointeger(L, 2));

        let backend = get_backend(L)?;
        backend.unregister_instrument(instrument_id)?;
        Ok(())
    }
}

// ---------------------------------------------------------------------------
// backend:take_changes() -> { {instrument_id=…, …}, … } | (nil, err)
//
// Each element is a table with fields:
//   instrument_id, instrument_name, phrase_id, phrase_name, script_body
// ---------------------------------------------------------------------------

#[allow(non_snake_case)]
unsafe extern "C" fn take_changes(L: *mut lua_State) -> c_int {
    unsafe {
        match take_changes_inner(L) {
            Ok(_) => 1,
            Err(err) => make_lua_error(L, err),
        }
    }
}

#[allow(non_snake_case)]
unsafe fn take_changes_inner(L: *mut lua_State) -> Result<()> {
    unsafe {
        let backend = get_backend(L)?;
        let changes = backend.take_changes()?;

        // Create the outer array table
        lua_createtable(L, changes.len() as c_int, 0);

        for (i, change) in changes.iter().enumerate() {
            // Create a table for each ScriptChange: 5 named fields
            // Stack: [outer]
            lua_createtable(L, 0, 5);
            // Stack: [outer, change]

            push_rust_string(L, "instrument_id");
            lua_pushinteger(L,change.instrument_id.into());
            lua_settable(L, -3);

            push_rust_string(L, "instrument_name");
            push_rust_string(L, &change.instrument_name);
            lua_settable(L, -3);

            push_rust_string(L, "phrase_id");
            lua_pushinteger(L, change.phrase_id.into());
            lua_settable(L, -3);

            push_rust_string(L, "phrase_name");
            push_rust_string(L, &change.phrase_name);
            lua_settable(L, -3);

            push_rust_string(L, "script_body");
            push_rust_string(L, &change.script_body);
            lua_settable(L, -3);

            // Stack: [outer, change]
            // Set outer[i+1] = change
            lua_pushinteger(L, (i + 1) as i64);
            lua_pushvalue(L, -2);
            // Stack: [outer, change, key, change_copy]
            lua_settable(L, -4);
            // Stack: [outer, change]
            lua_pop(L, 1);
            // Stack: [outer]
        }

        Ok(())
    }
}

// ---------------------------------------------------------------------------
// __gc metamethod
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Registration tables
// ---------------------------------------------------------------------------

const RUST_BACKEND_OBJECT_META: [luaL_Reg; 11] = [
    luaL_Reg { name: b"__gc\0".as_ptr() as *const c_char, func: backend_gc as lua_CFunction },
    luaL_Reg {
        name: b"set_new_instrument_indexes\0".as_ptr() as *const c_char,
        func: set_new_instrument_indexes as lua_CFunction,
    },
    luaL_Reg {
        name: b"set_new_phrase_indexes\0".as_ptr() as *const c_char,
        func: set_new_phrase_indexes as lua_CFunction,
    },
    luaL_Reg {
        name: b"register_script\0".as_ptr() as *const c_char,
        func: register_script as lua_CFunction,
    },
    luaL_Reg {
        name: b"unregister_script\0".as_ptr() as *const c_char,
        func: unregister_script as lua_CFunction,
    },
    luaL_Reg {
        name: b"rename_script\0".as_ptr() as *const c_char,
        func: rename_script as lua_CFunction,
    },
    luaL_Reg {
        name: b"rename_instrument\0".as_ptr() as *const c_char,
        func: rename_instrument as lua_CFunction,
    },
    luaL_Reg {
        name: b"unregister_instrument\0".as_ptr() as *const c_char,
        func: unregister_instrument as lua_CFunction,
    },
    luaL_Reg {
        name: b"take_changes\0".as_ptr() as *const c_char,
        func: take_changes as lua_CFunction,
    },
    luaL_Reg {
        name: b"update_song_path\0".as_ptr() as *const c_char,
        func: update_song_path as lua_CFunction,
    },
    // sentinel
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
