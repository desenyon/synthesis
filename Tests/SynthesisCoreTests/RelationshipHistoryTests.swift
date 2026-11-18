import Testing

@testable import SynthesisCore

struct RelationshipHistoryTests {
  @Test func edgeHistoryRetainsScopedSnapshotsAndPagesTiedTimestamps() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Edge history")
    let foreign = try store.createWorld(name: "Other universe")
    let first = try store.createRecord(worldID: world.id, title: "Mira", kind: "entity")
    let second = try store.createRecord(worldID: world.id, title: "Oren", kind: "entity")
    let edge = try store.addRelation(
      worldID: world.id, source: first.id, target: second.id, label: "mentors")
    #expect(try store.relationshipHistory(worldID: world.id, relationshipID: edge.id).isEmpty)
    #expect(throws: SynthesisError.self) {
      try store.relationshipHistory(worldID: foreign.id, relationshipID: edge.id)
    }

    var attributes = RelationshipAttributes()
    attributes.strength = .strong
    let changed = try store.updateRelation(
      worldID: world.id, expected: edge, label: "teaches", attributes: attributes)
    try store.updateRelation(worldID: world.id, id: edge.id, label: "guided")
    try store.db.execute(
      "UPDATE relationship_history SET created_at=? WHERE world_id=? AND relationship_id=?",
      ["2026-01-01T00:00:00Z", world.id, edge.id])
    let firstPage = try store.relationshipHistory(
      worldID: world.id, relationshipID: edge.id, limit: 1)
    let snapshot = try #require(firstPage.first)
    #expect(snapshot.label == "teaches" && snapshot.attributes == attributes)
    #expect(snapshot.revision == changed.revision)
    let secondPage = try store.relationshipHistory(
      worldID: world.id, relationshipID: edge.id, before: snapshot.cursor, limit: 1)
    #expect(secondPage.count == 1)
    #expect(secondPage.first?.label == edge.label && secondPage.first?.revision == edge.revision)

    try store.archiveRelation(worldID: world.id, id: edge.id)
    #expect(throws: SynthesisError.self) {
      try store.relationshipHistory(worldID: world.id, relationshipID: edge.id)
    }
    try store.restoreRelation(worldID: world.id, id: edge.id)
    let archive = try #require(
      try store.relationshipHistory(worldID: world.id, relationshipID: edge.id).first)
    #expect(archive.label == "guided" && archive.action == "archive")
    try store.archiveRecord(worldID: world.id, id: second.id)
    #expect(throws: SynthesisError.self) {
      try store.relationshipHistory(worldID: world.id, relationshipID: edge.id)
    }
  }
}
