import Testing

@testable import SynthesisCore

struct SearchIndexMaintenanceTests {
  @Test func checksSameCountDriftAndRebuildsOnlyOneWorld() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Local")
    let foreignWorld = try store.createWorld(name: "Other")
    let foreign = try store.createRecord(
      worldID: foreignWorld.id, title: "Another place", body: "Sodalite")
    let home = try store.createRecord(worldID: world.id, title: "Glassy Deep", kind: "entity")
    let type = try store.saveEntityType(
      worldID: world.id, name: "Navigator",
      fields: [EntityField(key: "home", label: "Home", kind: .entity)],
      defaults: ["home": .entity(home.id)])
    let entity = try store.createRecord(
      worldID: world.id, title: "Mira", body: "Argillite", kind: "entity")
    _ = try store.saveEntityProfile(
      worldID: world.id, recordID: entity.id, typeID: type.id, values: [:], expectedVersion: nil)
    let period = try store.createEntityNamePeriod(
      worldID: world.id, recordID: entity.id, draft: .init(name: "Astral Guide"))
    let inactive = try store.createEntityNamePeriod(
      worldID: world.id, recordID: entity.id, draft: .init(name: "Rime Keeper"))
    _ = try store.archiveEntityNamePeriod(worldID: world.id, expected: inactive)
    _ = try store.promote(
      worldID: world.id, id: entity.id, version: entity.version, confirmation: entity.id)
    try store.archiveRecord(worldID: world.id, id: entity.id)
    #expect(try store.staleSearchIndexes(worldID: world.id).isEmpty)
    _ = try store.saveRecord(
      worldID: world.id, id: home.id, version: home.version, title: "Shimmering Port",
      body: home.body, rtf: home.rtf)
    #expect(try store.staleSearchIndexes(worldID: world.id) == [.entityProperties])
    try store.db.execute("UPDATE records_fts SET body='Stale body' WHERE id=?", [entity.id])
    try store.db.execute(
      "UPDATE entity_name_search SET name='Old name' WHERE period_id=?", [period.id])
    try store.db.execute("DELETE FROM records_fts WHERE id=?", [foreign.id])
    #expect(try store.staleSearchIndexes(worldID: world.id) == Set(SearchIndexComponent.allCases))
    #expect(try store.staleSearchIndexes(worldID: foreignWorld.id) == [.records])
    let before = try store.exportWorldArchive(worldID: world.id)
    try store.rebuildSearchIndexes(worldID: world.id)
    #expect(try store.staleSearchIndexes(worldID: world.id).isEmpty)
    #expect(try store.staleSearchIndexes(worldID: foreignWorld.id) == [.records])
    for query in ["Argillite", "Astral Guide", "Shimmering"] {
      let matches = try store.search(worldID: world.id, query: query, archived: true)
      #expect(matches.map(\.id) == [entity.id])
    }
    #expect(try store.search(worldID: world.id, query: "Argillite").isEmpty)
    #expect(try store.search(worldID: world.id, query: "Rime Keeper", archived: true).isEmpty)
    #expect(try store.search(worldID: foreignWorld.id, query: "Sodalite").isEmpty)
    #expect(try store.exportWorldArchive(worldID: world.id) == before)
    #expect(throws: SynthesisError.self) { try store.rebuildSearchIndexes(worldID: "missing") }
  }

  @Test func failedPropertyRebuildRestoresEarlierIndexWrites() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Local")
    let other = try store.createWorld(name: "Other")
    let foreign = try store.createRecord(worldID: other.id, title: "Foreign home", kind: "entity")
    let type = try store.saveEntityType(
      worldID: world.id, name: "Navigator",
      fields: [EntityField(key: "home", label: "Home", kind: .entity)])
    let entity = try store.createRecord(
      worldID: world.id, title: "Mira", body: "Argillite", kind: "entity")
    _ = try store.saveEntityProfile(
      worldID: world.id, recordID: entity.id, typeID: type.id, values: [:], expectedVersion: nil)
    try store.db.execute("DELETE FROM records_fts WHERE id=?", [entity.id])
    try store.db.execute(
      "UPDATE entity_profiles SET values_json=? WHERE record_id=?",
      [try schemaJSON(["home": EntityValue.entity(foreign.id)]), entity.id])
    let profileIndex = try store.db.rows(
      "SELECT * FROM entity_profile_search WHERE world_id=?", [world.id])
    #expect(throws: SynthesisError.self) { try store.rebuildSearchIndexes(worldID: world.id) }
    #expect(try store.search(worldID: world.id, query: "Argillite").isEmpty)
    #expect(
      try store.db.rows("SELECT * FROM entity_profile_search WHERE world_id=?", [world.id])
        == profileIndex)
  }
}
