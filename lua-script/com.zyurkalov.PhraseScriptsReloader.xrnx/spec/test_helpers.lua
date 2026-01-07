--- @class TestHelpers
--- @field create_rust_backend_mock fun(): RustBackendMock
--- @field create_renoise_mock fun(file_name?: string): nil

--- @class RustBackendMock
--- @field swap_instruments fun(file_name: string, i1: number, i2: number)
--- @field remove_instrument fun(file_name: string, index: number)
--- @field swap_instruments_called boolean
--- @field remove_instrument_called boolean
--- @field swap_instruments_calls table[]
--- @field remove_instrument_calls table[]
--- @field reset fun()

local M = {}

--- Creates a mock for the rust_backend with call tracking
--- @return RustBackendMock
function M.create_rust_backend_mock()
    local mock = {
        swap_instruments_called = false,
        remove_instrument_called = false,
        swap_instruments_calls = {},
        remove_instrument_calls = {},
    }

    mock.swap_instruments = function(file_name, i1, i2)
        mock.swap_instruments_called = true
        table.insert(mock.swap_instruments_calls, {
            file_name = file_name,
            i1 = i1,
            i2 = i2
        })
    end

    mock.remove_instrument = function(file_name, index)
        mock.remove_instrument_called = true
        table.insert(mock.remove_instrument_calls, {
            file_name = file_name,
            index = index
        })
    end

    mock.reset = function()
        mock.swap_instruments_called = false
        mock.remove_instrument_called = false
        mock.swap_instruments_calls = {}
        mock.remove_instrument_calls = {}
    end

    return mock
end

--- Sets up the global renoise mock
--- @param file_name? string The file name to return (defaults to "test_song.xrns")
function M.setup_renoise_mock(file_name)
    file_name = file_name or "test_song.xrns"
    _G.renoise = {
        song = function()
            return {
                file_name = file_name
            }
        end
    }
end

return M