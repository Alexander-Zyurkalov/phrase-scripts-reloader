local IndexRegistry = require("index_registry")

describe("IndexRegistry", function()
    local registry

    before_each(function()
        registry = IndexRegistry.new()
    end)

    it("registers an instrument", function()
        local id = registry:register_instrument(1, "Piano")
        assert.are.equal(1, id)

        local data = registry:get_instrument_by_id(id)
        assert.are.equal("Piano", data.name)
        assert.are.equal(1, data.current_index)
    end)

    it("removes an instrument but ids persist", function()
        local instrument1 = registry:register_instrument(1, "Piano")
        local instrument2 = registry:register_instrument(3, "Violin")
        registry:remove_instrument(3)
        local instrument3 = registry:register_instrument(3, "Kick")
        assert.are.equal(2, instrument2)
        assert.are.equal(3, instrument3)
    end)

    it("updates indexes on insert", function()
        registry:register_instrument(1, "Piano")
        registry:register_instrument(2, "Guitar")
        registry:register_instrument(1, "Something else")

        local _, data = registry:find_instrument_by_index(3)
        assert.are.equal("Guitar", data.name)
    end)
end)

describe("Phrase management", function()
    local registry

    before_each(function()
        registry = IndexRegistry.new()
        registry:register_instrument(1, "Piano")
    end)

    it("registers a phrase", function()
        local phrase_id = registry:register_phrase(1, 1, "Intro")
        assert.are.equal(1, phrase_id)

        local data = registry:get_phrase_by_id(1, phrase_id)
        assert.are.equal("Intro", data.name)
        assert.are.equal(1, data.current_index)
        assert.is_false(data.is_script_registered)
    end)

    it("assigns incrementing phrase IDs per instrument", function()
        local phrase1 = registry:register_phrase(1, 1, "Intro")
        local phrase2 = registry:register_phrase(1, 2, "Verse")
        assert.are.equal(1, phrase1)
        assert.are.equal(2, phrase2)
    end)

    it("maintains separate phrase ID counters per instrument", function()
        registry:register_instrument(2, "Guitar")

        local piano_phrase = registry:register_phrase(1, 1, "Piano Intro")
        local guitar_phrase = registry:register_phrase(2, 1, "Guitar Intro")

        assert.are.equal(1, piano_phrase)
        assert.are.equal(1, guitar_phrase)
    end)

    it("removes a phrase but IDs persist", function()
        local phrase1 = registry:register_phrase(1, 1, "Intro")
        local phrase2 = registry:register_phrase(1, 2, "Verse")
        registry:remove_phrase(1, phrase1)
        local phrase3 = registry:register_phrase(1, 3, "Chorus")

        assert.are.equal(1, phrase1)
        assert.are.equal(2, phrase2)
        assert.are.equal(3, phrase3)
        assert.is_nil(registry:get_phrase_by_id(1, phrase1))
    end)

    it("returns nil for non-existent phrase", function()
        local data = registry:get_phrase_by_id(1, 999)
        assert.is_nil(data)
    end)

    it("returns nil for phrase in non-existent instrument", function()
        local data = registry:get_phrase_by_id(999, 1)
        assert.is_nil(data)
    end)

    it("finds phrase by index", function()
        registry:register_phrase(1, 5, "Chorus")

        local id, data = registry:find_phrase_by_index(1, 5)
        assert.are.equal(1, id)
        assert.are.equal("Chorus", data.name)
    end)

    it("returns nil when finding phrase by non-existent index", function()
        registry:register_phrase(1, 1, "Intro")

        local id, data = registry:find_phrase_by_index(1, 999)
        assert.is_nil(id)
        assert.is_nil(data)
    end)

    it("returns nil when finding phrase in non-existent instrument", function()
        local id, data = registry:find_phrase_by_index(999, 1)
        assert.is_nil(id)
        assert.is_nil(data)
    end)
end)


-- Swap operations
describe("Swap operations", function()
    local registry

    before_each(function()
        registry = IndexRegistry.new()
    end)

    it("swaps instrument indexes", function()
        registry:register_instrument(1, "Piano")
        registry:register_instrument(2, "Guitar")
        registry:register_instrument(3, "Drums")

        registry:swap_instrument_indexes(1, 3)

        local _, piano = registry:find_instrument_by_index(3)
        local _, guitar = registry:find_instrument_by_index(2)
        local _, drums = registry:find_instrument_by_index(1)

        assert.are.equal("Piano", piano.name)
        assert.are.equal("Guitar", guitar.name)
        assert.are.equal("Drums", drums.name)
    end)

    it("handles swap with non-existent index gracefully", function()
        registry:register_instrument(1, "Piano")

        -- Should not error, just won't swap anything
        registry:swap_instrument_indexes(1, 999)

        local _, piano = registry:find_instrument_by_index(1)
        assert.are.equal("Piano", piano.name)
    end)

    it("swaps phrase indexes within an instrument", function()
        registry:register_instrument(1, "Piano")
        registry:register_phrase(1, 1, "Intro")
        registry:register_phrase(1, 2, "Verse")
        registry:register_phrase(1, 3, "Chorus")

        registry:swap_phrase_indexes(1, 1, 3)

        local _, intro = registry:find_phrase_by_index(1, 3)
        local _, chorus = registry:find_phrase_by_index(1, 1)

        assert.are.equal("Intro", intro.name)
        assert.are.equal("Chorus", chorus.name)
    end)

    it("handles phrase swap in non-existent instrument gracefully", function()
        -- Should not error
        registry:swap_phrase_indexes(999, 1, 2)
    end)
end)

-- Edge cases
describe("Edge cases", function()
    local registry

    before_each(function()
        registry = IndexRegistry.new()
    end)

    it("cleans up phrase data when instrument is removed", function()
        local inst_id = registry:register_instrument(1, "Piano")
        registry:register_phrase(inst_id, 1, "Intro")

        registry:remove_instrument(inst_id)

        assert.is_nil(registry.phrase_map[inst_id])
        assert.is_nil(registry.next_phrase_id[inst_id])
    end)

    it("handles remove_phrase on non-existent instrument gracefully", function()
        -- Should not error
        registry:remove_phrase(999, 1)
    end)
end)