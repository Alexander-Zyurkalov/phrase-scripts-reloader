local rust_backend = require("rust_backend")

--- @class InstrumentData
--- @field current_index number The current index of the instrument (may change due to insertions/deletions)
--- @field name string The current name of the instrument

--- @class PhraseData
--- @field current_index number The current index of the phrase (may change due to insertions/deletions)
--- @field name string The current name of the phrase
--- @field is_script_registered boolean Whether the script is currently registered with the backend

--- @class State
--- @field instrument_map table<number, InstrumentData> Hash map to track instruments by unique ID
--- @field phrase_map table<number, table<number, PhraseData>> Hash map to track phrases by unique ID, grouped by instrument ID
--- @field next_instrument_id number Counter for generating unique instrument IDs
--- @field next_phrase_id table<number, number> Counters for generating unique phrase IDs per instrument

--- Updates all instrument indexes after an insertion or removal
--- @param state State The shared state
--- @param from_index number The index from which to start updating
--- @param delta number The change in index (+1 for insert, -1 for remove)
local function update_instrument_indexes(state, from_index, delta)
    for _, data in pairs(state.instrument_map) do
        if data.current_index >= from_index then
            data.current_index = data.current_index + delta
        end
    end
end

--- Updates all phrase indexes for a given instrument after an insertion or removal
--- @param state State The shared state
--- @param instrument_id number The unique instrument ID
--- @param from_index number The phrase index from which to start updating
--- @param delta number The change in index (+1 for insert, -1 for remove)
local function update_phrase_indexes(state, instrument_id, from_index, delta)
    if not state.phrase_map[instrument_id] then
        return
    end
    for _, data in pairs(state.phrase_map[instrument_id]) do
        if data.current_index >= from_index then
            data.current_index = data.current_index + delta
        end
    end
end

--- @param state State The shared state
--- @param instrument renoise.Instrument
--- @param instrument_index number The current index of the instrument
local function attach_instrument_elements_observers(state, instrument, instrument_index)
    local instrument_id = state.next_instrument_id
    state.next_instrument_id = state.next_instrument_id + 1

    state.instrument_map[instrument_id] = {
        current_index = instrument_index,
        name = instrument.name
    }

    state.phrase_map[instrument_id] = {}
    state.next_phrase_id[instrument_id] = 1

    local on_instrument_renamed = function()
        local old_name = state.instrument_map[instrument_id].name
        renoise.app():show_status("PhraseScriptsReloader: renaming instrument folder from '" .. old_name .. "' to '" .. instrument.name .. "'")
        rust_backend.rename_instrument(
                renoise.song().file_name,
                instrument_id,
                old_name,
                instrument.name
        )
        state.instrument_map[instrument_id].name = instrument.name
    end

    instrument.name_observable:add_notifier(on_instrument_renamed)

    ---@param notification {type: string, index: number}
    local on_phrase_added_or_loaded = function(notification)
        if notification.type == "insert" then
            local phrase_index = notification.index
            if phrase_index == nil or phrase_index > #instrument.phrases then
                return
            end

            update_phrase_indexes(state, instrument_id, phrase_index, 1)

            local phrase = instrument.phrases[phrase_index]

            local phrase_id = state.next_phrase_id[instrument_id]
            state.next_phrase_id[instrument_id] = state.next_phrase_id[instrument_id] + 1

            state.phrase_map[instrument_id][phrase_id] = {
                current_index = phrase_index,
                name = phrase.name,
                is_script_registered = false
            }

            local on_playback_mode_changed = function()
                local phrase_data = state.phrase_map[instrument_id][phrase_id]
                if phrase.playback_mode == renoise.InstrumentPhrase.PLAY_SCRIPT then
                    renoise.app():show_status("PhraseScriptsReloader: registering new script file for phrase '" ..
                            phrase_data.name .. "'")
                    local script_text = table.concat(phrase.script.paragraphs, "\n")
                    rust_backend.register_new_script(
                            renoise.song().file_name,
                            instrument_id,
                            phrase_id,
                            phrase_data.name,
                            script_text
                    )
                    phrase_data.is_script_registered = true
                elseif phrase_data.is_script_registered then
                    renoise.app():show_status("PhraseScriptsReloader: removing script file for phrase '" ..
                            phrase_data.name .. "'")
                    rust_backend.remove_script(
                            renoise.song().file_name,
                            instrument_id,
                            phrase_id
                    )
                    phrase_data.is_script_registered = false
                end
            end

            local on_phrase_renamed = function()
                local phrase_data = state.phrase_map[instrument_id][phrase_id]
                if phrase.playback_mode == renoise.InstrumentPhrase.PLAY_SCRIPT then
                    renoise.app():show_status("PhraseScriptsReloader: renaming script file from '" .. phrase_data.name .. "' to '" .. phrase.name .. "'")
                    rust_backend.rename_script(
                            renoise.song().file_name,
                            instrument_id,
                            phrase_id,
                            phrase_data.name,
                            phrase.name
                    )
                end
                phrase_data.name = phrase.name
            end

            on_playback_mode_changed()
            phrase.playback_mode_observable:add_notifier(on_playback_mode_changed)
            phrase.name_observable:add_notifier(on_phrase_renamed)

        elseif notification.type == "remove" then
            local removed_index = notification.index
            for id, data in pairs(state.phrase_map[instrument_id]) do
                if data.current_index == removed_index then
                    if data.is_script_registered then
                        renoise.app():show_status("PhraseScriptsReloader: removing script file for phrase '" ..
                                data.name .. "'")
                        rust_backend.remove_script(
                                renoise.song().file_name,
                                instrument_id,
                                id
                        )
                    end
                    state.phrase_map[instrument_id][id] = nil
                    break
                end
            end
            update_phrase_indexes(state, instrument_id, removed_index + 1, -1)

        elseif notification.type == "swap" then
            local index1 = notification.index
            local index2 = notification.index2 or (notification.index + 1)
            local entry1, entry2
            for _, data in pairs(state.phrase_map[instrument_id]) do
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
    end

    instrument.phrases_observable:add_notifier(on_phrase_added_or_loaded)

    for i, _ in ipairs(instrument.phrases) do
        on_phrase_added_or_loaded({
            type = "insert",
            index = i
        })
    end
end

--- @param state State The shared state
--- @param notification {type: string, index: number, index2: number|nil}
local function on_instruments_changed(state, notification)
    if notification.type == "insert" then
        renoise.app():show_status("PhraseScriptsReloader: new instrument added at index " .. notification.index)
        update_instrument_indexes(state, notification.index, 1)

        local new_instrument = renoise.song().instruments[notification.index]
        attach_instrument_elements_observers(state, new_instrument, notification.index)

    elseif notification.type == "remove" then
        local removed_index = notification.index
        for id, data in pairs(state.instrument_map) do
            if data.current_index == removed_index then
                renoise.app():show_status("PhraseScriptsReloader: removing instrument folder '" .. data.name .. "'")
                rust_backend.remove_instrument(
                        renoise.song().file_name,
                        id
                )
                state.instrument_map[id] = nil
                state.phrase_map[id] = nil
                state.next_phrase_id[id] = nil
                break
            end
        end
        update_instrument_indexes(state, removed_index + 1, -1)

    elseif notification.type == "swap" then
        local index1 = notification.index
        local index2 = notification.index2 or (notification.index + 1)
        local entry1, entry2
        for _, data in pairs(state.instrument_map) do
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
end

local function on_new_document()
    renoise.app():show_status("PhraseScriptsReloader: initializing observers for new document")

    --- @type State
    local state = {
        instrument_map = {},
        phrase_map = {},
        next_instrument_id = 1,
        next_phrase_id = {}
    }

    renoise.song().instruments_observable:add_notifier(function(notification)
        on_instruments_changed(state, notification)
    end)

    local instruments = renoise.song().instruments
    for i = 1, #instruments do
        attach_instrument_elements_observers(state, instruments[i], i)
    end
end

---@param str string
---@return string[]
local function split_lines(str)
    local lines = {}
    for line in str:gmatch("([^\n]*)\n?") do
        lines[#lines + 1] = line
    end
    if #lines > 0 and lines[#lines] == "" then
        lines[#lines] = nil
    end
    return lines
end

local function request_changes()
    local changes = rust_backend.request_changes(renoise.song().file_name)
    if #changes > 0 then
        renoise.app():show_status("PhraseScriptsReloader: reloading phrase scripts from files...")
    end
    for _, change in ipairs(changes) do
        local instrument_name = change.instrument_name
        local phrase_name = change.phrase_name
        local script_body = change.script_body

        local instruments = renoise.song().instruments
        for _, instrument in ipairs(instruments) do
            if instrument.name == instrument_name then
                local phrases = instrument.phrases
                for _, phrase in ipairs(phrases) do
                    if phrase.name == phrase_name and
                            phrase.playback_mode == renoise.InstrumentPhrase.PLAY_SCRIPT then
                        local script_paragraph = split_lines(script_body)
                        phrase.script.paragraphs = script_paragraph
                        renoise.app():show_status("PhraseScriptsReloader: phrase script reloaded from file: " ..
                                phrase_name)
                    end
                end
            end
        end
    end
end

renoise.tool().app_new_document_observable:add_notifier(on_new_document)
renoise.tool():add_timer(request_changes, 1000)