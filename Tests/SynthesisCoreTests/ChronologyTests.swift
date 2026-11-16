import Foundation
import Testing

@testable import SynthesisCore

struct ChronologyTests {
  @Test func branchesPeriodsAndSourcedEventsSurvivePortableRoundTrip() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "History")
    let source = try store.createRecord(
      worldID: world.id, title: "The founding", body: "Uncertain dates")
    let branch = try store.createChronologyLane(
      worldID: world.id, name: "The other crossing", kind: "branch")
    let period = try store.createChronologyLane(
      worldID: world.id, name: "Age of glass", kind: "period", parentID: branch.id,
      start: "Before the crossing", end: "unknown")
    let event = try store.saveChronologyEvent(
      worldID: world.id, id: nil, title: "The founding", date: "First winter", source: source.id,
      order: 1, laneID: period.id)
    #expect(try store.chronologyPlacements(worldID: world.id)[event.id] == period.id)
    let imported = try store.importWorldArchive(store.exportWorldArchive(worldID: world.id))
    let lanes = try store.chronologyLanes(worldID: imported.id)
    let copiedPeriod = try #require(lanes.first { $0.kind == "period" })
    #expect(copiedPeriod.parentID == lanes.first { $0.kind == "branch" }?.id)
    #expect(copiedPeriod.start == "Before the crossing")
    let copiedEvent = try #require(store.events(worldID: imported.id).first)
    #expect(try store.chronologyPlacements(worldID: imported.id)[copiedEvent.id] == copiedPeriod.id)
    try store.setChronologyLaneArchived(worldID: world.id, id: period.id, archived: true)
    #expect(try store.chronologyLanes(worldID: world.id).count == 1)
    #expect(try store.events(worldID: world.id).count == 1)
    try store.setChronologyLaneArchived(worldID: world.id, id: period.id, archived: false)
    #expect(try store.chronologyLanes(worldID: world.id).count == 2)
  }
  @Test func foreignBranchCannotCreatePartialEvent() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "One")
    let other = try store.createWorld(name: "Two")
    let source = try store.createRecord(worldID: world.id, title: "Source")
    let foreign = try store.createChronologyLane(
      worldID: other.id, name: "Other history", kind: "branch")
    #expect(throws: (any Error).self) {
      try store.saveChronologyEvent(
        worldID: world.id, id: nil, title: "Forbidden", date: "", source: source.id, order: nil,
        laneID: foreign.id)
    }
    #expect(try store.events(worldID: world.id).isEmpty)
  }
}

struct ChronologyAgentTests {
  @Test func chronologyChangesWaitForExplicitReview() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "History")
    let proposal = try #require(
      try store.stageProposal(
        worldID: world.id, conversationID: nil, messageID: nil,
        payload: [
          "changes": [
            [
              "action": "create_period", "title": "The silent age", "date": "Before the bells",
              "endDate": "Uncertain", "body": "A suggested era",
            ]
          ]
        ]))
    #expect(try store.chronologyLanes(worldID: world.id).isEmpty)
    #expect(throws: (any Error).self) {
      try store.resolveChange(
        worldID: world.id, proposalID: proposal.id, changeID: proposal.changes[0].id, accept: true,
        confirmation: "")
    }
    _ = try store.resolveChange(
      worldID: world.id, proposalID: proposal.id, changeID: proposal.changes[0].id, accept: true,
      confirmation: proposal.id)
    let period = try #require(store.chronologyLanes(worldID: world.id).first)
    #expect(period.start == "Before the bells")
    #expect(period.end == "Uncertain")
    #expect(period.notes == "A suggested era")
    #expect(try store.workspaceContext(worldID: world.id).contains(period.id))
  }
}
