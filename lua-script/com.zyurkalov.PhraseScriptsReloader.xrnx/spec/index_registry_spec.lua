local IndexRegistry = require("index_registry")

describe("IndexRegistry", function()
    local registry

    before_each(function()
        registry = IndexRegistry.new()
    end)

    it("registers an instrument", function()
        local id = IndexRegistry.register_instrument(registry, 1, "Piano")
        assert.are.equal(1, id)

        local data = IndexRegistry.get_instrument_by_id(registry, id)
        assert.are.equal("Piano", data.name)
        assert.are.equal(1, data.current_index)
    end)

    it("removes an instrument but ids persist", function()
        local instrument1 = IndexRegistry.register_instrument(registry, 1, "Piano")
        local instrument2 = IndexRegistry.register_instrument(registry, 3, "Violin")
        IndexRegistry.remove_instrument(registry, 3)
        local instrument3 = IndexRegistry.register_instrument(registry, 3, "Kick")
        assert.are.equal(2, instrument2)
        assert.are.equal(3, instrument3)
    end)

    it("updates indexes on insert", function()
        IndexRegistry.register_instrument(registry, 1, "Piano")
        IndexRegistry.register_instrument(registry, 2, "Guitar")
        IndexRegistry.register_instrument(registry, 1, "Something else")

        local _, data = IndexRegistry.find_instrument_by_index(registry, 3)
        assert.are.equal("Guitar", data.name)
    end)
end)

describe("Phrase management", function()
    local registry

    before_each(function()
        registry = IndexRegistry.new()
        IndexRegistry.register_instrument(registry, 1, "Piano")
    end)

    it("registers a phrase", function()
        local phrase_id = IndexRegistry.register_phrase(registry, 1, 1, "Intro")
        assert.are.equal(1, phrase_id)

        local data = IndexRegistry.get_phrase_by_id(registry, 1, phrase_id)
        assert.are.equal("Intro", data.name)
        assert.are.equal(1, data.current_index)
        assert.is_false(data.is_script_registered)
    end)

    it("assigns incrementing phrase IDs per instrument", function()
        local phrase1 = IndexRegistry.register_phrase(registry, 1, 1, "Intro")
        local phrase2 = IndexRegistry.register_phrase(registry, 1, 2, "Verse")
        assert.are.equal(1, phrase1)
        assert.are.equal(2, phrase2)
    end)

    it("maintains separate phrase ID counters per instrument", function()
        IndexRegistry.register_instrument(registry, 2, "Guitar")

        local piano_phrase = IndexRegistry.register_phrase(registry, 1, 1, "Piano Intro")
        local guitar_phrase = IndexRegistry.register_phrase(registry, 2, 1, "Guitar Intro")

        assert.are.equal(1, piano_phrase)
        assert.are.equal(1, guitar_phrase)
    end)

    it("removes a phrase but IDs persist", function()
        local phrase1 = IndexRegistry.register_phrase(registry, 1, 1, "Intro")
        local phrase2 = IndexRegistry.register_phrase(registry, 1, 2, "Verse")
        IndexRegistry.remove_phrase(registry, 1, phrase1)
        local phrase3 = IndexRegistry.register_phrase(registry, 1, 3, "Chorus")

        assert.are.equal(1, phrase1)
        assert.are.equal(2, phrase2)
        assert.are.equal(3, phrase3)
        assert.is_nil(IndexRegistry.get_phrase_by_id(registry, 1, phrase1))
    end)

    it("returns nil for non-existent phrase", function()
        local data = IndexRegistry.get_phrase_by_id(registry, 1, 999)
        assert.is_nil(data)
    end)

    it("returns nil for phrase in non-existent instrument", function()
        local data = IndexRegistry.get_phrase_by_id(registry, 999, 1)
        assert.is_nil(data)
    end)

    it("finds phrase by index", function()
        IndexRegistry.register_phrase(registry, 1, 5, "Chorus")

        local id, data = IndexRegistry.find_phrase_by_index(registry, 1, 5)
        assert.are.equal(1, id)
        assert.are.equal("Chorus", data.name)
    end)

    it("returns nil when finding phrase by non-existent index", function()
        IndexRegistry.register_phrase(registry, 1, 1, "Intro")

        local id, data = IndexRegistry.find_phrase_by_index(registry, 1, 999)
        assert.is_nil(id)
        assert.is_nil(data)
    end)

    it("returns nil when finding phrase in non-existent instrument", function()
        local id, data = IndexRegistry.find_phrase_by_index(registry, 999, 1)
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
        IndexRegistry.register_instrument(registry, 1, "Piano")
        IndexRegistry.register_instrument(registry, 2, "Guitar")
        IndexRegistry.register_instrument(registry, 3, "Drums")

        IndexRegistry.swap_instrument_indexes(registry, 1, 3)

        local _, piano = IndexRegistry.find_instrument_by_index(registry, 3)
        local _, guitar = IndexRegistry.find_instrument_by_index(registry, 2)
        local _, drums = IndexRegistry.find_instrument_by_index(registry, 1)

        assert.are.equal("Piano", piano.name)
        assert.are.equal("Guitar", guitar.name)
        assert.are.equal("Drums", drums.name)
    end)

    it("handles swap with non-existent index gracefully", function()
        IndexRegistry.register_instrument(registry, 1, "Piano")

        -- Should not error, just won't swap anything
        IndexRegistry.swap_instrument_indexes(registry, 1, 999)

        local _, piano = IndexRegistry.find_instrument_by_index(registry, 1)
        assert.are.equal("Piano", piano.name)
    end)

    it("swaps phrase indexes within an instrument", function()
        IndexRegistry.register_instrument(registry, 1, "Piano")
        IndexRegistry.register_phrase(registry, 1, 1, "Intro")
        IndexRegistry.register_phrase(registry, 1, 2, "Verse")
        IndexRegistry.register_phrase(registry, 1, 3, "Chorus")

        IndexRegistry.swap_phrase_indexes(registry, 1, 1, 3)

        local _, intro = IndexRegistry.find_phrase_by_index(registry, 1, 3)
        local _, chorus = IndexRegistry.find_phrase_by_index(registry, 1, 1)

        assert.are.equal("Intro", intro.name)
        assert.are.equal("Chorus", chorus.name)
    end)

    it("handles phrase swap in non-existent instrument gracefully", function()
        -- Should not error
        IndexRegistry.swap_phrase_indexes(registry, 999, 1, 2)
    end)
end)

-- Edge cases
describe("Edge cases", function()
    local registry

    before_each(function()
        registry = IndexRegistry.new()
    end)

    it("cleans up phrase data when instrument is removed", function()
        local inst_id = IndexRegistry.register_instrument(registry, 1, "Piano")
        IndexRegistry.register_phrase(registry, inst_id, 1, "Intro")

        IndexRegistry.remove_instrument(registry, inst_id)

        assert.is_nil(registry.phrase_map[inst_id])
        assert.is_nil(registry.next_phrase_id[inst_id])
    end)

    it("handles remove_phrase on non-existent instrument gracefully", function()
        -- Should not error
        IndexRegistry.remove_phrase(registry, 999, 1)
    end)
end)

