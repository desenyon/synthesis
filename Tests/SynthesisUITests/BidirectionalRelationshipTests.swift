import SynthesisCore
import Testing

@testable import SynthesisUI

@MainActor struct BidirectionalRelationshipTests {
  @Test func aSingleDirectedEdgeIsDiscoverableFromBothEntityProfiles() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let studio = try Studio(store: store)
    let world = studio.worldID
    let mira = try store.createRecord(
      worldID: world, title: "Mira", kind: "entity", category: "Characters")
    let keepers = try store.createRecord(
      worldID: world, title: "Tidekeepers", kind: "entity", category: "Factions")
    let edge = try store.addRelation(
      worldID: world, source: mira.id, target: keepers.id, label: "belongs to")
    try studio.reload()

    studio.openRecord(mira)
    let fromMira = try studio.recordRelationships(for: mira)
    #expect(fromMira.map(\.id) == [edge.id])
    let outgoing = try #require(fromMira.first)
    #expect(outgoing.detail == "Outgoing · belongs to")
    #expect(outgoing.counterpart.id == keepers.id)
    studio.openRecord(outgoing.counterpart)
    #expect(studio.selectedRecord?.id == keepers.id)

    let fromKeepers = try studio.recordRelationships(for: keepers)
    #expect(fromKeepers.map(\.id) == [edge.id])
    let incoming = try #require(fromKeepers.first)
    #expect(incoming.detail == "Incoming · belongs to")
    #expect(incoming.counterpart.id == mira.id)
    studio.openRecord(incoming.counterpart)
    #expect(studio.selectedRecord?.id == mira.id)

    #expect(try store.relations(worldID: world) == [edge])
    #expect(try store.record(worldID: world, id: mira.id) == mira)
    #expect(try store.record(worldID: world, id: keepers.id) == keepers)
    try store.archiveRelation(worldID: world, id: edge.id)
    #expect(try studio.recordRelationships(for: mira).isEmpty)
    #expect(try studio.recordRelationships(for: keepers).isEmpty)
    try store.restoreRelation(worldID: world, id: edge.id)
    #expect(try studio.recordRelationships(for: mira).map(\.id) == [edge.id])
    #expect(try studio.recordRelationships(for: keepers).map(\.id) == [edge.id])
  }
}
