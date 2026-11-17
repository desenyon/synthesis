import Foundation
import SynthesisCore
import Testing

@testable import SynthesisUI

@MainActor struct InspectionTests {
  @Test func dockedInspectorKeepsCanvasHiddenBehindCompanionTakeover() throws {
    let studio = try Studio(store: WorkspaceStore(path: ":memory:"))
    studio.destination = .canvas
    studio.mode = .assisted
    studio.companionExpanded = true
    #expect(studio.canvasVisible(windowWidth: 1440))
    studio.workspaceInspector = true
    #expect(!studio.canvasVisible(windowWidth: 1440))
    #expect(studio.canvasVisible(windowWidth: 1920))
    studio.companionExpanded = false
    #expect(studio.canvasVisible(windowWidth: 1440))
    #expect(studio.canvasVisible(windowWidth: 1024))
  }
  @Test func inspectionPreservesTheWorkspaceAndCannotCrossUniverses() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let studio = try Studio(store: store)
    let world = studio.worldID
    let a = try store.createRecord(worldID: world, title: "Mira", kind: "entity")
    let b = try store.createRecord(worldID: world, title: "Tidekeepers", kind: "entity")
    let other = try store.createWorld(name: "Private other universe")
    let foreign = try store.createRecord(worldID: other.id, title: "Foreign", kind: "entity")
    try studio.reload()
    studio.navigate(.knowledge)
    studio.graphSelectedID = a.id
    studio.setMode(.manual)
    studio.editorSave = { false }
    studio.inspect(.record(b.id))
    #expect(studio.destination == .knowledge && studio.graphSelectedID == a.id)
    #expect(studio.workspaceInspector && studio.effectiveInspection == .record(b.id))
    #expect(studio.selectedRecord == nil && !studio.flushEditor())
    #expect(try store.record(worldID: world, id: b.id) == b)
    #expect(throws: SynthesisError.self) { try studio.inspectionData(for: .record(foreign.id)) }
    studio.graphSelectedID = b.id
    #expect(studio.inspectionTarget == nil && studio.effectiveInspection == .record(b.id))
    studio.toggleWorkspaceInspector()
    #expect(!studio.workspaceInspector && studio.graphSelectedID == b.id)
    studio.toggleWorkspaceInspector()
    let reopened = try Studio(store: store)
    #expect(reopened.workspaceInspector)
    studio.editorSave = nil
    studio.switchWorld(other.id)
    #expect(studio.inspectionTarget == nil && studio.effectiveInspection == .world)
    #expect(throws: SynthesisError.self) { try studio.inspectionData(for: .record(a.id)) }
  }

  @Test func inspectorProjectsSavedRelationshipsHistoryMapsAndProposals() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let studio = try Studio(store: store)
    let world = studio.worldID
    let a = try store.createRecord(worldID: world, title: "Mira", kind: "entity")
    let b = try store.createRecord(worldID: world, title: "Harbour", kind: "entity")
    let edge = try store.addRelation(worldID: world, source: a.id, target: b.id, label: "maps")
    let lane = try store.createChronologyLane(worldID: world, name: "Glass age", kind: "period")
    let event = try store.saveChronologyEvent(
      worldID: world, id: nil, title: "First chart", date: "Year 12", source: a.id, order: nil,
      laneID: lane.id)
    let map = try store.createAtlasMap(worldID: world, name: "Harbour map", placeID: b.id)
    let board = try store.saveBoard(
      worldID: world, name: "Research", kind: "canvas",
      content:
        "{\"cards\":[{\"id\":\"card\",\"text\":\"Mira\",\"recordID\":\"\(a.id)\",\"x\":0,\"y\":0,\"width\":230,\"height\":160}],\"edges\":[]}"
    )
    let chat = try store.createConversation(worldID: world, title: "The coast")
    let proposal = try #require(
      try store.stageProposal(
        worldID: world, conversationID: chat.id, messageID: nil,
        payload: [
          "summary": "A possibility",
          "changes": [
            ["action": "create_record", "title": "Island", "kind": "entity", "evidence": [a.id]]
          ],
        ]))
    try studio.reload()
    let record = try studio.inspectionData(for: .record(a.id))
    #expect(record.references.contains { $0.target == .record(b.id) && $0.detail == "maps" })
    #expect(record.references.contains { $0.target == .event(event.id) })
    #expect(
      try studio.inspectionData(for: .event(event.id)).references.contains {
        $0.target == .lane(lane.id)
      })
    #expect(
      try studio.inspectionData(for: .lane(lane.id)).references.contains {
        $0.target == .event(event.id)
      })
    #expect(
      try studio.inspectionData(for: .board(map.id, kind: "atlas")).references.contains {
        $0.target == .record(b.id)
      })
    #expect(
      try studio.inspectionData(for: .board(board.id, kind: "canvas")).references.contains {
        $0.target == .record(a.id)
      })
    #expect(try studio.inspectionData(for: .relationship(edge.id)).references.count == 2)
    #expect(try studio.inspectionData(for: .conversation(chat.id)).title == "The coast")
    #expect(
      try studio.inspectionData(for: .proposal(proposal.id)).references.contains {
        $0.target == .record(a.id)
      })
    #expect(try store.proposal(worldID: world, id: proposal.id).pending == 1)
    try store.archiveRecord(worldID: world, id: a.id)
    try studio.reload()
    #expect(throws: SynthesisError.self) { try studio.inspectionData(for: .record(a.id)) }
    let foreign = try store.createWorld(name: "Other")
    studio.switchWorld(foreign.id)
    for target: InspectionTarget in [
      .event(event.id), .lane(lane.id), .board(map.id, kind: "atlas"), .relationship(edge.id),
      .conversation(chat.id), .proposal(proposal.id),
    ] {
      #expect(throws: SynthesisError.self) { try studio.inspectionData(for: target) }
    }
  }
}
