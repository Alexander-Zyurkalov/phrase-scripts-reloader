local rust_backend = {}

---@param path string
---@param instrument_index number
---@param phrase_index number
---@param phrase_name string
---@param script_body string
function rust_backend.register_new_script(path, instrument_index, phrase_index, phrase_name, script_body)
    print(" ======= register-new-script =======")
    print("path = " .. path)
    print("instrument_index = " .. instrument_index)
    print("phrase_index = " .. phrase_index)
    print("phrase_name = " .. phrase_name)
    print("script_body = " .. script_body)
end

---@param path string
---@param instrument_index number
---@param phrase_index number
---@param old_name string
---@param new_name string
function rust_backend.rename_script(path, instrument_index, phrase_index, old_name, new_name)
    print(" ======= rename-script =======")
    print("path = " .. path)
    print("instrument_index = " .. instrument_index)
    print("phrase_index = " .. phrase_index)
    print("old_name = " .. old_name)
    print("new_name = " .. new_name)
end

---@param path string
---@param instrument_index number
---@param phrase_index number
function rust_backend.remove_script(path, instrument_index, phrase_index)
    print(" ======= remove-script =======")
    print("path = " .. path)
    print("instrument_index = " .. instrument_index)
    print("phrase_index = " .. phrase_index)
end

---@param path string
---@param instrument_index number
---@param old_instrument_name string
---@param new_instrument_name string
function rust_backend.rename_instrument(path, instrument_index, old_instrument_name, new_instrument_name)
    print(" ======= rename-instrument =======")
    print("path = " .. path)
    print("instrument_index = " .. instrument_index)
    print("old_instrument_name = " .. old_instrument_name)
    print("new_instrument_name = " .. new_instrument_name)
end

---@param path string
---@param instrument_index number
function rust_backend.remove_instrument(path, instrument_index)
    print(" ======= remove-instrument =======")
    print("path = " .. path)
    print("instrument_index = " .. instrument_index)
end

---@param path string
---@return {instrument_name: string, phrase_name: string, script_body: string}[]
function rust_backend.request_changes(path)
    if math.random() < 0.1 then
        return {
            [1] = {
                instrument_name = "my_instrument",
                phrase_name = "my_phrase",
                script_body = [[
return cycle("bm ta bm ta"):map({
    bm = "c1",
    ta = "c#1",
}) ]]
            }
        }
    else
        return {}
    end
end

return rust_backend