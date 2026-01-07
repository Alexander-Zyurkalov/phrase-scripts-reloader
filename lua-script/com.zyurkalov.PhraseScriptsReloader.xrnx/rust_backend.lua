local rust_backend = {}

--@param path string
---@param instrument_index number
---@param instrument_name string
---@param phrase_index number
---@param phrase_name string
---@param script_body string
function rust_backend.register_script(path, instrument_index, instrument_name, phrase_index, phrase_name, script_body)
end

---@param path string
---@param instrument_index number
---@param phrase_index number
---@param old_name string
---@param new_name string
function rust_backend.rename_script(path, instrument_index, phrase_index, old_name, new_name)
end

---@param path string
---@param instrument_index number
---@param phrase_index number
function rust_backend.remove_script(path, instrument_index, phrase_index)
end

---@param path string
---@param instrument_index number
---@param old_instrument_name string
---@param new_instrument_name string
function rust_backend.rename_instrument(path, instrument_index, old_instrument_name, new_instrument_name)
end

---@param path string
---@param instrument_index number
function rust_backend.remove_instrument(path, instrument_index)
end

---@param path string
---@param instrument_index1 number
---@param instrument_index2 number
function rust_backend.swap_instruments(path, instrument_index1, instrument_index2)
end

---@param path string
---@param instrument_index number
---@param phrase_index1 number
---@param phrase_index2 number
function rust_backend.swap_phrases(path, instrument_index, phrase_index1, phrase_index2)
end

---@param path string
---@return {path: string, instrument_index: number, phrase_index: number, phrase_name: string, script_body: string}[]
function rust_backend.take_changes(path)
    return {}
end

return rust_backend