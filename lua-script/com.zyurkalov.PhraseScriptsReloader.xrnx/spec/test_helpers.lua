--- @class TestHelpers
--- @field create_rust_backend_mock fun(): RustBackendMock
--- @field create_renoise_mock fun(file_name?: string): nil

--- @class RustBackendMock
--- @field set_new_instrument_indexes fun(self: RustBackendMock, instrument_indexes: number[])
--- @field set_new_phrase_indexes fun(self: RustBackendMock, instrument_index: number, phrase_indexes: number[])
--- @field remove_instrument fun(self: RustBackendMock, index: number)
--- @field unregister_script fun(self: RustBackendMock, instrument_index: number, phrase_index: number)
--- @field register_script fun(self: RustBackendMock, instrument_index: number, instrument_name: string, phrase_index: number, phrase_name: string, script_body: string)
--- @field rename_script fun(self: RustBackendMock, instrument_index: number, phrase_index: number, old_name: string, new_name: string)
--- @field rename_instrument fun(self: RustBackendMock, instrument_index: number, old_name: string, new_name: string)
--- @field set_new_instrument_indexes_called boolean
--- @field set_new_phrase_indexes_called boolean
--- @field remove_instrument_called boolean
--- @field unregister_script_called boolean
--- @field register_script_called boolean
--- @field rename_script_called boolean
--- @field rename_instrument_called boolean
--- @field set_new_instrument_indexes_calls table[]
--- @field set_new_phrase_indexes_calls table[]
--- @field remove_instrument_calls table[]
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
        remove_instrument_called = false,
        unregister_script_called = false,
        register_script_called = false,
        rename_script_called = false,
        rename_instrument_called = false,
        set_new_instrument_indexes_calls = {},
        set_new_phrase_indexes_calls = {},
        remove_instrument_calls = {},
        unregister_script_calls = {},
        register_script_calls = {},
        rename_script_calls = {},
        rename_instrument_calls = {},
    }

    function mock:set_new_instrument_indexes(instrument_indexes)
        self.set_new_instrument_indexes_called = true
        table.insert(self.set_new_instrument_indexes_calls, {
            instrument_indexes = instrument_indexes
        })
    end

    function mock:set_new_phrase_indexes(instrument_index, phrase_indexes)
        self.set_new_phrase_indexes_called = true
        table.insert(self.set_new_phrase_indexes_calls, {
            instrument_index = instrument_index,
            phrase_indexes = phrase_indexes
        })
    end

    function mock:remove_instrument(index)
        self.remove_instrument_called = true
        table.insert(self.remove_instrument_calls, {
            index = index
        })
    end

    function mock:unregister_script(instrument_index, phrase_index)
        self.unregister_script_called = true
        table.insert(self.unregister_script_calls, {
            instrument_index = instrument_index,
            phrase_index = phrase_index
        })
    end

    function mock:rename_instrument(instrument_index, old_name, new_name)
        self.rename_instrument_called = true
        table.insert(self.rename_instrument_calls, {
            instrument_index = instrument_index,
            old_name = old_name,
            new_name = new_name
        })
    end

    function mock:register_script(instrument_index, instrument_name, phrase_index, phrase_name, script_body)
        self.register_script_called = true
        table.insert(self.register_script_calls, {
            instrument_index = instrument_index,
            instrument_name = instrument_name,
            phrase_index = phrase_index,
            phrase_name = phrase_name,
            script_body = script_body
        })
    end

    function mock:rename_script(instrument_index, phrase_index, old_name, new_name)
        self.rename_script_called = true
        table.insert(self.rename_script_calls, {
            instrument_index = instrument_index,
            phrase_index = phrase_index,
            old_name = old_name,
            new_name = new_name
        })
    end

    function mock:reset()
        self.set_new_instrument_indexes_called = false
        self.set_new_phrase_indexes_called = false
        self.remove_instrument_called = false
        self.unregister_script_called = false
        self.register_script_called = false
        self.rename_script_called = false
        self.rename_instrument_called = false
        self.set_new_instrument_indexes_calls = {}
        self.set_new_phrase_indexes_calls = {}
        self.remove_instrument_calls = {}
        self.unregister_script_calls = {}
        self.register_script_calls = {}
        self.rename_script_calls = {}
        self.rename_instrument_calls = {}
    end

    return mock
end


return M