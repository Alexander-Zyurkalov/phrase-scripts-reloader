local rust_backend = require('rust_backend')
local rust = rust_backend.new("mypath.mp4", 10)

local err_nil, err = rust:set_new_instrument_indexes({ {1, 1}, {2, 4} })
rust:register_script()
if err then print("Error: " .. err) end

