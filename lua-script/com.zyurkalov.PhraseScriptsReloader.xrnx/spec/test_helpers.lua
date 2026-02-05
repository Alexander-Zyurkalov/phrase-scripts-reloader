--- @class TestHelpers
--- @field create_rust_backend_mock fun(): RustBackendMock
--- @field create_renoise_mock fun(file_name?: string): nil

--- @class RustBackendMock
--- @field set_new_instrument_indexes fun(self: RustBackendMock, id_index_pairs: table[])
--- @field set_new_phrase_indexes fun(self: RustBackendMock, instrument_id: number, id_index_pairs: table[])
--- @field unregister_instrument fun(self: RustBackendMock, instrument_id: number)
--- @field unregister_script fun(self: RustBackendMock, instrument_id: number, phrase_id: number)
--- @field register_script fun(self: RustBackendMock, instrument_id: number, instrument_name: string, phrase_id: number, phrase_name: string, script_body: string)
--- @field rename_script fun(self: RustBackendMock, instrument_id: number, phrase_id: number, new_name: string)
--- @field rename_instrument fun(self: RustBackendMock, instrument_id: number, new_name: string)
--- @field take_changes fun(self: RustBackendMock): table[]
--- @field pending_changes table[] Changes to be returned by take_changes
--- @field set_new_instrument_indexes_called boolean
--- @field set_new_phrase_indexes_called boolean
--- @field unregister_instrument_called boolean
--- @field unregister_script_called boolean
--- @field register_script_called boolean
--- @field rename_script_called boolean
--- @field rename_instrument_called boolean
--- @field set_new_instrument_indexes_calls table[]
--- @field set_new_phrase_indexes_calls table[]
--- @field unregister_instrument_calls table[]
--- @field unregister_script_calls table[]
--- @field register_script_calls table[]
--- @field rename_script_calls table[]
--- @field rename_instrument_calls table[]
--- @field reset fun(self: RustBackendMock)

local M = {}

--- Creates a mock for the rust_backend with call tracking
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
        set_new_instrument_indexes_calls = {},
        set_new_phrase_indexes_calls = {},
        unregister_instrument_calls = {},
        unregister_script_calls = {},
        register_script_calls = {},
        rename_script_calls = {},
        rename_instrument_calls = {},
        pending_changes = {},
    }

    function mock:take_changes()
        local changes = self.pending_changes
        self.pending_changes = {}
        return changes
    end

    function mock:set_new_instrument_indexes(id_index_pairs)
        self.set_new_instrument_indexes_called = true
        table.insert(self.set_new_instrument_indexes_calls, {
            id_index_pairs = id_index_pairs
        })
    end

    function mock:set_new_phrase_indexes(instrument_id, id_index_pairs)
        self.set_new_phrase_indexes_called = true
        table.insert(self.set_new_phrase_indexes_calls, {
            instrument_id = instrument_id,
            id_index_pairs = id_index_pairs
        })
    end

    function mock:unregister_instrument(instrument_id)
        self.unregister_instrument_called = true
        table.insert(self.unregister_instrument_calls, {
            instrument_id = instrument_id
        })
    end

    function mock:unregister_script(instrument_id, phrase_id)
        self.unregister_script_called = true
        table.insert(self.unregister_script_calls, {
            instrument_id = instrument_id,
            phrase_id = phrase_id
        })
    end

    function mock:rename_instrument(instrument_id, new_name)
        self.rename_instrument_called = true
        table.insert(self.rename_instrument_calls, {
            instrument_id = instrument_id,
            new_name = new_name
        })
    end

    function mock:register_script(instrument_id, instrument_name, phrase_id, phrase_name, script_body)
        self.register_script_called = true
        table.insert(self.register_script_calls, {
            instrument_id = instrument_id,
            instrument_name = instrument_name,
            phrase_id = phrase_id,
            phrase_name = phrase_name,
            script_body = script_body
        })
    end

    function mock:rename_script(instrument_id, phrase_id, new_name)
        self.rename_script_called = true
        table.insert(self.rename_script_calls, {
            instrument_id = instrument_id,
            phrase_id = phrase_id,
            new_name = new_name
        })
    end

    function mock:reset()
        self.set_new_instrument_indexes_called = false
        self.set_new_phrase_indexes_called = false
        self.unregister_instrument_called = false
        self.unregister_script_called = false
        self.register_script_called = false
        self.rename_script_called = false
        self.rename_instrument_called = false
        self.set_new_instrument_indexes_calls = {}
        self.set_new_phrase_indexes_calls = {}
        self.unregister_instrument_calls = {}
        self.unregister_script_calls = {}
        self.register_script_calls = {}
        self.rename_script_calls = {}
        self.rename_instrument_calls = {}
        self.pending_changes = {}
    end

    return mock
end


return M