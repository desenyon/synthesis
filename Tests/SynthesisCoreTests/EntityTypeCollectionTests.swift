import Testing

@testable import SynthesisCore

struct EntityTypeCollectionTests {
  @Test func collectionMembershipFollowsAssignmentsAndSchemaLifecycle() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Aster")
    let foreign = try store.createWorld(name: "Another world")
    let source = try store.createRecord(
      worldID: world.id, title: "Harbor traveler", kind: "entity", category: "Factions")
    let type = try store.saveEntityType(worldID: world.id, name: "Navigator", fields: [])
    let other = try store.saveEntityType(worldID: world.id, name: "Archivist", fields: [])
    let foreignType = try store.saveEntityType(worldID: foreign.id, name: type.name, fields: [])
    let foreignRecord = try store.createTypedEntity(
      worldID: foreign.id, typeID: foreignType.id, title: "Travel log")
    let profile = try store.saveEntityProfile(
      worldID: world.id, recordID: source.id, typeID: type.id, values: [:], expectedVersion: nil)
    let initial = try store.entityTypeCollections(worldID: world.id)
    #expect(initial.map(\.id) == [other.id, type.id])
    #expect(initial.last?.recordIDs == [source.id])
    #expect(
      try store.entityTypeCollections(worldID: foreign.id).first?.recordIDs == [foreignRecord.id])

    let renamed = try store.saveEntityType(
      worldID: world.id, id: type.id, expectedVersion: type.version, name: "Wayfinder", fields: [])
    #expect(try store.entityTypeCollections(worldID: world.id).last?.name == renamed.name)
    #expect(try store.entityTypeCollections(worldID: world.id).last?.recordIDs == [source.id])
    try store.setEntityTypeArchived(
      worldID: world.id, id: type.id, archived: true, expectedVersion: renamed.version)
    #expect(try store.entityTypeCollections(worldID: world.id).map(\.id) == [other.id])
    #expect(try store.entityProfile(worldID: world.id, recordID: source.id) == profile)
    #expect(
      try store.search(
        worldID: world.id, query: "Harbor", scope: .init(entityTypeID: type.id)
      ).isEmpty)
    let archived = try store.entityType(worldID: world.id, id: type.id)
    try store.setEntityTypeArchived(
      worldID: world.id, id: type.id, archived: false, expectedVersion: archived.version)
    #expect(try store.entityTypeCollections(worldID: world.id).last?.recordIDs == [source.id])

    _ = try store.saveEntityProfile(
      worldID: world.id, recordID: source.id, typeID: other.id, values: [:],
      expectedVersion: profile.version)
    let moved = try store.entityTypeCollections(worldID: world.id)
    #expect(moved.first?.recordIDs == [source.id] && moved.last?.recordIDs.isEmpty == true)
    #expect(try store.record(worldID: world.id, id: source.id) == source)
  }

  @Test func stableTypeScopeIntersectsSearchBeforeLimitsAndLeavesLegacyAliasesWorking() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Aster")
    let foreign = try store.createWorld(name: "Separate world")
    let type = try store.saveEntityType(worldID: world.id, name: "Navigator", fields: [])
    let foreignType = try store.saveEntityType(worldID: foreign.id, name: "Navigator", fields: [])
    let source = try store.createRecord(
      worldID: world.id, title: "Harbor note", kind: "entity", category: "Factions")
    _ = try store.saveMetadata(
      worldID: world.id, id: source.id, version: source.version, tags: [], aliases: ["Cartographer"]
    )
    _ = try store.saveEntityProfile(
      worldID: world.id, recordID: source.id, typeID: type.id, values: [:], expectedVersion: nil)
    for _ in 0..<55 {
      _ = try store.createRecord(
        worldID: world.id, title: "Harbor note", kind: "entity", category: "Navigator")
    }
    let scope = LoreSearchScope(entityTypeID: type.id)
    #expect(
      try store.search(worldID: world.id, query: "Harbor", scope: scope).map(\.id) == [source.id])
    #expect(
      try store.search(worldID: world.id, query: "alias:Cartographer", scope: scope).map(\.id)
        == [source.id])
    #expect(try store.search(worldID: world.id, query: "category:Systems").map(\.id) == [source.id])
    #expect(
      try store.search(
        worldID: world.id, query: "Harbor", scope: .init(entityTypeID: foreignType.id)
      ).isEmpty)
    try store.archiveRecord(worldID: world.id, id: source.id)
    #expect(try store.search(worldID: world.id, query: "Harbor", scope: scope).isEmpty)
    #expect(
      try store.search(worldID: world.id, query: "Harbor", archived: true, scope: scope).map(\.id)
        == [source.id])
  }
}
