local rust_backend = require('rust_backend')
local rust = rust_backend.new("mypath.mp4", 10)

local ok, err = pcall(function()
    rust:set_new_instrument_indexes({ {1, 1}, {2, 127} })
end)

if not ok then
    print("Error: " .. err)
end