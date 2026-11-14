import Foundation
import SwiftFlow
import SynthesisCore
import Testing

@testable import SynthesisUI

struct GraphEngineTests {
  @Test func projectionExcludesOtherWorldsDocumentsAndDanglingEdges() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "One")
    let other = try store.createWorld(name: "Two")
    let a = try store.createRecord(worldID: world.id, title: "A", kind: "entity")
    let b = try store.createRecord(worldID: world.id, title: "B", kind: "entity")
    let foreign = try store.createRecord(worldID: other.id, title: "Foreign", kind: "entity")
    let doc = try store.createRecord(worldID: world.id, title: "Document")
    let edge = try store.addRelation(worldID: world.id, source: a.id, target: b.id, label: "knows")
    let foreign2 = try store.createRecord(worldID: other.id, title: "Foreign 2", kind: "entity")
    let foreignEdge = try store.addRelation(
      worldID: other.id, source: foreign.id, target: foreign2.id, label: "hidden")
    let graph = GraphEngine.project(
      worldID: world.id, records: [a, b, foreign, foreign2, doc],
      relationships: [edge, foreignEdge])
    #expect(Set(graph.nodes.map(\.id)) == [a.id, b.id])
    #expect(graph.edges.map(\.id) == [edge.id])
    #expect(graph.edges.first?.label == "knows")
    #expect(graph.nodes.allSatisfy { !$0.deletable && !$0.draggable })
    #expect(graph.edges.allSatisfy { !$0.deletable && !$0.reconnectable })
    #expect(GraphEngine.canConnect(Connection(source: a.id, target: b.id), in: graph))
    #expect(!GraphEngine.canConnect(Connection(source: a.id, target: a.id), in: graph))
    #expect(!GraphEngine.canConnect(Connection(source: a.id, target: foreign.id), in: graph))
  }
  @Test func cyclicGraphHasFiniteDistinctLayoutAndStableReferences() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Cycle")
    let a = try store.createRecord(worldID: world.id, title: "A", kind: "entity")
    let b = try store.createRecord(worldID: world.id, title: "B", kind: "entity")
    let c = try store.createRecord(worldID: world.id, title: "Unrelated", kind: "entity")
    let ab = try store.addRelation(worldID: world.id, source: a.id, target: b.id, label: "knows")
    let ba = try store.addRelation(worldID: world.id, source: b.id, target: a.id, label: "trusts")
    let graph = GraphEngine.project(
      worldID: world.id, records: [a, b, c], relationships: [ab, ba])
    #expect(graph.nodes.allSatisfy { $0.position.x.isFinite && $0.position.y.isFinite })
    #expect(Set(graph.nodes.map { "\($0.position.x):\($0.position.y)" }).count == 3)
    let doc = GraphEngine.canvasDocument(from: graph, selected: a.id)
    #expect(Set(doc.cards.compactMap(\.recordID)) == [a.id, b.id])
    #expect(doc.edges.isEmpty)  // Semantic links stay in the relationship table.
    #expect(doc.cards[0].id != doc.cards[1].id)
    #expect(try store.record(worldID: world.id, id: a.id).version == 1)
    #expect(try store.relations(worldID: world.id).count == 2)
  }
  @MainActor @Test func engineArrangeIsExplicitUndoableAndPersists() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let studio = try Studio(store: store)
    let a = try store.createRecord(worldID: studio.worldID, title: "A", kind: "entity")
    let b = try store.createRecord(worldID: studio.worldID, title: "B", kind: "entity")
    _ = try store.addRelation(worldID: studio.worldID, source: a.id, target: b.id, label: "follows")
    let board = BoardController(studio: studio)
    board.load()
    board.add(a)
    board.add(b)
    let before = board.document.cards
    board.autoLayout()
    #expect(board.document.cards != before)
    let reopened = BoardController(studio: studio)
    reopened.load()
    #expect(reopened.document.cards == board.document.cards)
    board.step(back: true)
    #expect(board.document.cards == before)
    #expect(try store.relations(worldID: studio.worldID).count == 1)
  }
}
