local rust_backend = require('rust_backend')

-- Create a new backend
local rust, err = rust_backend.new("mypath.xrns", 1)
if err then
    print("Error creating backend: " .. err)
    return
end
print("Backend created successfully")

-- Set instrument indexes: instrument 1 -> index 1, instrument 2 -> index 10
local _, err = rust:set_new_instrument_indexes({ { 1, 1 }, { 2, 10 } })
if err then
    print("Error setting instrument indexes: " .. err)
    return
end
print("Instrument indexes set")

-- Set phrase indexes for instrument 1: phrase 1 -> index 1, phrase 2 -> index 2
local _, err = rust:set_new_phrase_indexes(1, { { 1, 1 }, { 2, 2 } })
if err then
    print("Error setting phrase indexes: " .. err)
    return
end
print("Phrase indexes set for instrument 1")

-- Set phrase indexes for instrument 2: phrase 3 -> index 1
local _, err = rust:set_new_phrase_indexes(2, { { 3, 1 } })
if err then
    print("Error setting phrase indexes: " .. err)
    return
end
print("Phrase indexes set for instrument 2")

-- Register a script (with body)
local path, err = rust:register_script(1, "Piano", 1, "Intro", 'return cycle("c4")')
if err then
    print("Error registering script: " .. err)
    return
end
print("Registered script at: " .. path)

-- Register a second phrase
local path2, err = rust:register_script(1, "Piano", 2, "Verse", 'return cycle("e4")')
if err then
    print("Error registering second script: " .. err)
    return
end
print("Registered second script at: " .. path2)

-- Register a script for instrument 2
local path3, err = rust:register_script(2, "Bass", 3, "Bassline", 'return cycle("c2")')
if err then
    print("Error registering bass script: " .. err)
    return
end
print("Registered bass script at: " .. path3)

-- Rename a phrase script
local _, err = rust:rename_script(1, 1, "Intro_v2")
if err then
    print("Error renaming script: " .. err)
    return
end
print("Script renamed successfully")

-- Rename an instrument
local _, err = rust:rename_instrument(2, "Synth Bass")
if err then
    print("Error renaming instrument: " .. err)
    return
end
print("Instrument renamed successfully")

-- Update the song path
local _, err = rust:update_song_path("new_song_path.xrns")
if err then
    print("Error updating song path: " .. err)
    return
end
print("Song path updated")

-- Take changes (usually called after external edits to the script files)
local changes, err = rust:take_changes()
if err then
    print("Error taking changes: " .. err)
    return
end
print("Changes taken: " .. #changes .. " change(s)")
for i, change in ipairs(changes) do
    print(string.format(
            "  Change %d: instrument=%s (id=%d), phrase=%s (id=%d)",
            i,
            change.instrument_name,
            change.instrument_id,
            change.phrase_name,
            change.phrase_id
    ))
    print("    body: " .. change.script_body)
end

-- Unregister a script (creates a .bak file)
local bak_path, err = rust:unregister_script(1, 2)
if err then
    print("Error unregistering script: " .. err)
    return
end
print("Unregistered script, backup at: " .. bak_path)

-- Unregister an entire instrument
local _, err = rust:unregister_instrument(2)
if err then
    print("Error unregistering instrument: " .. err)
    return
end
print("Instrument 2 unregistered")

print("\nAll bindings work!")