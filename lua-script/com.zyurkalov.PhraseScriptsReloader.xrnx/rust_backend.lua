--- @class RustBackend
--- @field path string
--- @field new fun(path: string): RustBackend
--- @field update_path fun(self: RustBackend, path: string)
--- @field register_script fun(self: RustBackend, instrument_index: number, instrument_name: string, phrase_index: number, phrase_name: string, script_body: string)
--- @field rename_script fun(self: RustBackend, instrument_index: number, phrase_index: number, old_name: string, new_name: string)
--- @field unregister_script fun(self: RustBackend, instrument_index: number, phrase_index: number)
--- @field rename_instrument fun(self: RustBackend, instrument_index: number, old_instrument_name: string, new_instrument_name: string)
--- @field remove_instrument fun(self: RustBackend, instrument_index: number)
--- @field set_new_instrument_indexes fun(self: RustBackend, instrument_indexes: number[])
--- @field set_new_phrase_indexes fun(self: RustBackend, instrument_index: number, phrase_indexes: number[])
--- @field take_changes fun(self: RustBackend): {path: string, instrument_index: number, phrase_index: number, phrase_name: string, script_body: string}[]
local RustBackend = {}
RustBackend.__index = RustBackend

---@param path string
---@return RustBackend
function RustBackend.new(path)
    local self = setmetatable({}, RustBackend)
    self.path = path
    return self
end

---@param path string
function RustBackend:update_path(path)
    print("Old path = " .. self.path)
    print("New path = " .. path)
    self.path = path
end

---@param instrument_index number
---@param instrument_name string
---@param phrase_index number
---@param phrase_name string
---@param script_body string
function RustBackend:register_script(instrument_index, instrument_name, phrase_index, phrase_name, script_body)
    print("RustBackend:register_script - instrument_index=" .. instrument_index .. ", instrument_name=" .. instrument_name ..
            ", phrase_index=" .. phrase_index .. ", phrase_name=" .. phrase_name .. ", script_body_length=" .. #script_body)
end

---@param instrument_index number
---@param phrase_index number
---@param old_name string
---@param new_name string
function RustBackend:rename_script(instrument_index, phrase_index, old_name, new_name)
    print("RustBackend:rename_script - instrument_index=" .. instrument_index .. ", phrase_index=" .. phrase_index ..
            ", old_name=" .. old_name .. ", new_name=" .. new_name)
end

---@param instrument_index number
---@param phrase_index number
function RustBackend:unregister_script(instrument_index, phrase_index)
    print("RustBackend:unregister_script - instrument_index=" .. instrument_index .. ", phrase_index=" .. phrase_index)
end

---@param instrument_index number
---@param old_instrument_name string
---@param new_instrument_name string
function RustBackend:rename_instrument(instrument_index, old_instrument_name, new_instrument_name)
    print("RustBackend:rename_instrument - instrument_index=" .. instrument_index .. ", old_name=" .. old_instrument_name ..
            ", new_name=" .. new_instrument_name)
end

---@param instrument_index number
function RustBackend:remove_instrument(instrument_index)
    print("RustBackend:remove_instrument - instrument_index=" .. instrument_index)
end

---@param instrument_indexes number[] A list of instrument indexes that were swapped
function RustBackend:set_new_instrument_indexes(instrument_indexes)
    print("RustBackend:set_new_instrument_indexes - indexes=" .. table.concat(instrument_indexes, ", "))
end

---@param instrument_index number
---@param phrase_indexes number[] A list of phrase indexes that were swapped
function RustBackend:set_new_phrase_indexes(instrument_index, phrase_indexes)
    print("RustBackend:set_new_phrase_indexes - instrument_index=" .. instrument_index ..
            ", phrase_indexes=" .. table.concat(phrase_indexes, ", "))
end

---@return {path: string, instrument_index: number, phrase_index: number, phrase_name: string, script_body: string}[]
function RustBackend:take_changes()
    return {}
end

return RustBackend