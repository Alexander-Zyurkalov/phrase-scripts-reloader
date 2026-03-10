local rust_backend = require('rust_backend')
local rust, err = rust_backend.new("mypath.mp4", 1)
if err then
    print("Error: " .. err)
    return
end
local err_nil, err = rust:set_new_instrument_indexes({ { 1, 1 }, { 2, 10 } })
if err then
    print("Error: " .. err)
    return
end

local path, err = rust:register_script(1, "Piano", 1, "Intro", "return cycle(\"c4\")")
if err then
    print("Error: " .. err)
    return
end
print("Path = ", path)



