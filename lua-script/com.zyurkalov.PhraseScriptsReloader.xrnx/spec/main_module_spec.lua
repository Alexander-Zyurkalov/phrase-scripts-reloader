local MainModule = require("main_module")
local IndexRegistry = require("index_registry")
local TestHelpers = require("spec.test_helpers")

-- Test case definitions for reordering scenarios
-- Each case defines: description, initial_position, desired_position, expected_final_order
local reorder_test_cases = {
    {
        desc = "from the beginning to the end",
        initial_pos = 1,
        desired_pos = 4,
        moves_forward = true,
        expected_instrument_order = { "Guitar", "Drums", "Piano" },  -- for instruments
        expected_phrase_order = { "Verse", "Chorus", "Intro" },
    },
    {
        desc = "from the end to the beginning",
        initial_pos = 3,
        desired_pos = 1,
        moves_forward = false,
        expected_instrument_order = { "Drums", "Piano", "Guitar" },
        expected_phrase_order = { "Chorus", "Intro", "Verse" },
    },
    {
        desc = "from the middle to the end",
        initial_pos = 2,
        desired_pos = 4,
        moves_forward = true,
        expected_instrument_order = { "Piano", "Drums", "Guitar" },
        expected_phrase_order = { "Intro", "Chorus", "Verse" },
    },
    {
        desc = "from the middle to the beginning",
        initial_pos = 2,
        desired_pos = 1,
        moves_forward = false,
        expected_instrument_order = { "Guitar", "Piano", "Drums" },
        expected_phrase_order = { "Verse", "Intro", "Chorus" },
    },
    {
        desc = "from the end to the middle",
        initial_pos = 3,
        desired_pos = 2,
        moves_forward = false,
        expected_instrument_order = { "Piano", "Drums", "Guitar" },
        expected_phrase_order = { "Intro", "Chorus", "Verse" },
    },
    {
        desc = "from the beginning to the middle",
        initial_pos = 1,
        desired_pos = 3,
        moves_forward = true,
        expected_instrument_order = { "Guitar", "Piano", "Drums" },
        expected_phrase_order = { "Verse", "Intro", "Chorus" },
    },
    {
        desc = "adjacent forward (position 1 to 2)",
        initial_pos = 1,
        desired_pos = 3,
        moves_forward = true,
        expected_instrument_order = { "Guitar", "Piano", "Drums" },
        expected_phrase_order = { "Verse", "Intro", "Chorus" },
    },
    {
        desc = "adjacent backward (position 2 to 1)",
        initial_pos = 2,
        desired_pos = 1,
        moves_forward = false,
        expected_instrument_order = { "Guitar", "Piano", "Drums" },
        expected_phrase_order = { "Verse", "Intro", "Chorus" },
    },
}

--- Helper to execute instrument swap-remove pattern and return results
--- @param registry IndexRegistry
--- @param main MainModule
--- @param test_case table
--- @return number nil_id The ID of the inserted nil instrument
local function execute_instrument_reorder(registry, main, test_case)
    local nil_instrument_id = registry:register_instrument(test_case.desired_pos, nil)

    local swap_index1, remove_index
    if test_case.moves_forward then
        swap_index1 = test_case.initial_pos
        remove_index = test_case.initial_pos
    else
        swap_index1 = test_case.initial_pos + 1
        remove_index = test_case.initial_pos + 1
    end

    local notification = { index1 = swap_index1, index2 = test_case.desired_pos }
    main:swap_instrument_indexes(notification)
    main:remove_instrument({ index = remove_index })

    return nil_instrument_id
end

--- Helper to execute phrase swap-remove pattern and return results
--- @param registry IndexRegistry
--- @param main MainModule
--- @param instrument_id number
--- @param test_case table
--- @return number nil_id The ID of the inserted nil phrase
local function execute_phrase_reorder(registry, main, instrument_id, test_case)
    local nil_phrase_id = registry:register_phrase(instrument_id, test_case.desired_pos, nil)

    local swap_index1, remove_index
    if test_case.moves_forward then
        swap_index1 = test_case.initial_pos
        remove_index = test_case.initial_pos
    else
        swap_index1 = test_case.initial_pos + 1
        remove_index = test_case.initial_pos + 1
    end

    local notification = { index1 = swap_index1, index2 = test_case.desired_pos }
    main:swap_phrases_indexes(instrument_id, notification)
    main:remove_phrase(instrument_id, { index = remove_index })

    return nil_phrase_id
end

describe("Instrument Reordering via Insert-Swap-Remove Pattern", function()
    local registry
    local rust_backend_mock
    local main

    before_each(function()
        registry = IndexRegistry.new()
        registry:register_instrument(1, "Piano")
        registry:register_instrument(2, "Guitar")
        registry:register_instrument(3, "Drums")

        registry:register_phrase(1, 1, "Piano Intro")
        registry:register_phrase(1, 2, "Piano Verse")
        registry:register_phrase(1, 3, "Piano Chorus")

        registry:register_phrase(2, 1, "Guitar Intro")
        registry:register_phrase(2, 2, "Guitar Verse")
        registry:register_phrase(2, 3, "Guitar Chorus")

        registry:register_phrase(3, 1, "Drums Intro")
        registry:register_phrase(3, 2, "Drums Verse")
        registry:register_phrase(3, 3, "Drums Chorus")

        rust_backend_mock = TestHelpers.create_rust_backend_mock()
        main = MainModule.new(rust_backend_mock, registry)
    end)

    for _, test_case in ipairs(reorder_test_cases) do
        it("Swaps " .. test_case.desc, function()
            execute_instrument_reorder(registry, main, test_case)

            -- Verify final instrument positions
            local _, i1 = registry:find_instrument_by_index(1)
            local _, i2 = registry:find_instrument_by_index(2)
            local _, i3 = registry:find_instrument_by_index(3)
            local _, i4 = registry:find_instrument_by_index(4)

            assert.are.equal(test_case.expected_instrument_order[1], i1.name)
            assert.are.equal(test_case.expected_instrument_order[2], i2.name)
            assert.are.equal(test_case.expected_instrument_order[3], i3.name)
            assert.is_nil(i4)

            assert.are.equal(3, registry:get_instrument_count())
            assert.is_true(rust_backend_mock.set_new_instrument_indexes_called)
            assert.is_true(rust_backend_mock.remove_instrument_called)
        end)
    end
end)

describe("Phrase Reordering via Insert-Swap-Remove Pattern", function()
    local registry
    local rust_backend_mock
    local main
    local instrument_id

    before_each(function()
        registry = IndexRegistry.new()
        instrument_id = registry:register_instrument(1, "Piano")

        registry:register_phrase(instrument_id, 1, "Intro")
        registry:register_phrase(instrument_id, 2, "Verse")
        registry:register_phrase(instrument_id, 3, "Chorus")

        rust_backend_mock = TestHelpers.create_rust_backend_mock()
        main = MainModule.new(rust_backend_mock, registry)
    end)

    for _, test_case in ipairs(reorder_test_cases) do
        it("Swaps phrases " .. test_case.desc, function()
            execute_phrase_reorder(registry, main, instrument_id, test_case)

            -- Verify final phrase positions
            local _, p1 = registry:find_phrase_by_index(instrument_id, 1)
            local _, p2 = registry:find_phrase_by_index(instrument_id, 2)
            local _, p3 = registry:find_phrase_by_index(instrument_id, 3)
            local _, p4 = registry:find_phrase_by_index(instrument_id, 4)

            assert.are.equal(test_case.expected_phrase_order[1], p1.name)
            assert.are.equal(test_case.expected_phrase_order[2], p2.name)
            assert.are.equal(test_case.expected_phrase_order[3], p3.name)
            assert.is_nil(p4)

            assert.is_true(rust_backend_mock.set_new_phrase_indexes_called)
            local instrument_data = registry:get_instrument_by_id(instrument_id)
            assert.are.equal(instrument_data.current_index, rust_backend_mock.set_new_phrase_indexes_calls[1].instrument_index)
        end)
    end
end)

describe("Renaming Instruments", function()
    local registry
    local rust_backend_mock
    local main

    before_each(function()
        registry = IndexRegistry.new()
        registry:register_instrument(1, "Piano")
        registry:register_instrument(2, "Guitar")
        registry:register_instrument(3, "Drums")

        rust_backend_mock = TestHelpers.create_rust_backend_mock()
        main = MainModule.new(rust_backend_mock, registry)
    end)

    it("Renames an instrument and updates the registry", function()
        local instrument_id = 1  -- Piano
        local new_name = "Grand Piano"

        main:rename_instrument(instrument_id, new_name)

        -- Get instrument data to verify index
        local instrument_data = registry:get_instrument_by_id(instrument_id)

        -- Verify rust backend was called with correct parameters
        assert.is_true(rust_backend_mock.rename_instrument_called)
        assert.are.equal(1, #rust_backend_mock.rename_instrument_calls)
        assert.are.equal(instrument_data.current_index, rust_backend_mock.rename_instrument_calls[1].instrument_index)
        assert.are.equal("Piano", rust_backend_mock.rename_instrument_calls[1].old_name)
        assert.are.equal(new_name, rust_backend_mock.rename_instrument_calls[1].new_name)

        -- Verify registry name was updated
        assert.are.equal(new_name, instrument_data.name)
    end)
end)

describe("Removing Phrases with Scripts", function()
    local registry
    local rust_backend_mock
    local main
    local instrument_id

    before_each(function()
        registry = IndexRegistry.new()
        instrument_id = registry:register_instrument(1, "Piano")

        registry:register_phrase(instrument_id, 1, "Intro")
        registry:register_phrase(instrument_id, 2, "Verse")
        registry:register_phrase(instrument_id, 3, "Chorus")

        rust_backend_mock = TestHelpers.create_rust_backend_mock()
        main = MainModule.new(rust_backend_mock, registry)
    end)

    it("calls unregister_script with correct instrument_index and phrase_index when phrase has a script", function()
        -- Mark phrase at index 2 as having a script registered
        local _, phrase_data = registry:find_phrase_by_index(instrument_id, 2)
        phrase_data.is_script_registered = true

        -- Get the instrument data to verify indexes
        local instrument_data = registry:get_instrument_by_id(instrument_id)
        local expected_instrument_index = instrument_data.current_index
        local expected_phrase_index = phrase_data.current_index

        -- Remove the phrase
        main:remove_phrase(instrument_id, { index = 2 })

        -- Verify unregister_script was called
        assert.is_true(rust_backend_mock.unregister_script_called)
        assert.are.equal(1, #rust_backend_mock.unregister_script_calls)

        -- Verify correct indexes were passed
        local call = rust_backend_mock.unregister_script_calls[1]
        assert.are.equal(expected_instrument_index, call.instrument_index)
        assert.are.equal(expected_phrase_index, call.phrase_index)
    end)

    it("does not call unregister_script when phrase has no script registered", function()
        -- Remove phrase without script (is_script_registered is nil/false by default)
        main:remove_phrase(instrument_id, { index = 2 })

        -- Verify unregister_script was NOT called
        assert.is_false(rust_backend_mock.unregister_script_called)
        assert.are.equal(0, #rust_backend_mock.unregister_script_calls)
    end)

    it("removes phrase from registry regardless of script status", function()
        -- Mark phrase as having a script
        local phrase_id, phrase_data = registry:find_phrase_by_index(instrument_id, 2)
        phrase_data.is_script_registered = true

        -- Remove the phrase
        main:remove_phrase(instrument_id, { index = 2 })

        -- Verify phrase was removed from registry
        local removed_id, _ = registry:find_phrase_by_index(instrument_id, 2)
        assert.are.not_equal(phrase_id, removed_id)
    end)
end)

describe("Registering Scripts", function()
    local registry
    local rust_backend_mock
    local main
    local instrument_id

    before_each(function()
        registry = IndexRegistry.new()
        instrument_id = registry:register_instrument(1, "Piano")

        registry:register_phrase(instrument_id, 1, "Intro")
        registry:register_phrase(instrument_id, 2, "Verse")
        registry:register_phrase(instrument_id, 3, "Chorus")

        rust_backend_mock = TestHelpers.create_rust_backend_mock()
        main = MainModule.new(rust_backend_mock, registry)
    end)

    it("calls register_script with correct parameters and marks phrase as registered", function()
        local phrase_id = 2
        local script_text = "-- This is a test script\nprint('Hello')"

        -- Get data before calling register_script
        local instrument_data = registry:get_instrument_by_id(instrument_id)
        local phrase_data = registry:get_phrase_by_id(instrument_id, phrase_id)

        -- Call register_script
        main:register_script(instrument_id, phrase_id, script_text)

        -- Verify register_script was called
        assert.is_true(rust_backend_mock.register_script_called)
        assert.are.equal(1, #rust_backend_mock.register_script_calls)

        -- Verify correct parameters were passed
        local call = rust_backend_mock.register_script_calls[1]
        assert.are.equal(instrument_data.current_index, call.instrument_index)
        assert.are.equal(instrument_data.name, call.instrument_name)
        assert.are.equal(phrase_data.current_index, call.phrase_index)
        assert.are.equal(phrase_data.name, call.phrase_name)
        assert.are.equal(script_text, call.script_body)

        -- Verify is_script_registered was set to true
        assert.is_true(phrase_data.is_script_registered)
    end)
end)

describe("Unregistering Scripts", function()
    local registry
    local rust_backend_mock
    local main
    local instrument_id

    before_each(function()
        registry = IndexRegistry.new()
        instrument_id = registry:register_instrument(1, "Piano")

        registry:register_phrase(instrument_id, 1, "Intro")
        registry:register_phrase(instrument_id, 2, "Verse")
        registry:register_phrase(instrument_id, 3, "Chorus")

        rust_backend_mock = TestHelpers.create_rust_backend_mock()
        main = MainModule.new(rust_backend_mock, registry)
    end)

    it("calls unregister_script with correct parameters and marks phrase as unregistered", function()
        local phrase_id = 2

        -- First register a script
        registry:get_phrase_by_id(instrument_id, phrase_id).is_script_registered = true

        -- Get data before calling unregister_script
        local instrument_data = registry:get_instrument_by_id(instrument_id)
        local phrase_data = registry:get_phrase_by_id(instrument_id, phrase_id)

        -- Verify script is registered before unregistering
        assert.is_true(phrase_data.is_script_registered)

        -- Call unregister_script
        main:unregister_script(instrument_id, phrase_id)

        -- Verify unregister_script was called
        assert.is_true(rust_backend_mock.unregister_script_called)
        assert.are.equal(1, #rust_backend_mock.unregister_script_calls)

        -- Verify correct parameters were passed
        local call = rust_backend_mock.unregister_script_calls[1]
        assert.are.equal(instrument_data.current_index, call.instrument_index)
        assert.are.equal(phrase_data.current_index, call.phrase_index)

        -- Verify is_script_registered was set to false
        assert.is_false(phrase_data.is_script_registered)
    end)
end)

describe("Renaming Phrases", function()
    local registry
    local rust_backend_mock
    local main
    local instrument_id

    before_each(function()
        registry = IndexRegistry.new()
        instrument_id = registry:register_instrument(1, "Piano")

        registry:register_phrase(instrument_id, 1, "Intro")
        registry:register_phrase(instrument_id, 2, "Verse")
        registry:register_phrase(instrument_id, 3, "Chorus")

        rust_backend_mock = TestHelpers.create_rust_backend_mock()
        main = MainModule.new(rust_backend_mock, registry)
    end)

    it("calls rename_script when phrase is in script playback mode", function()
        local phrase_id = 2
        local new_name = "Verse Extended"

        local instrument_data = registry:get_instrument_by_id(instrument_id)
        local phrase_data = registry:get_phrase_by_id(instrument_id, phrase_id)
        local old_name = phrase_data.name

        -- Call rename_phrase with is_playing_script = true
        main:rename_phrase(instrument_id, phrase_id, new_name, true)

        -- Verify rename_script was called
        assert.is_true(rust_backend_mock.rename_script_called)
        assert.are.equal(1, #rust_backend_mock.rename_script_calls)

        -- Verify correct parameters were passed
        local call = rust_backend_mock.rename_script_calls[1]
        assert.are.equal(instrument_data.current_index, call.instrument_index)
        assert.are.equal(phrase_data.current_index, call.phrase_index)
        assert.are.equal(old_name, call.old_name)
        assert.are.equal(new_name, call.new_name)

        -- Verify phrase name was updated in registry
        assert.are.equal(new_name, phrase_data.name)
    end)

    it("does not call rename_script when phrase is not in script playback mode", function()
        local phrase_id = 2
        local new_name = "Verse Extended"

        local phrase_data = registry:get_phrase_by_id(instrument_id, phrase_id)
        local old_name = phrase_data.name

        -- Call rename_phrase with is_playing_script = false
        main:rename_phrase(instrument_id, phrase_id, new_name, false)

        -- Verify rename_script was NOT called
        assert.is_false(rust_backend_mock.rename_script_called)
        assert.are.equal(0, #rust_backend_mock.rename_script_calls)

        -- Verify phrase name was still updated in registry
        assert.are.equal(new_name, phrase_data.name)
    end)
end)