--- @class RustBackend
--- @field song_path string
--- @field new fun(song_path: string): RustBackend
--- @field update_song_path fun(self: RustBackend, song_path: string)
--- @field register_script fun(self: RustBackend, instrument_id: number, instrument_name: string, phrase_id: number, phrase_name: string, script_body: string)
--- @field rename_script fun(self: RustBackend, instrument_id: number, phrase_id: number, new_name: string)
--- @field unregister_script fun(self: RustBackend, instrument_id: number, phrase_id: number)
--- @field rename_instrument fun(self: RustBackend, instrument_id: number, new_instrument_name: string)
--- @field unregister_instrument fun(self: RustBackend, instrument_id: number)
--- @field set_new_instrument_indexes fun(self: RustBackend, id_index_pairs: table[])
--- @field set_new_phrase_indexes fun(self: RustBackend, instrument_id: number, id_index_pairs: table[])
--- @field take_changes fun(self: RustBackend): {instrument_id: number, instrument_name: string, phrase_id: number, phrase_name: string, script_body: string}[]
local RustBackend = {}
RustBackend.__index = RustBackend

---@param song_path string
---@return RustBackend
function RustBackend.new(song_path)
    local self = setmetatable({}, RustBackend)
    self.song_path = song_path
    return self
end

---@param song_path string
function RustBackend:update_song_path(song_path)
    print("Old path = " .. self.song_path)
    print("New path = " .. song_path)
    self.song_path = song_path
end

---@param instrument_id number
---@param instrument_name string
---@param phrase_id number
---@param phrase_name string
---@param script_body string
function RustBackend:register_script(instrument_id, instrument_name, phrase_id, phrase_name, script_body)
    print("RustBackend:register_script - instrument_id=" .. instrument_id .. ", instrument_name=" .. instrument_name ..
            ", phrase_id=" .. phrase_id .. ", phrase_name=" .. phrase_name .. ", script_body_length=" .. #script_body)
end

---@param instrument_id number
---@param phrase_id number
---@param new_name string
function RustBackend:rename_script(instrument_id, phrase_id, new_name)
    print("RustBackend:rename_script - instrument_id=" .. instrument_id .. ", phrase_id=" .. phrase_id ..
            ", new_name=" .. new_name)
end

---@param instrument_id number
---@param phrase_id number
function RustBackend:unregister_script(instrument_id, phrase_id)
    print("RustBackend:unregister_script - instrument_id=" .. instrument_id .. ", phrase_id=" .. phrase_id)
end

---@param instrument_id number
---@param new_instrument_name string
function RustBackend:rename_instrument(instrument_id, new_instrument_name)
    print("RustBackend:rename_instrument - instrument_id=" .. instrument_id ..
            ", new_name=" .. new_instrument_name)
end

---@param instrument_id number
function RustBackend:unregister_instrument(instrument_id)
    print("RustBackend:unregister_instrument - instrument_id=" .. instrument_id)
end

---@param id_index_pairs table[] A list of {id, index} pairs for instruments
function RustBackend:set_new_instrument_indexes(id_index_pairs)
    local pairs_str = {}
    for _, pair in ipairs(id_index_pairs) do
        table.insert(pairs_str, "{" .. pair[1] .. ", " .. pair[2] .. "}")
    end
    print("RustBackend:set_new_instrument_indexes - pairs=" .. table.concat(pairs_str, ", "))
end

---@param instrument_id number The instrument ID
---@param id_index_pairs table[] A list of {id, index} pairs for phrases
function RustBackend:set_new_phrase_indexes(instrument_id, id_index_pairs)
    local pairs_str = {}
    for _, pair in ipairs(id_index_pairs) do
        table.insert(pairs_str, "{" .. pair[1] .. ", " .. pair[2] .. "}")
    end
    print("RustBackend:set_new_phrase_indexes - instrument_id=" .. instrument_id ..
            ", pairs=" .. table.concat(pairs_str, ", "))
end

---@return {instrument_id: number, instrument_name: string, phrase_id: number, phrase_name: string, script_body: string}[]
function RustBackend:take_changes()
    return {}
end

return RustBackend