local main_module = require("main_module")
local IndexRegistry = require("index_registry")
local test_helpers = require("spec.test_helpers")

test_helpers.setup_renoise_mock()

describe("Reproducing Renoise Instrument Swap", function()
    local registry
    local rust_backend_mock

    before_each(function()
        registry = IndexRegistry.new()
        IndexRegistry.register_instrument(registry, 1, "Piano")
        IndexRegistry.register_instrument(registry, 2, "Guitar")
        IndexRegistry.register_instrument(registry, 3, "Drums")

        IndexRegistry.register_phrase(registry, 1, 1, "Piano Intro")
        IndexRegistry.register_phrase(registry, 1, 2, "Piano Verse")
        IndexRegistry.register_phrase(registry, 1, 3, "Piano Chorus")

        IndexRegistry.register_phrase(registry, 2, 1, "Guitar Intro")
        IndexRegistry.register_phrase(registry, 2, 2, "Guitar Verse")
        IndexRegistry.register_phrase(registry, 2, 3, "Guitar Chorus")

        IndexRegistry.register_phrase(registry, 3, 1, "Drums Intro")
        IndexRegistry.register_phrase(registry, 3, 2, "Drums Verse")
        IndexRegistry.register_phrase(registry, 3, 3, "Drums Chorus")

        rust_backend_mock = test_helpers.create_rust_backend_mock()
    end)

    it("Swaps from the beginning to the end", function()
        local initial_piano_position = 1
        local desired_piano_position = 4
        local notification = { index1 = initial_piano_position, index2 = desired_piano_position }

        -- Renoise inserts here automatically
        IndexRegistry.register_instrument(registry, desired_piano_position, nil)
        main_module.swap(registry, notification, rust_backend_mock, IndexRegistry)
        -- Renoise remove the position where the inserted element was
        main_module.remove(registry, { index = initial_piano_position }, rust_backend_mock, IndexRegistry)

        local _, i1 = IndexRegistry.find_instrument_by_index(registry, 1)
        local _, i2 = IndexRegistry.find_instrument_by_index(registry, 2)
        local _, i3 = IndexRegistry.find_instrument_by_index(registry, 3)
        local _, i4 = IndexRegistry.find_instrument_by_index(registry, 4)

        assert.are.equal("Guitar", i1.name)
        assert.are.equal("Drums", i2.name)
        assert.are.equal("Piano", i3.name)
        assert.is_nil(i4)

        assert.are.equal(3, IndexRegistry.get_instrument_count(registry))
        assert.is_true(rust_backend_mock.swap_instruments_called)
        assert.is_true(rust_backend_mock.remove_instrument_called)
    end)

    it("Swaps from the end to the beginning", function()
        -- Initial: Piano(1), Guitar(2), Drums(3)
        -- Goal: Drums(1), Piano(2), Guitar(3)
        local initial_drums_position = 3
        local desired_drums_position = 1

        -- Renoise inserts at position 1, shifting everything right
        -- State becomes: nil(1), Piano(2), Guitar(3), Drums(4)
        IndexRegistry.register_instrument(registry, desired_drums_position, nil)

        -- Drums is now at position 4 (shifted from 3)
        local shifted_drums_position = initial_drums_position + 1
        local notification = { index1 = shifted_drums_position, index2 = desired_drums_position }

        main_module.swap(registry, notification, rust_backend_mock, IndexRegistry)
        -- After swap: Drums(1), Piano(2), Guitar(3), nil(4)

        -- Renoise removes where the nil ended up (position 4)
        main_module.remove(registry, { index = shifted_drums_position }, rust_backend_mock, IndexRegistry)

        local _, i1 = IndexRegistry.find_instrument_by_index(registry, 1)
        local _, i2 = IndexRegistry.find_instrument_by_index(registry, 2)
        local _, i3 = IndexRegistry.find_instrument_by_index(registry, 3)
        local _, i4 = IndexRegistry.find_instrument_by_index(registry, 4)

        assert.are.equal("Drums", i1.name)
        assert.are.equal("Piano", i2.name)
        assert.are.equal("Guitar", i3.name)
        assert.is_nil(i4)

        assert.are.equal(3, IndexRegistry.get_instrument_count(registry))
        assert.is_true(rust_backend_mock.swap_instruments_called)
        assert.is_true(rust_backend_mock.remove_instrument_called)
    end)

    it("Swaps from the middle to the end", function()
        -- Initial: Piano(1), Guitar(2), Drums(3)
        -- Goal: Piano(1), Drums(2), Guitar(3)
        local initial_guitar_position = 2
        local desired_guitar_position = 4

        -- Renoise inserts at position 4
        -- State becomes: Piano(1), Guitar(2), Drums(3), nil(4)
        IndexRegistry.register_instrument(registry, desired_guitar_position, nil)

        local notification = { index1 = initial_guitar_position, index2 = desired_guitar_position }

        main_module.swap(registry, notification, rust_backend_mock, IndexRegistry)
        -- After swap: Piano(1), nil(2), Drums(3), Guitar(4)

        -- Renoise removes where the nil ended up (position 2)
        main_module.remove(registry, { index = initial_guitar_position }, rust_backend_mock, IndexRegistry)

        local _, i1 = IndexRegistry.find_instrument_by_index(registry, 1)
        local _, i2 = IndexRegistry.find_instrument_by_index(registry, 2)
        local _, i3 = IndexRegistry.find_instrument_by_index(registry, 3)
        local _, i4 = IndexRegistry.find_instrument_by_index(registry, 4)

        assert.are.equal("Piano", i1.name)
        assert.are.equal("Drums", i2.name)
        assert.are.equal("Guitar", i3.name)
        assert.is_nil(i4)

        assert.are.equal(3, IndexRegistry.get_instrument_count(registry))
        assert.is_true(rust_backend_mock.swap_instruments_called)
        assert.is_true(rust_backend_mock.remove_instrument_called)
    end)

    it("Swaps from the middle to the beginning", function()
        -- Initial: Piano(1), Guitar(2), Drums(3)
        -- Goal: Guitar(1), Piano(2), Drums(3)
        local initial_guitar_position = 2
        local desired_guitar_position = 1

        -- Renoise inserts at position 1, shifting everything right
        -- State becomes: nil(1), Piano(2), Guitar(3), Drums(4)
        IndexRegistry.register_instrument(registry, desired_guitar_position, nil)

        -- Guitar is now at position 3 (shifted from 2)
        local shifted_guitar_position = initial_guitar_position + 1
        local notification = { index1 = shifted_guitar_position, index2 = desired_guitar_position }

        main_module.swap(registry, notification, rust_backend_mock, IndexRegistry)
        -- After swap: Guitar(1), Piano(2), nil(3), Drums(4)

        -- Renoise removes where the nil ended up (position 3)
        main_module.remove(registry, { index = shifted_guitar_position }, rust_backend_mock, IndexRegistry)

        local _, i1 = IndexRegistry.find_instrument_by_index(registry, 1)
        local _, i2 = IndexRegistry.find_instrument_by_index(registry, 2)
        local _, i3 = IndexRegistry.find_instrument_by_index(registry, 3)
        local _, i4 = IndexRegistry.find_instrument_by_index(registry, 4)

        assert.are.equal("Guitar", i1.name)
        assert.are.equal("Piano", i2.name)
        assert.are.equal("Drums", i3.name)
        assert.is_nil(i4)

        assert.are.equal(3, IndexRegistry.get_instrument_count(registry))
        assert.is_true(rust_backend_mock.swap_instruments_called)
        assert.is_true(rust_backend_mock.remove_instrument_called)
    end)

    it("Swaps from the end to the middle", function()
        -- Initial: Piano(1), Guitar(2), Drums(3)
        -- Goal: Piano(1), Drums(2), Guitar(3)
        local initial_drums_position = 3
        local desired_drums_position = 2

        -- Renoise inserts at position 2, shifting positions 2+ to the right
        -- State becomes: Piano(1), nil(2), Guitar(3), Drums(4)
        IndexRegistry.register_instrument(registry, desired_drums_position, nil)

        -- Drums is now at position 4 (shifted from 3)
        local shifted_drums_position = initial_drums_position + 1
        local notification = { index1 = shifted_drums_position, index2 = desired_drums_position }

        main_module.swap(registry, notification, rust_backend_mock, IndexRegistry)
        -- After swap: Piano(1), Drums(2), Guitar(3), nil(4)

        -- Renoise removes where the nil ended up (position 4)
        main_module.remove(registry, { index = shifted_drums_position }, rust_backend_mock, IndexRegistry)

        local _, i1 = IndexRegistry.find_instrument_by_index(registry, 1)
        local _, i2 = IndexRegistry.find_instrument_by_index(registry, 2)
        local _, i3 = IndexRegistry.find_instrument_by_index(registry, 3)
        local _, i4 = IndexRegistry.find_instrument_by_index(registry, 4)

        assert.are.equal("Piano", i1.name)
        assert.are.equal("Drums", i2.name)
        assert.are.equal("Guitar", i3.name)
        assert.is_nil(i4)

        assert.are.equal(3, IndexRegistry.get_instrument_count(registry))
        assert.is_true(rust_backend_mock.swap_instruments_called)
        assert.is_true(rust_backend_mock.remove_instrument_called)
    end)

    it("Swaps from the beginning to the middle", function()
        -- Initial: Piano(1), Guitar(2), Drums(3)
        -- Goal: Guitar(1), Piano(2), Drums(3)
        local initial_piano_position = 1
        -- To move Piano to final position 2, we need to insert at position 3
        -- because after removal of nil at position 1, position 3 becomes position 2
        local desired_piano_position = 3

        -- Renoise inserts at position 3
        -- State becomes: Piano(1), Guitar(2), nil(3), Drums(4)
        IndexRegistry.register_instrument(registry, desired_piano_position, nil)

        local notification = { index1 = initial_piano_position, index2 = desired_piano_position }

        main_module.swap(registry, notification, rust_backend_mock, IndexRegistry)
        -- After swap: nil(1), Guitar(2), Piano(3), Drums(4)

        -- Renoise removes where the nil ended up (position 1)
        main_module.remove(registry, { index = initial_piano_position }, rust_backend_mock, IndexRegistry)

        local _, i1 = IndexRegistry.find_instrument_by_index(registry, 1)
        local _, i2 = IndexRegistry.find_instrument_by_index(registry, 2)
        local _, i3 = IndexRegistry.find_instrument_by_index(registry, 3)
        local _, i4 = IndexRegistry.find_instrument_by_index(registry, 4)

        assert.are.equal("Guitar", i1.name)
        assert.are.equal("Piano", i2.name)
        assert.are.equal("Drums", i3.name)
        assert.is_nil(i4)

        assert.are.equal(3, IndexRegistry.get_instrument_count(registry))
        assert.is_true(rust_backend_mock.swap_instruments_called)
        assert.is_true(rust_backend_mock.remove_instrument_called)
    end)

    it("Swaps adjacent instruments forward (position 1 to 2)", function()
        -- Initial: Piano(1), Guitar(2), Drums(3)
        -- Goal: Guitar(1), Piano(2), Drums(3)
        local initial_piano_position = 1
        -- To swap with adjacent (move Piano after Guitar), insert at position 3
        local desired_piano_position = 3

        -- Renoise inserts at position 3
        -- State becomes: Piano(1), Guitar(2), nil(3), Drums(4)
        IndexRegistry.register_instrument(registry, desired_piano_position, nil)

        local notification = { index1 = initial_piano_position, index2 = desired_piano_position }

        main_module.swap(registry, notification, rust_backend_mock, IndexRegistry)
        -- After swap: nil(1), Guitar(2), Piano(3), Drums(4)

        -- Renoise removes position 1
        main_module.remove(registry, { index = initial_piano_position }, rust_backend_mock, IndexRegistry)

        local _, i1 = IndexRegistry.find_instrument_by_index(registry, 1)
        local _, i2 = IndexRegistry.find_instrument_by_index(registry, 2)
        local _, i3 = IndexRegistry.find_instrument_by_index(registry, 3)

        assert.are.equal("Guitar", i1.name)
        assert.are.equal("Piano", i2.name)
        assert.are.equal("Drums", i3.name)

        assert.are.equal(3, IndexRegistry.get_instrument_count(registry))
        assert.is_true(rust_backend_mock.swap_instruments_called)
        assert.is_true(rust_backend_mock.remove_instrument_called)
    end)

    it("Swaps adjacent instruments backward (position 2 to 1)", function()
        -- Initial: Piano(1), Guitar(2), Drums(3)
        -- Goal: Guitar(1), Piano(2), Drums(3)
        local initial_guitar_position = 2
        local desired_guitar_position = 1

        -- Renoise inserts at position 1
        -- State becomes: nil(1), Piano(2), Guitar(3), Drums(4)
        IndexRegistry.register_instrument(registry, desired_guitar_position, nil)

        -- Guitar shifted from 2 to 3
        local shifted_guitar_position = initial_guitar_position + 1
        local notification = { index1 = shifted_guitar_position, index2 = desired_guitar_position }

        main_module.swap(registry, notification, rust_backend_mock, IndexRegistry)
        -- After swap: Guitar(1), Piano(2), nil(3), Drums(4)

        -- Renoise removes position 3 (where nil ended up)
        main_module.remove(registry, { index = shifted_guitar_position }, rust_backend_mock, IndexRegistry)

        local _, i1 = IndexRegistry.find_instrument_by_index(registry, 1)
        local _, i2 = IndexRegistry.find_instrument_by_index(registry, 2)
        local _, i3 = IndexRegistry.find_instrument_by_index(registry, 3)

        assert.are.equal("Guitar", i1.name)
        assert.are.equal("Piano", i2.name)
        assert.are.equal("Drums", i3.name)

        assert.are.equal(3, IndexRegistry.get_instrument_count(registry))
        assert.is_true(rust_backend_mock.swap_instruments_called)
        assert.is_true(rust_backend_mock.remove_instrument_called)
    end)
end)