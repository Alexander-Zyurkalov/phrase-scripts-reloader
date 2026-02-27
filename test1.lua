local rust_backend = require('rust_backend')
local rust = rust_backend.new("mypath.mp4", 10)

print("rust object = ", rust)
