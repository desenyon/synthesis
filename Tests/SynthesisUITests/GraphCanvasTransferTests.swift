import Foundation
import SynthesisCore
import Testing

@testable import SynthesisUI

@MainActor struct GraphCanvasTransferTests {
  @Test func aNeighborhoodCopiesCurrentRecordIDsAndLeavesLiveRelationshipsIntact() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let studio = try Studio(store: store)
    let world = studio.worldID
    let focal = try store.createRecord(
      worldID: world, title: String(repeating: "a", count: 120), kind: "entity")
    let incoming = try store.createRecord(worldID: world, title: "Incoming", kind: "entity")
    let outgoing = try store.createRecord(worldID: world, title: "Outgoing", kind: "entity")
    let farther = try store.createRecord(worldID: world, title: "Farther", kind: "entity")
    let beyond = try store.createRecord(worldID: world, title: "Beyond", kind: "entity")
    _ = try store.addRelation(
      worldID: world, source: incoming.id, target: focal.id, label: "visits")
    _ = try store.addRelation(
      worldID: world, source: focal.id, target: outgoing.id, label: "mentors")
    _ = try store.addRelation(
      worldID: world, source: outgoing.id, target: farther.id, label: "visits")
    _ = try store.addRelation(
      worldID: world, source: farther.id, target: beyond.id, label: "visits")
    let original = try store.relations(worldID: world)
    try studio.reload()
    studio.navigate(.knowledge)
    let positions: [String: CGPoint] = [
      focal.id: .zero, incoming.id: CGPoint(x: -100, y: 20),
      outgoing.id: CGPoint(x: 200, y: -30), farther.id: CGPoint(x: 400, y: -60),
      beyond.id: CGPoint(x: 600, y: -90),
    ]
    let expected: Set<String> = [focal.id, incoming.id, outgoing.id, farther.id]
    let scope = GraphNeighborhood(rootID: focal.id, depth: 2)
    let board = try #require(
      try studio.copyGraphToCanvas(
        worldID: world, neighborhood: scope, shownIDs: expected, positions: positions))
    let projection = try CanvasBoardContent.decode(board.content)
    let cards = try #require(projection.legacy?.cards)
    #expect(Set(cards.compactMap(\.recordID)) == expected)
    #expect(cards.first(where: { $0.recordID == incoming.id })?.x == -120)
    #expect(cards.first(where: { $0.recordID == outgoing.id })?.y == -39)
    #expect(projection.legacy?.edges.isEmpty == true)
    #expect(board.name.count == 120)
    #expect(try store.relations(worldID: world) == original)
    #expect(studio.destination == .canvas && studio.canvasBoardID == board.id)
  }

  @Test func unavailableSourcesAndFailedSavesDoNotCreateBoards() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let studio = try Studio(store: store)
    let world = studio.worldID
    let entity = try store.createRecord(worldID: world, title: "Entity", kind: "entity")
    let foreign = try store.createWorld(name: "Another universe")
    try studio.reload()
    studio.navigate(.knowledge)
    let baseline = try store.boards(worldID: world, kind: "canvas").map(\.id)
    let points = [entity.id: CGPoint(x: 1, y: 2)]
    let scope = GraphNeighborhood(rootID: entity.id, depth: 1)
    studio.splitEditorSave = { false }
    #expect(
      try studio.copyGraphToCanvas(
        worldID: world, neighborhood: scope, shownIDs: [entity.id], positions: points) == nil)
    studio.splitEditorSave = nil
    #expect(
      try studio.copyGraphToCanvas(
        worldID: foreign.id, neighborhood: scope, shownIDs: [entity.id], positions: points) == nil)
    #expect(throws: SynthesisError.self) {
      try studio.copyGraphToCanvas(
        worldID: world, neighborhood: nil, shownIDs: [], positions: points)
    }
    #expect(throws: SynthesisError.self) {
      try studio.copyGraphToCanvas(
        worldID: world, neighborhood: scope, shownIDs: [entity.id], positions: [:])
    }
    let newNeighbor = try store.createRecord(worldID: world, title: "Added later", kind: "entity")
    _ = try store.addRelation(
      worldID: world, source: entity.id, target: newNeighbor.id, label: "knows")
    #expect(throws: SynthesisError.self) {
      try studio.copyGraphToCanvas(
        worldID: world, neighborhood: scope, shownIDs: [entity.id], positions: points)
    }
    try store.archiveRecord(worldID: world, id: entity.id)
    #expect(throws: SynthesisError.self) {
      try studio.copyGraphToCanvas(
        worldID: world, neighborhood: scope, shownIDs: [entity.id], positions: points)
    }
    #expect(try store.boards(worldID: world, kind: "canvas").map(\.id) == baseline)
    #expect(studio.destination == .knowledge)
  }
}
