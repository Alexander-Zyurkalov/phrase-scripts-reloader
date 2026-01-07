--- @class SwapModule
--- @field swap fun(registry: IndexRegistry, notification: {type: string, index: number, index2: number|nil}, rust_backend: {swap_instruments: fun(file_name: string, i1: number, i2: number)}, index_registry_module: {get_instrument_count: fun(registry: IndexRegistry): number, swap_instrument_indexes: fun(registry: IndexRegistry, i1: number, i2: number)})


--- @type SwapModule
local M = {}

--- @param registry IndexRegistry The shared index registry
--- @param notification {type: string, index: number, index2: number|nil}
--- @param rust_backend {swap_instruments: fun(file_name: string, i1: number, i2: number)}
--- @param index_registry_module {get_instrument_count: fun(registry: IndexRegistry): number, swap_instrument_indexes: fun(registry: IndexRegistry, i1: number, i2: number)}
function M.swap(registry, notification, rust_backend, index_registry_module)
    local index1 = notification.index1
    local index2 = notification.index2
    rust_backend.swap_instruments(renoise.song().file_name, index1, index2)
    index_registry_module.swap_instrument_indexes(registry, index1, index2)
end

--- @param registry IndexRegistry The shared index registry
--- @param notification {type: string, index: number, index2: number|nil}
--- @param rust_backend {remove_instrument: fun(file_name: string, i: number)}
--- @param index_registry_module {get_instrument_count: fun(registry: IndexRegistry): number, find_instrument_by_index: fun(registry: IndexRegistry, index: number)}

function M.remove(registry, notification, rust_backend, index_registry_module)

    local removed_index = notification.index

    local instrument_id, instrument_data = index_registry_module.find_instrument_by_index(registry, removed_index)
    if instrument_data then
        rust_backend.remove_instrument(
                renoise.song().file_name,
                instrument_data.current_index
        )
        index_registry_module.remove_instrument(registry, instrument_id)
    end

end

return M