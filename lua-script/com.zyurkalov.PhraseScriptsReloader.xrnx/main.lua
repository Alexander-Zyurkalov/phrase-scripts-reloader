local RustBackend = require("rust_backend")
local IndexRegistry = require("index_registry")
local MainModule = require("main_module")

--- @param registry IndexRegistry The shared index registry
--- @param instrument renoise.Instrument
--- @param instrument_index number The current index of the instrument
--- @param rust_backend RustBackend
--- @param main MainModule
local function attach_instrument_elements_observers(registry, instrument, instrument_index, rust_backend, main)
    local instrument_id = registry:register_instrument(instrument_index, instrument.name)

    local on_instrument_renamed = function()
        local instrument_data = registry:get_instrument_by_id(instrument_id)
        renoise.app():show_status("PhraseScriptsReloader: renaming instrument folder from '" .. instrument_data.name ..
                "' to '" .. instrument.name .. "'")
        main:rename_instrument(
                instrument_id,
                instrument.name
        )
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
            local phrase_id = registry:register_phrase(instrument_id, phrase_index, phrase.name)

            local on_playback_mode_changed = function()
                local phrase_data = registry:get_phrase_by_id(instrument_id, phrase_id)
                if phrase.playback_mode == renoise.InstrumentPhrase.PLAY_SCRIPT then
                    renoise.app():show_status("PhraseScriptsReloader: registering new script file for the phrase '" ..
                            phrase.name .. "'")
                    local script_text = table.concat(phrase.script.paragraphs, "\n")
                    main:register_script(instrument_id, phrase_id, script_text)
                elseif phrase_data.is_script_registered then
                    renoise.app():show_status("PhraseScriptsReloader: unregistering script file for phrase '" ..
                            phrase.name .. "'")
                    main:unregister_script(instrument_id, phrase_id)
                end
            end

            local on_phrase_renamed = function()
                renoise.app():show_status("PhraseScriptsReloader: renaming script file from '" ..
                        registry:get_phrase_by_id(instrument_id, phrase_id).name .. "' to '" .. phrase.name .. "'")
                main:rename_phrase(
                        instrument_id,
                        phrase_id,
                        phrase.name,
                        phrase.playback_mode == renoise.InstrumentPhrase.PLAY_SCRIPT
                )
            end

            on_playback_mode_changed()
            phrase.playback_mode_observable:add_notifier(on_playback_mode_changed)
            phrase.name_observable:add_notifier(on_phrase_renamed)

        elseif notification.type == "remove" then
            local phrase_data = registry:get_phrase_by_id(instrument_id, notification.index)
            if phrase_data then
                renoise.app():show_status("PhraseScriptsReloader: removing phrase '" .. phrase_data.name .. "'")
            end
            main:remove_phrase(instrument_id, notification)
        elseif notification.type == "swap" then
            renoise.app():show_status("PhraseScriptsReloader: swapping phrases")
            main:swap_phrases_indexes(instrument_id, notification)
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
--- @param rust_backend RustBackend
--- @param main MainModule
local function on_instruments_changed(registry, notification, rust_backend, main)
    if notification.type == "insert" then
        local new_instrument = renoise.song().instruments[notification.index]
        attach_instrument_elements_observers(registry, new_instrument, notification.index, rust_backend, main)
    elseif notification.type == "remove" then
        main:remove_instrument(notification)
    elseif notification.type == "swap" then
        main:swap_instrument_indexes(notification)
    end
end

--- @param change {instrument_index: number, phrase_index: number, phrase_name: string, script_body: string}
local function apply_script_change(change)
    local instrument_index = change.instrument_index
    local phrase_index = change.phrase_index
    local script_body = change.script_body
    local phrase_name = change.phrase_name

    local instrument = renoise.song().instruments[instrument_index]
    if not instrument then
        return
    end

    local phrase = instrument.phrases[phrase_index]
    if not phrase then
        return
    end

    if phrase.playback_mode == renoise.InstrumentPhrase.PLAY_SCRIPT then
        local lines = {}
        for line in script_body:gmatch("([^\n]*)\n?") do
            lines[#lines + 1] = line
        end
        if #lines > 0 and lines[#lines] == "" then
            lines[#lines] = nil
        end
        phrase.script.paragraphs = lines
        renoise.app():show_status("PhraseScriptsReloader: phrase script reloaded from file: " ..
                phrase_name)
    end
end

--- Shows validation errors in a warning dialog
--- @param errors {message: string, path: string}[]
local function show_validation_errors(errors)
    local error_lines = {}
    for _, error in ipairs(errors) do
        table.insert(error_lines, "• " .. error.message)
        table.insert(error_lines, "  Path: " .. error.path)
        table.insert(error_lines, "")
    end
    local error_text = table.concat(error_lines, "\n")
    renoise.app():show_warning(
            "PhraseScriptsReloader: Some script changes were skipped due to validation errors:\n\n" ..
                    error_text
    )
end

--- @param main MainModule
local function request_changes(main)
    local changes, errors = main:take_changes()

    if #errors > 0 then
        show_validation_errors(errors)
    end

    if #changes > 0 then
        renoise.app():show_status("PhraseScriptsReloader: reloading phrase scripts from files...")
    end
    for _, change in ipairs(changes) do
        apply_script_change(change)
    end
end

local saved_document_notifier = nil
local request_changes_callback = nil

local function on_new_document()
    renoise.app():show_status("PhraseScriptsReloader: initializing observers for new document")

    local rust_backend = RustBackend.new(renoise.song().file_name)
    local registry = IndexRegistry.new()
    local main = MainModule.new(rust_backend, registry)

    renoise.song().instruments_observable:add_notifier(function(notification)
        on_instruments_changed(registry, notification, rust_backend, main)
    end)

    local instruments = renoise.song().instruments
    for i = 1, #instruments do
        attach_instrument_elements_observers(registry, instruments[i], i, rust_backend, main)
    end

    -- Remove previous timer if exists
    if request_changes_callback and renoise.tool():has_timer(request_changes_callback) then
        renoise.tool():remove_timer(request_changes_callback)
    end

    request_changes_callback = function()
        request_changes(main)
    end
    renoise.tool():add_timer(request_changes_callback, 1000)

    -- Remove previous saved document notifier if exists
    if saved_document_notifier then
        renoise.tool().app_saved_document_observable:remove_notifier(saved_document_notifier)
    end

    saved_document_notifier = function()
        rust_backend:update_song_path(renoise.song().file_name)
    end
    renoise.tool().app_saved_document_observable:add_notifier(saved_document_notifier)
end

renoise.tool().app_new_document_observable:add_notifier(on_new_document)