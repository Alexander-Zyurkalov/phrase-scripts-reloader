use std::fs;
use std::time::SystemTime;
use std::os::raw::{c_char, c_int};
use std::ffi::CStr;

#[repr(C)]
pub struct lua_State {
    _private: [u8; 0],
}

unsafe extern "C" {
    fn lua_pushinteger(L: *mut lua_State, n: i64);
    fn lua_pushnil(L: *mut lua_State);
    fn lua_tolstring(L: *mut lua_State, index: c_int, len: *mut usize) -> *const c_char;
    fn lua_settable(L: *mut lua_State, index: c_int);
    fn lua_pushcclosure(L: *mut lua_State, f: unsafe extern "C" fn(*mut lua_State) -> c_int, n: c_int);
    fn lua_pushstring(L: *mut lua_State, s: *const c_char) -> *const c_char;
    fn lua_createtable(L: *mut lua_State, narr: c_int, nrec: c_int);
}

unsafe extern "C" fn get_file_mtime(L: *mut lua_State) -> c_int {
    unsafe {
        // Get the string argument from Lua stack
        let c_str = lua_tolstring(L, 1, std::ptr::null_mut());
        if c_str.is_null() {
            lua_pushnil(L);
            return 1;
        }

        let path = match CStr::from_ptr(c_str).to_str() {
            Ok(s) => s,
            Err(_) => {
                lua_pushnil(L);
                return 1;
            }
        };

        // Get file modification time
        match fs::metadata(path) {
            Ok(metadata) => match metadata.modified() {
                Ok(time) => match time.duration_since(SystemTime::UNIX_EPOCH) {
                    Ok(duration) => {
                        lua_pushinteger(L, duration.as_secs() as i64);
                        return 1;
                    }
                    Err(_) => {}
                },
                Err(_) => {}
            },
            Err(_) => {}
        }

        lua_pushnil(L);
        1
    }
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn luaopen_phrase_scripts_reloader(L: *mut lua_State) -> c_int {
    unsafe {
        // Create a new table for our module
        lua_createtable(L, 0, 1);

        // Add get_mtime function to the table
        lua_pushstring(L, b"get_mtime\0".as_ptr() as *const c_char);
        lua_pushcclosure(L, get_file_mtime, 0);
        lua_settable(L, -3);

        1  // Return 1 value (the table)
    }
}