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
--- @field take_changes fun(self: MainModule): {instrument_index: number, phrase_index: number, phrase_name: string, script_body: string}[], {message: string, path: string}[]

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

--- Helper: log a rust_backend error to the console
--- @param context string Description of the operation that failed
--- @param err string The error message
local function log_backend_error(context, err)
    print("PhraseScriptsReloader [ERROR] " .. context .. ": " .. tostring(err))
end

--- @param notification {type: string, index1: number, index2: number}
function M:swap_instrument_indexes(notification)
    local index1 = notification.index1
    local index2 = notification.index2
    self.registry:swap_instrument_indexes(index1, index2)

    -- After swap, find the IDs now at each index and send id-index pairs
    local id1, _ = self.registry:find_instrument_by_index(index1)
    local id2, _ = self.registry:find_instrument_by_index(index2)

    local pairs = {}
    if id1 then
        table.insert(pairs, { id1, index1 })
    end
    if id2 then
        table.insert(pairs, { id2, index2 })
    end
    local _, err = self.rust_backend:set_new_instrument_indexes(pairs)
    if err then
        log_backend_error("set_new_instrument_indexes", err)
    end
end

--- @param instrument_id number
--- @param notification {type: string, index1: number, index2: number}
function M:swap_phrases_indexes(instrument_id, notification)
    local index1 = notification.index1
    local index2 = notification.index2
    self.registry:swap_phrase_indexes(instrument_id, index1, index2)

    -- After swap, find the IDs now at each index and send id-index pairs
    local phrase_id1, _ = self.registry:find_phrase_by_index(instrument_id, index1)
    local phrase_id2, _ = self.registry:find_phrase_by_index(instrument_id, index2)

    local pairs = {}
    if phrase_id1 then
        table.insert(pairs, { phrase_id1, index1 })
    end
    if phrase_id2 then
        table.insert(pairs, { phrase_id2, index2 })
    end
    local _, err = self.rust_backend:set_new_phrase_indexes(instrument_id, pairs)
    if err then
        log_backend_error("set_new_phrase_indexes (instrument " .. instrument_id .. ")", err)
    end
end

--- @param notification {type: string, index: number}
function M:remove_instrument(notification)
    local removed_index = notification.index

    local instrument_id, instrument_data = self.registry:find_instrument_by_index(removed_index)
    if instrument_data then
        local _, err = self.rust_backend:unregister_instrument(instrument_id)
        if err then
            log_backend_error("unregister_instrument (id " .. instrument_id .. ")", err)
        end
        self.registry:unregister_instrument(instrument_id)
    end
end

--- @param instrument_id number
--- @param notification {type: string, index: number}
function M:remove_phrase(instrument_id, notification)
    local removed_index = notification.index
    local phrase_id, phrase_data = self.registry:find_phrase_by_index(instrument_id, removed_index)
    if phrase_id and phrase_data then
        if phrase_data.is_script_registered then
            local _, err = self.rust_backend:unregister_script(instrument_id, phrase_id)
            if err then
                log_backend_error("unregister_script (instrument " .. instrument_id .. ", phrase " .. phrase_id .. ")", err)
            end
        end
        self.registry:remove_phrase(instrument_id, phrase_id)
    end

end

--- @param instrument_id number
--- @param new_instrument_name string
function M:rename_instrument(instrument_id, new_instrument_name)
    local instrument_data = self.registry:get_instrument_by_id(instrument_id)
    local _, err = self.rust_backend:rename_instrument(
            instrument_id,
            new_instrument_name
    )
    if err then
        log_backend_error("rename_instrument (id " .. instrument_id .. ")", err)
        return
    end
    instrument_data.name = new_instrument_name
end

--- @param instrument_id number
--- @param phrase_id number
--- @param script_text string
function M:register_script(instrument_id, phrase_id, script_text)
    local instrument_data = self.registry:get_instrument_by_id(instrument_id)
    local phrase_data = self.registry:get_phrase_by_id(instrument_id, phrase_id)

    -- Provide the ID-to-index mapping to the Rust backend
    local _, err = self.rust_backend:set_new_instrument_indexes({ { instrument_id, instrument_data.current_index } })
    if err then
        log_backend_error("set_new_instrument_indexes during register_script", err)
        return
    end
    local _, err2 = self.rust_backend:set_new_phrase_indexes(instrument_id, { { phrase_id, phrase_data.current_index } })
    if err2 then
        log_backend_error("set_new_phrase_indexes during register_script", err2)
        return
    end

    local _, err3 = self.rust_backend:register_script(
            instrument_id,
            instrument_data.name,
            phrase_id,
            phrase_data.name,
            script_text
    )
    if err3 then
        log_backend_error("register_script (instrument " .. instrument_id .. ", phrase " .. phrase_id .. ")", err3)
        return
    end
    phrase_data.is_script_registered = true
end

--- @param instrument_id number
--- @param phrase_id number
function M:unregister_script(instrument_id, phrase_id)
    local phrase_data = self.registry:get_phrase_by_id(instrument_id, phrase_id)
    local _, err = self.rust_backend:unregister_script(
            instrument_id,
            phrase_id
    )
    if err then
        log_backend_error("unregister_script (instrument " .. instrument_id .. ", phrase " .. phrase_id .. ")", err)
        return
    end
    phrase_data.is_script_registered = false
end

--- Renames a phrase and optionally its script file (if phrase is in script playback mode)
--- @param instrument_id number
--- @param phrase_id number
--- @param new_name string
--- @param is_playing_script boolean Whether the phrase is in PLAY_SCRIPT mode
function M:rename_phrase(instrument_id, phrase_id, new_name, is_playing_script)
    local phrase_data = self.registry:get_phrase_by_id(instrument_id, phrase_id)

    if is_playing_script then
        local _, err = self.rust_backend:rename_script(
                instrument_id,
                phrase_id,
                new_name
        )
        if err then
            log_backend_error("rename_script (instrument " .. instrument_id .. ", phrase " .. phrase_id .. ")", err)
            return
        end
    end

    phrase_data.name = new_name
end

--- Retrieves pending changes from the rust backend, converting IDs to indexes
--- Filters out changes where IDs no longer exist in the registry or names don't match
--- @return {instrument_index: number, phrase_index: number, phrase_name: string, script_body: string}[] validated_changes
--- @return {message: string, path: string}[] errors
function M:take_changes()
    local raw_changes, err = self.rust_backend:take_changes()
    if err then
        log_backend_error("take_changes", err)
        return {}, {}
    end

    local validated_changes = {}
    local errors = {}

    for _, change in ipairs(raw_changes) do
        local instrument_data = self.registry:get_instrument_by_id(change.instrument_id)
        if not instrument_data then
            table.insert(errors, {
                message = "instrument_id " .. change.instrument_id .. " not found in registry",
                path = change.path
            })
        elseif instrument_data.name ~= change.instrument_name then
            table.insert(errors, {
                message = "instrument_name mismatch for instrument_id " .. change.instrument_id ..
                        ": expected '" .. instrument_data.name .. "', got '" .. change.instrument_name .. "'",
                path = change.path
            })
        else
            local phrase_data = self.registry:get_phrase_by_id(change.instrument_id, change.phrase_id)
            if not phrase_data then
                table.insert(errors, {
                    message = "phrase_id " .. change.phrase_id .. " not found for instrument_id " .. change.instrument_id,
                    path = change.path
                })
            elseif phrase_data.name ~= change.phrase_name then
                table.insert(errors, {
                    message = "phrase_name mismatch for phrase_id " .. change.phrase_id ..
                            " in instrument_id " .. change.instrument_id ..
                            ": expected '" .. phrase_data.name .. "', got '" .. change.phrase_name .. "'",
                    path = change.path
                })
            else
                table.insert(validated_changes, {
                    instrument_index = instrument_data.current_index,
                    phrase_index = phrase_data.current_index,
                    phrase_name = change.phrase_name,
                    script_body = change.script_body
                })
            end
        end
    end

    return validated_changes, errors
end

return M