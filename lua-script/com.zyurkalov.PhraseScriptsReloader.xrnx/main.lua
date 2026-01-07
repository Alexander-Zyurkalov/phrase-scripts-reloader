local rust_backend = require("rust_backend")
local index_registry_module = require("index_registry")
local main_module = require("main_module")

--- @param registry IndexRegistry The shared index registry
--- @param instrument renoise.Instrument
--- @param instrument_index number The current index of the instrument
local function attach_instrument_elements_observers(registry, instrument, instrument_index)
    local instrument_id = index_registry_module.register_instrument(registry, instrument_index, instrument.name)

    local on_instrument_renamed = function()
        local instrument_data = index_registry_module.get_instrument_by_id(registry, instrument_id)
        renoise.app():show_status("PhraseScriptsReloader: renaming instrument folder from '" .. instrument_data.name ..
                "' to '" .. instrument.name .. "'")
        rust_backend.rename_instrument(
                renoise.song().file_name,
                instrument_data.current_index,
                instrument_data.name,
                instrument.name
        )
        instrument_data.name = instrument.name
    end

    instrument.name_observable:add_notifier(on_instrument_renamed)

    ---@param notification {type: string, index: number}
    local on_phrase_changed = function(notification)
        if notification.type == "insert" then
            local phrase_index = notification.index
            if phrase_index == nil or phrase_index > #instrument.phrases then
                return
            end

            local phrase = instrument.phrases[phrase_index]
            local phrase_id = index_registry_module.register_phrase(registry, instrument_id, phrase_index, phrase.name)

            local on_playback_mode_changed = function()
                local instrument_data = index_registry_module.get_instrument_by_id(registry, instrument_id)
                local phrase_data = index_registry_module.get_phrase_by_id(registry, instrument_id, phrase_id)
                if phrase.playback_mode == renoise.InstrumentPhrase.PLAY_SCRIPT then
                    renoise.app():show_status("PhraseScriptsReloader: registering new script file for phrase '" ..
                            phrase_data.name .. "'")
                    local script_text = table.concat(phrase.script.paragraphs, "\n")
                    rust_backend.register_script(
                            renoise.song().file_name,
                            instrument_data.current_index,
                            instrument.name,
                            phrase_data.current_index,
                            phrase_data.name,
                            script_text
                    )
                    phrase_data.is_script_registered = true
                elseif phrase_data.is_script_registered then
                    renoise.app():show_status("PhraseScriptsReloader: removing script file for phrase '" ..
                            phrase_data.name .. "'")
                    rust_backend.remove_script(
                            renoise.song().file_name,
                            instrument_data.current_index,
                            phrase_data.current_index
                    )
                    phrase_data.is_script_registered = false
                end
            end

            local on_phrase_renamed = function()
                local instrument_data = index_registry_module.get_instrument_by_id(registry, instrument_id)
                local phrase_data = index_registry_module.get_phrase_by_id(registry, instrument_id, phrase_id)
                if phrase.playback_mode == renoise.InstrumentPhrase.PLAY_SCRIPT then
                    renoise.app():show_status("PhraseScriptsReloader: renaming script file from '" ..
                            phrase_data.name .. "' to '" .. phrase.name .. "'")
                    rust_backend.rename_script(
                            renoise.song().file_name,
                            instrument_data.current_index,
                            phrase_data.current_index,
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
            local phrase_id, phrase_data = index_registry_module.find_phrase_by_index(registry, instrument_id, removed_index)
            if phrase_data then
                if phrase_data.is_script_registered then
                    local instrument_data = index_registry_module.get_instrument_by_id(registry, instrument_id)
                    renoise.app():show_status("PhraseScriptsReloader: removing script file for phrase '" ..
                            phrase_data.name .. "'")
                    rust_backend.remove_script(
                            renoise.song().file_name,
                            instrument_data.current_index,
                            phrase_data.current_index
                    )
                end
                index_registry_module.remove_phrase(registry, instrument_id, phrase_id)
            end

        elseif notification.type == "swap" then
            local instrument_data = index_registry_module.get_instrument_by_id(registry, instrument_id)
            rust_backend.swap_phrases(
                    renoise.song().file_name,
                    instrument_data.current_index,
                    notification.index1,
                    notification.index2
            )
            index_registry_module.swap_phrase_indexes(registry, instrument_id, notification.index1, notification.index2)
        else
            print("PhraseScriptsReloader: unhandled phrase notification type: " .. tostring(notification.type))
        end
    end

    instrument.phrases_observable:add_notifier(on_phrase_changed)

    for i, _ in ipairs(instrument.phrases) do
        on_phrase_changed({
            type = "insert",
            index = i
        })
    end
end

--- @param registry IndexRegistry The shared index registry
--- @param notification {type: string, index1: number, index2: number|nil}
local function on_instruments_changed(registry, notification)
    if notification.type == "insert" then
        local new_instrument = renoise.song().instruments[notification.index]
        attach_instrument_elements_observers(registry, new_instrument, notification.index)
    elseif notification.type == "remove" then
        main_module.remove(registry, notification, rust_backend, index_registry_module)
    elseif notification.type == "swap" then
        main_module.swap(registry, notification, rust_backend, index_registry_module)
        index_registry_module.print_instrument_map(registry)
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

--- @param registry IndexRegistry The shared index registry
--- @param change {path: string, instrument_index: number, phrase_index: number, phrase_name: string, script_body: string}
local function apply_change(registry, change)
    local target_instrument_index = change.instrument_index
    local target_phrase_index = change.phrase_index
    local script_body = change.script_body

    local instrument_id, instrument_data = index_registry_module.find_instrument_by_index(registry, target_instrument_index)
    if not instrument_data then
        return
    end

    local _, phrase_data = index_registry_module.find_phrase_by_index(registry, instrument_id, target_phrase_index)
    if not phrase_data then
        return
    end

    local instrument = renoise.song().instruments[instrument_data.current_index]
    if not instrument then
        return
    end

    local phrase = instrument.phrases[phrase_data.current_index]
    if not phrase then
        return
    end

    if phrase.playback_mode == renoise.InstrumentPhrase.PLAY_SCRIPT then
        phrase.script.paragraphs = split_lines(script_body)
        renoise.app():show_status("PhraseScriptsReloader: phrase script reloaded from file: " ..
                phrase_data.name)
    end
end

--- @param registry IndexRegistry The shared registry
local function request_changes(registry)
    local changes = rust_backend.take_changes(renoise.song().file_name)
    if #changes > 0 then
        renoise.app():show_status("PhraseScriptsReloader: reloading phrase scripts from files...")
    end
    for _, change in ipairs(changes) do
        apply_change(registry, change)
    end
end

local function on_new_document()
    renoise.app():show_status("PhraseScriptsReloader: initializing observers for new document")

    local registry = index_registry_module.new()

    renoise.song().instruments_observable:add_notifier(function(notification)
        on_instruments_changed(registry, notification)
    end)

    local instruments = renoise.song().instruments
    for i = 1, #instruments do
        attach_instrument_elements_observers(registry, instruments[i], i)
    end

    local function request_changes_callback()
        request_changes(registry)
    end

    if renoise.tool():has_timer(request_changes_callback) then
        renoise.tool():remove_timer(request_changes_callback)
    end
    renoise.tool():add_timer(request_changes_callback, 1000)
end

renoise.tool().app_new_document_observable:add_notifier(on_new_document)