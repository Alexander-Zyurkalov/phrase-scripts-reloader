--- @class MainModule
--- @field rust_backend RustBackend
--- @field registry IndexRegistry
--- @field new fun(rust_backend: RustBackend, registry: IndexRegistry): MainModule
--- @field swap_instrument_indexes fun(self: MainModule, notification: {type: string, index1: number, index2: number})
--- @field swap_phrases_indexes fun(self: MainModule, instrument_id: number, notification: {type: string, index1: number, index2: number})
--- @field remove_instrument fun(self: MainModule, notification: {type: string, index: number})
--- @field remove_phrase fun(self: MainModule, instrument_id: number, notification: {type: string, index: number})
--- @field rename_instrument fun(self: MainModule, instrument_id: number, new_instrument_name: string)
--- @field register_script fun(self: MainModule, instrument_id: number, phrase_id: number, script_text: string)
--- @field unregister_script fun(self: MainModule, instrument_id: number, phrase_id: number)
--- @field rename_phrase fun(self: MainModule, instrument_id: number, phrase_id: number, new_name: string, is_playing_script: boolean)
--- @field take_changes fun(self: MainModule): {path: string, instrument_index: number, phrase_index: number, phrase_name: string, script_body: string}[]

local M = {}
M.__index = M

--- @param rust_backend RustBackend
--- @param registry IndexRegistry
--- @return MainModule
function M.new(rust_backend, registry)
    local self = setmetatable({}, M)
    self.rust_backend = rust_backend
    self.registry = registry
    return self
end

--- @param notification {type: string, index1: number, index2: number}
function M:swap_instrument_indexes(notification)
    local index1 = notification.index1
    local index2 = notification.index2
    self.registry:swap_instrument_indexes(index1, index2)
    self.rust_backend:set_new_instrument_indexes({ index1, index2 })
end

--- @param instrument_id number
--- @param notification {type: string, index1: number, index2: number}
function M:swap_phrases_indexes(instrument_id, notification)
    local index1 = notification.index1
    local index2 = notification.index2
    local instrument_data = self.registry:get_instrument_by_id(instrument_id)
    self.registry:swap_phrase_indexes(instrument_id, index1, index2)
    self.rust_backend:set_new_phrase_indexes(instrument_data.current_index, { index1, index2 })
end

--- @param notification {type: string, index: number}
function M:remove_instrument(notification)
    local removed_index = notification.index

    local instrument_id, instrument_data = self.registry:find_instrument_by_index(removed_index)
    if instrument_data then
        self.rust_backend:remove_instrument(instrument_data.current_index)
        self.registry:remove_instrument(instrument_id)
    end
end

--- @param instrument_id number
--- @param notification {type: string, index: number}
function M:remove_phrase(instrument_id, notification)
    local removed_index = notification.index
    local instrument_data = self.registry:get_instrument_by_id(instrument_id)
    local phrase_id, phrase_data = self.registry:find_phrase_by_index(instrument_id, removed_index)
    if phrase_id and phrase_data then
        if phrase_data.is_script_registered then
            self.rust_backend:unregister_script(instrument_data.current_index, phrase_data.current_index)
        end
        self.registry:remove_phrase(instrument_id, phrase_id)
    end

end

--- @param instrument_id number
--- @param new_instrument_name string
function M:rename_instrument(instrument_id, new_instrument_name)
    local instrument_data = self.registry:get_instrument_by_id(instrument_id)
    self.rust_backend:rename_instrument(
            instrument_data.current_index,
            instrument_data.name,
            new_instrument_name
    )
    instrument_data.name = new_instrument_name
end

--- @param instrument_id number
--- @param phrase_id number
--- @param script_text string
function M:register_script(instrument_id, phrase_id, script_text)
    local instrument_data = self.registry:get_instrument_by_id(instrument_id)
    local phrase_data = self.registry:get_phrase_by_id(instrument_id, phrase_id)
    self.rust_backend:register_script(
            instrument_data.current_index,
            instrument_data.name,
            phrase_data.current_index,
            phrase_data.name,
            script_text
    )
    phrase_data.is_script_registered = true
end

--- @param instrument_id number
--- @param phrase_id number
function M:unregister_script(instrument_id, phrase_id)
    local instrument_data = self.registry:get_instrument_by_id(instrument_id)
    local phrase_data = self.registry:get_phrase_by_id(instrument_id, phrase_id)
    self.rust_backend:unregister_script(
            instrument_data.current_index,
            phrase_data.current_index
    )
    phrase_data.is_script_registered = false
end

--- Renames a phrase and optionally its script file (if phrase is in script playback mode)
--- @param instrument_id number
--- @param phrase_id number
--- @param new_name string
--- @param is_playing_script boolean Whether the phrase is in PLAY_SCRIPT mode
function M:rename_phrase(instrument_id, phrase_id, new_name, is_playing_script)
    local instrument_data = self.registry:get_instrument_by_id(instrument_id)
    local phrase_data = self.registry:get_phrase_by_id(instrument_id, phrase_id)

    if is_playing_script then
        self.rust_backend:rename_script(
                instrument_data.current_index,
                phrase_data.current_index,
                phrase_data.name,
                new_name
        )
    end

    phrase_data.name = new_name
end

--- Retrieves pending changes from the rust backend
--- @return {path: string, instrument_index: number, phrase_index: number, phrase_name: string, script_body: string}[]
function M:take_changes()
    return self.rust_backend:take_changes()
end

return M