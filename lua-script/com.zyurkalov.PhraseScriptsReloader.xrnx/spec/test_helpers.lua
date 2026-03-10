--- @class TestHelpers
--- @field create_rust_backend_mock fun(): RustBackendMock
--- @field create_renoise_mock fun(file_name?: string): nil

--- @class RustBackendMock
--- @field set_new_instrument_indexes fun(self: RustBackendMock, id_index_pairs: table[]): nil, string|nil
--- @field set_new_phrase_indexes fun(self: RustBackendMock, instrument_id: number, id_index_pairs: table[]): nil, string|nil
--- @field unregister_instrument fun(self: RustBackendMock, instrument_id: number): nil, string|nil
--- @field unregister_script fun(self: RustBackendMock, instrument_id: number, phrase_id: number): string|nil, string|nil
--- @field register_script fun(self: RustBackendMock, instrument_id: number, instrument_name: string, phrase_id: number, phrase_name: string, script_body: string): string|nil, string|nil
--- @field rename_script fun(self: RustBackendMock, instrument_id: number, phrase_id: number, new_name: string): nil, string|nil
--- @field rename_instrument fun(self: RustBackendMock, instrument_id: number, new_name: string): nil, string|nil
--- @field update_song_path fun(self: RustBackendMock, path: string): nil, string|nil
--- @field take_changes fun(self: RustBackendMock): table[], string|nil
--- @field pending_changes table[] Changes to be returned by take_changes
--- @field set_new_instrument_indexes_called boolean
--- @field set_new_phrase_indexes_called boolean
--- @field unregister_instrument_called boolean
--- @field unregister_script_called boolean
--- @field register_script_called boolean
--- @field rename_script_called boolean
--- @field rename_instrument_called boolean
--- @field update_song_path_called boolean
--- @field set_new_instrument_indexes_calls table[]
--- @field set_new_phrase_indexes_calls table[]
--- @field unregister_instrument_calls table[]
--- @field unregister_script_calls table[]
--- @field register_script_calls table[]
--- @field rename_script_calls table[]
--- @field rename_instrument_calls table[]
--- @field update_song_path_calls table[]
--- @field forced_error string|nil When set, all calls return this as an error
--- @field reset fun(self: RustBackendMock)

local M = {}

--- Creates a mock for the rust_backend with call tracking
--- All methods return (result, nil) on success to match the real Rust backend interface.
--- Set mock.forced_error to a string to simulate backend errors.
--- @return RustBackendMock
function M.create_rust_backend_mock()
    local mock = {
        set_new_instrument_indexes_called = false,
        set_new_phrase_indexes_called = false,
        unregister_instrument_called = false,
        unregister_script_called = false,
        register_script_called = false,
        rename_script_called = false,
        rename_instrument_called = false,
        update_song_path_called = false,
        set_new_instrument_indexes_calls = {},
        set_new_phrase_indexes_calls = {},
        unregister_instrument_calls = {},
        unregister_script_calls = {},
        register_script_calls = {},
        rename_script_calls = {},
        rename_instrument_calls = {},
        update_song_path_calls = {},
        pending_changes = {},
        forced_error = nil,
    }

    --- @return table[], string|nil
    function mock:take_changes()
        if self.forced_error then
            return nil, self.forced_error
        end
        local changes = self.pending_changes
        self.pending_changes = {}
        return changes, nil
    end

    --- @return nil, string|nil
    function mock:set_new_instrument_indexes(id_index_pairs)
        self.set_new_instrument_indexes_called = true
        table.insert(self.set_new_instrument_indexes_calls, {
            id_index_pairs = id_index_pairs
        })
        if self.forced_error then
            return nil, self.forced_error
        end
        return nil, nil
    end

    --- @return nil, string|nil
    function mock:set_new_phrase_indexes(instrument_id, id_index_pairs)
        self.set_new_phrase_indexes_called = true
        table.insert(self.set_new_phrase_indexes_calls, {
            instrument_id = instrument_id,
            id_index_pairs = id_index_pairs
        })
        if self.forced_error then
            return nil, self.forced_error
        end
        return nil, nil
    end

    --- @return nil, string|nil
    function mock:unregister_instrument(instrument_id)
        self.unregister_instrument_called = true
        table.insert(self.unregister_instrument_calls, {
            instrument_id = instrument_id
        })
        if self.forced_error then
            return nil, self.forced_error
        end
        return nil, nil
    end

    --- @return string|nil, string|nil
    function mock:unregister_script(instrument_id, phrase_id)
        self.unregister_script_called = true
        table.insert(self.unregister_script_calls, {
            instrument_id = instrument_id,
            phrase_id = phrase_id
        })
        if self.forced_error then
            return nil, self.forced_error
        end
        return "/mock/path/script.lua.bak", nil
    end

    --- @return nil, string|nil
    function mock:rename_instrument(instrument_id, new_name)
        self.rename_instrument_called = true
        table.insert(self.rename_instrument_calls, {
            instrument_id = instrument_id,
            new_name = new_name
        })
        if self.forced_error then
            return nil, self.forced_error
        end
        return nil, nil
    end

    --- @return string|nil, string|nil
    function mock:register_script(instrument_id, instrument_name, phrase_id, phrase_name, script_body)
        self.register_script_called = true
        table.insert(self.register_script_calls, {
            instrument_id = instrument_id,
            instrument_name = instrument_name,
            phrase_id = phrase_id,
            phrase_name = phrase_name,
            script_body = script_body
        })
        if self.forced_error then
            return nil, self.forced_error
        end
        return "/mock/path/script.lua", nil
    end

    --- @return nil, string|nil
    function mock:rename_script(instrument_id, phrase_id, new_name)
        self.rename_script_called = true
        table.insert(self.rename_script_calls, {
            instrument_id = instrument_id,
            phrase_id = phrase_id,
            new_name = new_name
        })
        if self.forced_error then
            return nil, self.forced_error
        end
        return nil, nil
    end

    --- @return nil, string|nil
    function mock:update_song_path(path)
        self.update_song_path_called = true
        table.insert(self.update_song_path_calls, {
            path = path
        })
        if self.forced_error then
            return nil, self.forced_error
        end
        return nil, nil
    end

    function mock:reset()
        self.set_new_instrument_indexes_called = false
        self.set_new_phrase_indexes_called = false
        self.unregister_instrument_called = false
        self.unregister_script_called = false
        self.register_script_called = false
        self.rename_script_called = false
        self.rename_instrument_called = false
        self.update_song_path_called = false
        self.set_new_instrument_indexes_calls = {}
        self.set_new_phrase_indexes_calls = {}
        self.unregister_instrument_calls = {}
        self.unregister_script_calls = {}
        self.register_script_calls = {}
        self.rename_script_calls = {}
        self.rename_instrument_calls = {}
        self.update_song_path_calls = {}
        self.pending_changes = {}
        self.forced_error = nil
    end

    return mock
end

return M