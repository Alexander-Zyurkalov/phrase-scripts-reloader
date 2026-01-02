local file_info = require("phrase_scripts_reloader")
function write_tidalcycles_to_phrase()
    local song = renoise.song()
    local instrument = song.selected_instrument
    if #instrument.phrases == 0 then
        instrument:insert_phrase_at(1)
    end
    local phrase = instrument.phrases[1]
    phrase.playback_mode = renoise.InstrumentPhrase.PLAY_SCRIPT

    ---@class renoise.InstrumentPhraseScript
    local script = phrase.script

    local tidal_code = [[return cycle("c4 d4 e4 f4")]]

    -- Split into lines and assign as a table
    local lines = {}
    for line in tidal_code:gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end

    script.paragraphs = lines

    script:commit()
end

write_tidalcycles_to_phrase()
print(file_info.get_mtime("test1.lua"))