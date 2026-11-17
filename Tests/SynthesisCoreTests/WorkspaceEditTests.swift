import Foundation
import Testing

@testable import SynthesisCore

struct WorkspaceEditTests {
  @Test func invalidChangesAreDisclosedAndForeignWorkspaceEditsAreRejected() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Active")
    let other = try store.createWorld(name: "Other")
    let foreign = try store.createChronologyLane(
      worldID: other.id, name: "Private history", kind: "branch")
    let proposal = try #require(
      try store.stageProposal(
        worldID: world.id, conversationID: nil, messageID: nil,
        payload: [
          "changes": [
            ["action": "create_record", "title": "Valid draft"],
            ["action": "revise_lane", "id": foreign.id, "title": "Must not happen"],
            ["action": "delete_everything"],
          ]
        ]))
    #expect(proposal.changes.count == 1)
    #expect(proposal.summary.contains("2 unsupported or invalid changes were not staged"))
    #expect(try store.chronologyLanes(worldID: other.id).first?.name == "Private history")
    #expect(try store.records(worldID: world.id).isEmpty)
  }
  @Test func pendingWorkspaceEditsRemainScopedAfterWorldArchiveImport() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let original = try store.createWorld(name: "Original")
    let lane = try store.createChronologyLane(worldID: original.id, name: "Old era", kind: "period")
    let event = try store.saveChronologyEvent(
      worldID: original.id, id: nil, title: "Old event", date: "", source: nil, order: nil,
      laneID: lane.id)
    _ = try store.stageProposal(
      worldID: original.id, conversationID: nil, messageID: nil,
      payload: [
        "changes": [
          ["action": "revise_event", "id": event.id, "title": "Imported event", "lane": lane.id],
          ["action": "revise_lane", "id": lane.id, "title": "Imported era"],
        ]
      ])
    let copy = try store.importWorldArchive(store.exportWorldArchive(worldID: original.id))
    let proposal = try #require(store.proposals(worldID: copy.id).first)
    for change in proposal.changes {
      #expect(change.recordID != event.id && change.recordID != lane.id)
      _ = try store.resolveChange(
        worldID: copy.id, proposalID: proposal.id, changeID: change.id, accept: true,
        confirmation: proposal.id)
    }
    #expect(try store.events(worldID: copy.id).first?.title == "Imported event")
    #expect(try store.chronologyLanes(worldID: copy.id).first?.name == "Imported era")
    #expect(try store.events(worldID: original.id).first?.title == "Old event")
    #expect(try store.chronologyLanes(worldID: original.id).first?.name == "Old era")
  }
  @Test func historyEditsRejectCyclesForeignParentsAndStaleEditors() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "History")
    let other = try store.createWorld(name: "Other")
    let root = try store.createChronologyLane(worldID: world.id, name: "Root", kind: "branch")
    let child = try store.createChronologyLane(
      worldID: world.id, name: "Child", kind: "period", parentID: root.id)
    let foreign = try store.createChronologyLane(worldID: other.id, name: "Foreign", kind: "branch")
    for parent in [child.id, foreign.id] {
      #expect(throws: (any Error).self) {
        try store.updateChronologyLane(
          worldID: world.id, expected: root, name: "Bad move", parentID: parent, start: "", end: "",
          notes: "")
      }
    }
    try store.updateChronologyLane(
      worldID: world.id, expected: root, name: "Renamed", parentID: nil, start: "Before",
      end: "After", notes: "Kept")
    #expect(throws: (any Error).self) {
      try store.updateChronologyLane(
        worldID: world.id, expected: root, name: "Stale", parentID: nil, start: "", end: "",
        notes: "")
    }
    #expect(try store.chronologyLanes(worldID: world.id).first?.name == "Renamed")
  }
  @Test func reviewedWorkspaceEditsChangeExistingStructuresAndRejectStaleSnapshots() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Edits")
    let a = try store.createRecord(worldID: world.id, title: "A", kind: "entity")
    let b = try store.createRecord(worldID: world.id, title: "B", kind: "entity")
    let lane = try store.createChronologyLane(worldID: world.id, name: "Old era", kind: "period")
    let event = try store.saveChronologyEvent(
      worldID: world.id, id: nil, title: "Old event", date: "", source: a.id, order: 7, laneID: nil)
    let map = try store.saveAtlasMap(
      worldID: world.id, name: "Old map", content: #"{"image":"preserve","markers":[]}"#)
    let relation = try store.addRelation(
      worldID: world.id, source: a.id, target: b.id, label: "knows")
    let payload: [String: Any] = [
      "changes": [
        ["action": "revise_event", "id": event.id, "title": "New event", "lane": lane.id],
        ["action": "revise_lane", "id": lane.id, "title": "New era", "date": "Dawn"],
        ["action": "revise_map", "id": map.id, "title": "New map", "source": b.id],
        ["action": "revise_relationship", "id": relation.id, "label": "trusts"],
      ]
    ]
    let proposal = try #require(
      try store.stageProposal(
        worldID: world.id, conversationID: nil, messageID: nil, payload: payload))
    #expect(proposal.changes.count == 4)
    #expect(try store.events(worldID: world.id).first?.title == "Old event")
    for change in proposal.changes {
      _ = try store.resolveChange(
        worldID: world.id, proposalID: proposal.id, changeID: change.id, accept: true,
        confirmation: proposal.id)
    }
    #expect(try store.events(worldID: world.id).first?.title == "New event")
    #expect(try store.events(worldID: world.id).first?.order == 7)
    #expect(try store.chronologyPlacements(worldID: world.id)[event.id] == lane.id)
    #expect(try store.chronologyLanes(worldID: world.id).first?.name == "New era")
    #expect(try store.relations(worldID: world.id).first?.label == "trusts")
    let savedMap = try store.board(worldID: world.id, id: map.id, kind: "atlas")
    #expect(savedMap.name == "New map" && savedMap.content.contains("preserve"))
    #expect(try AtlasLinks(content: savedMap.content).placeID == b.id)
    #expect(try store.record(worldID: world.id, id: a.id) == a)
    let stale = try #require(
      try store.stageProposal(
        worldID: world.id, conversationID: nil, messageID: nil, payload: payload))
    try store.updateRelation(worldID: world.id, id: relation.id, label: "creator edit")
    let change = try #require(stale.changes.last)
    #expect(throws: (any Error).self) {
      try store.resolveChange(
        worldID: world.id, proposalID: stale.id, changeID: change.id, accept: true,
        confirmation: stale.id)
    }
    #expect(try store.relations(worldID: world.id).first?.label == "creator edit")
  }
}
