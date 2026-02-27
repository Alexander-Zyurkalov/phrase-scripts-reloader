local rust_backend = require('rust_backend')
local rust = rust_backend.new("mypath.mp4", 10)
rust:set_new_instrument_indexes({ {1, 1}, {2, 2}})

print("rust object = ", rust)
