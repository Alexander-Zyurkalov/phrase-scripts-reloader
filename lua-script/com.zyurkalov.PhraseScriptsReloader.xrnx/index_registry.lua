--- @class InstrumentData
--- @field current_index number The current index of the instrument (may change due to insertions/deletions)
--- @field name string The current name of the instrument

--- @class PhraseData
--- @field current_index number The current index of the phrase (may change due to insertions/deletions)
--- @field name string The current name of the phrase
--- @field is_script_registered boolean Whether the script is currently registered with the backend

--- @class IndexRegistry
--- @field instrument_map table<number, InstrumentData> Hash map to track instruments by unique ID
--- @field phrase_map table<number, table<number, PhraseData>> Hash map to track phrases by unique ID, grouped by instrument ID
--- @field next_instrument_id number Counter for generating unique instrument IDs
--- @field next_phrase_id table<number, number> Counters for generating unique phrase IDs per instrument
--- @field recently_swapped_instruments table
--- @field new fun(): IndexRegistry
--- @field print_instrument_map fun(self: IndexRegistry)
--- @field get_instrument_count fun(self: IndexRegistry): number
--- @field swap_instrument_indexes fun(self: IndexRegistry, index1: number, index2: number)
--- @field swap_phrase_indexes fun(self: IndexRegistry, instrument_id: number, index1: number, index2: number)
--- @field register_instrument fun(self: IndexRegistry, instrument_index: number, instrument_name: string): number
--- @field remove_instrument fun(self: IndexRegistry, instrument_id: number)
--- @field register_phrase fun(self: IndexRegistry, instrument_id: number, phrase_index: number, phrase_name: string): number
--- @field remove_phrase fun(self: IndexRegistry, instrument_id: number, phrase_id: number)
--- @field get_instrument_by_id fun(self: IndexRegistry, instrument_id: number): InstrumentData|nil
--- @field get_phrase_by_id fun(self: IndexRegistry, instrument_id: number, phrase_id: number): PhraseData|nil
--- @field find_instrument_by_index fun(self: IndexRegistry, current_index: number): number|nil, InstrumentData|nil
--- @field find_phrase_by_index fun(self: IndexRegistry, instrument_id: number, current_index: number): number|nil, PhraseData|nil

local IndexRegistry = {}
IndexRegistry.__index = IndexRegistry

--- Creates a new IndexRegistry instance
--- @return IndexRegistry
function IndexRegistry.new()
    local self = setmetatable({}, IndexRegistry)
    self.instrument_map = {}
    self.phrase_map = {}
    self.next_instrument_id = 1
    self.next_phrase_id = {}
    self.recently_swapped_instruments = {}
    return self
end

--- Prints the instrument_map structure for debugging
function IndexRegistry:print_instrument_map()
    -- Sort by current_index for consistent output
    local sorted_ids = {}
    for id in pairs(self.instrument_map) do
        table.insert(sorted_ids, id)
    end
    table.sort(sorted_ids, function(a, b)
        return self.instrument_map[a].current_index < self.instrument_map[b].current_index
    end)

    for _, id in ipairs(sorted_ids) do
        local data = self.instrument_map[id]
    end
end

--- Returns the number of registered instruments
--- @return number count The number of registered instruments
function IndexRegistry:get_instrument_count()
    local seen = {}
    local count = 0
    for _, v in pairs(self.instrument_map) do
        if not seen[v.current_index] then
            seen[v.current_index] = true
            count = count + 1
        end
    end
    return count
end

--- Returns the number of registered phrases for a given instrument
--- @param instrument_id number The unique instrument ID
--- @return number count The number of registered phrases
function IndexRegistry:get_phrase_count(instrument_id)
    local seen = {}
    local count = 0
    if self.phrase_map[instrument_id] == nil then
        return 0
    end
    for _, v in pairs(self.phrase_map[instrument_id]) do
        if not seen[v.current_index] then
            seen[v.current_index] = true
            count = count + 1
        end
    end
    return count
end

--- Updates all instrument indexes after an insertion or removal
--- @param from_index number The index from which to start updating
--- @param delta number The change in index (+1 for insert, -1 for remove)
function IndexRegistry:_update_instrument_indexes(from_index, delta)
    for _, data in pairs(self.instrument_map) do
        if data.current_index >= from_index then
            data.current_index = data.current_index + delta
        end
    end
end

--- Updates all phrase indexes for a given instrument after an insertion or removal
--- @param instrument_id number The unique instrument ID
--- @param from_index number The phrase index from which to start updating
--- @param delta number The change in index (+1 for insert, -1 for remove)
function IndexRegistry:_update_phrase_indexes(instrument_id, from_index, delta)
    if not self.phrase_map then
        return
    end
    if not self.phrase_map[instrument_id] then
        return
    end
    for _, data in pairs(self.phrase_map[instrument_id]) do
        if data.current_index >= from_index then
            data.current_index = data.current_index + delta
        end
    end
end

--- Swaps the current_index values of two entries in a map
--- @param map table<number, {current_index: number}>
--- @param index1 number
--- @param index2 number
local function swap_indexes_in_map(map, index1, index2)
    local entry1, entry2
    for _, data in pairs(map) do
        if data.current_index == index1 then
            entry1 = data
        elseif data.current_index == index2 then
            entry2 = data
        end
    end
    if entry1 and entry2 then
        entry1.current_index, entry2.current_index = entry2.current_index, entry1.current_index
    end
end

--- Swaps the current_index values of two instruments
--- @param index1 number
--- @param index2 number
function IndexRegistry:swap_instrument_indexes(index1, index2)
    swap_indexes_in_map(self.instrument_map, index1, index2)
end

--- Swaps the current_index values of two phrases within an instrument
--- @param instrument_id number The unique instrument ID
--- @param index1 number
--- @param index2 number
function IndexRegistry:swap_phrase_indexes(instrument_id, index1, index2)
    if self.phrase_map[instrument_id] then
        swap_indexes_in_map(self.phrase_map[instrument_id], index1, index2)
    end
end

--- Registers a new instrument
--- @param instrument_index number The current index of the instrument
--- @param instrument_name string The name of the instrument
--- @return number instrument_id The unique ID assigned to the instrument
function IndexRegistry:register_instrument(instrument_index, instrument_name)
    local instrument_id = self.next_instrument_id
    self.next_instrument_id = self.next_instrument_id + 1
    if instrument_index <= self:get_instrument_count() then
        self:_update_instrument_indexes(instrument_index, 1)
    end

    self.instrument_map[instrument_id] = {
        current_index = instrument_index,
        name = instrument_name or ""
    }

    self.phrase_map[instrument_id] = {}
    self.next_phrase_id[instrument_id] = 1

    return instrument_id
end

--- Removes an instrument
--- @param instrument_id number The unique instrument ID
function IndexRegistry:remove_instrument(instrument_id)
    local instrument_data = self.instrument_map[instrument_id]
    local instrument_index = instrument_data and instrument_data.current_index
    self.instrument_map[instrument_id] = nil
    self.phrase_map[instrument_id] = nil
    self.next_phrase_id[instrument_id] = nil
    if instrument_index and instrument_index <= self:get_instrument_count() then
        self:_update_instrument_indexes(instrument_index, -1)
    end
end

--- Registers a new phrase
--- @param instrument_id number The unique instrument ID
--- @param phrase_index number The current index of the phrase
--- @param phrase_name string The name of the phrase
--- @return number phrase_id The unique ID assigned to the phrase
function IndexRegistry:register_phrase(instrument_id, phrase_index, phrase_name)
    local phrase_id = self.next_phrase_id[instrument_id]
    if phrase_id == nil then
        return nil
    end
    self.next_phrase_id[instrument_id] = self.next_phrase_id[instrument_id] + 1
    if phrase_index <= self:get_phrase_count(instrument_id) then
        self:_update_phrase_indexes(instrument_id, phrase_index, 1)
    end

    self.phrase_map[instrument_id][phrase_id] = {
        current_index = phrase_index,
        name = phrase_name,
        is_script_registered = false
    }

    return phrase_id
end

--- Removes a phrase
--- @param instrument_id number The unique instrument ID
--- @param phrase_id number The unique phrase ID
function IndexRegistry:remove_phrase(instrument_id, phrase_id)
    if self.phrase_map[instrument_id] then
        local phrase_data = self.phrase_map[instrument_id]
        local phrase_index = phrase_data[phrase_id] and phrase_data[phrase_id].current_index
        self.phrase_map[instrument_id][phrase_id] = nil
        if phrase_index and phrase_index <= self:get_phrase_count(instrument_id) then
            self:_update_phrase_indexes(instrument_id, phrase_index, -1)
        end
    end
end

--- Gets instrument data by its unique ID
--- @param instrument_id number The unique instrument ID
--- @return InstrumentData|nil
function IndexRegistry:get_instrument_by_id(instrument_id)
    return self.instrument_map[instrument_id]
end

--- Gets phrase data by its unique ID
--- @param instrument_id number The unique instrument ID
--- @param phrase_id number The unique phrase ID
--- @return PhraseData|nil
function IndexRegistry:get_phrase_by_id(instrument_id, phrase_id)
    if self.phrase_map[instrument_id] then
        return self.phrase_map[instrument_id][phrase_id]
    end
    return nil
end

--- Finds instrument ID and data by current index
--- @param current_index number The current index to search for
--- @return number|nil instrument_id, InstrumentData|nil data
function IndexRegistry:find_instrument_by_index(current_index)
    for id, data in pairs(self.instrument_map) do
        if data.current_index == current_index then
            return id, data
        end
    end
    return nil, nil
end

--- Finds phrase ID and data by current index within an instrument
--- @param instrument_id number The unique instrument ID
--- @param current_index number The current index to search for
--- @return number|nil phrase_id, PhraseData|nil data
function IndexRegistry:find_phrase_by_index(instrument_id, current_index)
    if not self.phrase_map[instrument_id] then
        return nil, nil
    end
    for id, data in pairs(self.phrase_map[instrument_id]) do
        if data.current_index == current_index then
            return id, data
        end
    end
    return nil, nil
end

return IndexRegistry