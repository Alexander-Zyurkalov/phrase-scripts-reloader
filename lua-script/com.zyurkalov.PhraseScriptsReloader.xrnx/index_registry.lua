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
--- @field recently_swapped_instruments table<number, boolean> Workaround for Renoise bug: indexes involved in recent swap

local M = {}

--- Creates a new state instance
--- @return IndexRegistry
function M.new()
    return {
        instrument_map = {},
        phrase_map = {},
        next_instrument_id = 1,
        next_phrase_id = {},
        recently_swapped_instruments = {}
    }
end

--- Prints the instrument_map structure for debugging
--- @param registry IndexRegistry The shared state
function M.print_instrument_map(registry)
    -- Sort by current_index for consistent output
    local sorted_ids = {}
    for id in pairs(registry.instrument_map) do
        table.insert(sorted_ids, id)
    end
    table.sort(sorted_ids, function(a, b)
        return registry.instrument_map[a].current_index < registry.instrument_map[b].current_index
    end)

    for _, id in ipairs(sorted_ids) do
        local data = registry.instrument_map[id]
    end
end

--- Returns the number of registered instruments
--- @param registry IndexRegistry The shared state
--- @return number count The number of registered instruments
function M.get_instrument_count(registry)
    local seen = {}
    local count = 0
    for _, v in pairs(registry.instrument_map) do
        if not seen[v.current_index] then
            seen[v.current_index] = true
            count = count + 1
        end
    end
    return count
end

--- Updates all instrument indexes after an insertion or removal
--- @param registry IndexRegistry The shared state
--- @param from_index number The index from which to start updating
--- @param delta number The change in index (+1 for insert, -1 for remove)
local function update_instrument_indexes(registry, from_index, delta)
    for _, data in pairs(registry.instrument_map) do
        if data.current_index >= from_index then
            data.current_index = data.current_index + delta
        end
    end
end
--- Updates all phrase indexes for a given instrument after an insertion or removal
--- @param registry IndexRegistry The shared state
--- @param instrument_id number The unique instrument ID
--- @param from_index number The phrase index from which to start updating
--- @param delta number The change in index (+1 for insert, -1 for remove)
local function update_phrase_indexes(registry, instrument_id, from_index, delta)
    if (not registry.phrase_map) then
        return
    end
    if not registry.phrase_map[instrument_id] then
        return
    end
    for _, data in pairs(registry.phrase_map[instrument_id]) do
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
--- @param registry IndexRegistry The shared state
--- @param index1 number
--- @param index2 number
function M.swap_instrument_indexes(registry, index1, index2)
    swap_indexes_in_map(registry.instrument_map, index1, index2)
end

--- Swaps the current_index values of two phrases within an instrument
--- @param registry IndexRegistry The shared state
--- @param instrument_id number The unique instrument ID
--- @param index1 number
--- @param index2 number
function M.swap_phrase_indexes(registry, instrument_id, index1, index2)
    if registry.phrase_map[instrument_id] then
        swap_indexes_in_map(registry.phrase_map[instrument_id], index1, index2)
    end
end

--- Registers a new instrument in the state
--- @param registry IndexRegistry The shared state
--- @param instrument_index number The current index of the instrument
--- @param instrument_name string The name of the instrument
--- @return number instrument_id The unique ID assigned to the instrument
function M.register_instrument(registry, instrument_index, instrument_name)
    local instrument_id = registry.next_instrument_id
    registry.next_instrument_id = registry.next_instrument_id + 1
    if instrument_index <= M.get_instrument_count(registry) then
        update_instrument_indexes(registry, instrument_index, 1)
    end

    registry.instrument_map[instrument_id] = {
        current_index = instrument_index,
        name = instrument_name or ""
    }

    registry.phrase_map[instrument_id] = {}
    registry.next_phrase_id[instrument_id] = 1

    return instrument_id
end

--- Removes an instrument from the state
--- @param registry IndexRegistry The shared state
--- @param instrument_id number The unique instrument ID
function M.remove_instrument(registry, instrument_id)
    local instrument_data = registry.instrument_map[instrument_id]
    local instrument_index = instrument_data and instrument_data.current_index
    registry.instrument_map[instrument_id] = nil
    registry.phrase_map[instrument_id] = nil
    registry.next_phrase_id[instrument_id] = nil
    if instrument_index and instrument_index <= M.get_instrument_count(registry) then
        update_instrument_indexes(registry, instrument_index, -1)
    end
end

--- Registers a new phrase in the state
--- @param registry IndexRegistry The shared state
--- @param instrument_id number The unique instrument ID
--- @param phrase_index number The current index of the phrase
--- @param phrase_name string The name of the phrase
--- @return number phrase_id The unique ID assigned to the phrase
function M.register_phrase(registry, instrument_id, phrase_index, phrase_name)
    update_phrase_indexes(registry, instrument_id, phrase_index, 1)
    local phrase_id = registry.next_phrase_id[instrument_id]
    registry.next_phrase_id[instrument_id] = registry.next_phrase_id[instrument_id] + 1

    registry.phrase_map[instrument_id][phrase_id] = {
        current_index = phrase_index,
        name = phrase_name,
        is_script_registered = false
    }

    return phrase_id
end

--- Removes a phrase from the state
--- @param registry IndexRegistry The shared state
--- @param instrument_id number The unique instrument ID
--- @param phrase_id number The unique phrase ID
function M.remove_phrase(registry, instrument_id, phrase_id)
    if registry.phrase_map[instrument_id] then
        registry.phrase_map[instrument_id][phrase_id] = nil
        update_phrase_indexes(registry, instrument_id, phrase_id, -1)
    end
end

--- Gets instrument data by its unique ID
--- @param registry IndexRegistry The shared state
--- @param instrument_id number The unique instrument ID
--- @return InstrumentData|nil
function M.get_instrument_by_id(registry, instrument_id)
    return registry.instrument_map[instrument_id]
end

--- Gets phrase data by its unique ID
--- @param registry IndexRegistry The shared state
--- @param instrument_id number The unique instrument ID
--- @param phrase_id number The unique phrase ID
--- @return PhraseData|nil
function M.get_phrase_by_id(registry, instrument_id, phrase_id)
    if registry.phrase_map[instrument_id] then
        return registry.phrase_map[instrument_id][phrase_id]
    end
    return nil
end

--- Finds instrument ID and data by current index
--- @param registry IndexRegistry The shared state
--- @param current_index number The current index to search for
--- @return number|nil instrument_id, InstrumentData|nil data
function M.find_instrument_by_index(registry, current_index)
    for id, data in pairs(registry.instrument_map) do
        if data.current_index == current_index then
            return id, data
        end
    end
    return nil, nil
end

--- Finds phrase ID and data by current index within an instrument
--- @param registry IndexRegistry The shared state
--- @param instrument_id number The unique instrument ID
--- @param current_index number The current index to search for
--- @return number|nil phrase_id, PhraseData|nil data
function M.find_phrase_by_index(registry, instrument_id, current_index)
    if not registry.phrase_map[instrument_id] then
        return nil, nil
    end
    for id, data in pairs(registry.phrase_map[instrument_id]) do
        if data.current_index == current_index then
            return id, data
        end
    end
    return nil, nil
end

--- Checks if an index was recently swapped and clears the tracking if so
--- @param registry IndexRegistry The shared state
--- @param index number The index to check
--- @return boolean was_recently_swapped
function M.check_and_clear_recently_swapped(registry, index)
    if registry.recently_swapped_instruments[index] then
        registry.recently_swapped_instruments = {}
        return true
    end
    return false
end

return M