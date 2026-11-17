import Foundation
import Testing

@testable import SynthesisCore

struct ChronologyTests {
  @Test func reviewedHistoryResolvesParentsAndEventsInOneProposal() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "History")
    let lore = try store.createRecord(worldID: world.id, title: "Origin")
    let proposal = try #require(
      try store.stageProposal(
        worldID: world.id, conversationID: nil, messageID: nil,
        payload: [
          "changes": [
            ["action": "create_branch", "title": "Eastern history"],
            ["action": "create_period", "title": "First age", "lane": "Eastern history"],
            ["action": "add_event", "title": "Founding", "source": lore.id, "lane": "First age"],
          ]
        ]))
    #expect(proposal.changes.count == 3)
    #expect(try store.events(worldID: world.id).isEmpty)
    #expect(throws: (any Error).self) {
      try store.resolveChange(
        worldID: world.id, proposalID: proposal.id, changeID: proposal.changes[2].id, accept: true,
        confirmation: proposal.id)
    }
    for change in proposal.changes {
      try store.resolveChange(
        worldID: world.id, proposalID: proposal.id, changeID: change.id, accept: true,
        confirmation: proposal.id)
    }
    let lanes = try store.chronologyLanes(worldID: world.id)
    let branch = try #require(lanes.first { $0.name == "Eastern history" })
    let period = try #require(lanes.first { $0.name == "First age" })
    #expect(period.parentID == branch.id)
    let event = try #require(try store.events(worldID: world.id).first)
    #expect(try store.chronologyPlacements(worldID: world.id)[event.id] == period.id)
    #expect(try store.record(worldID: world.id, id: lore.id).canonical == nil)
  }

  @Test func emptyWorldEventCreatesDraftSourceAtomically() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "A beginning")
    let event = try store.saveChronologyEvent(
      worldID: world.id, id: nil, title: "The first dawn", date: "", source: nil, order: nil,
      laneID: nil)
    let source = try store.record(worldID: world.id, id: event.sourceID)
    #expect(source.title == event.title && source.kind == "lore" && source.state == "draft")
    #expect(source.canonical == nil && event.dateLabel == "unknown")
    #expect(try store.records(worldID: world.id).count == 1)
    #expect(throws: (any Error).self) {
      try store.saveChronologyEvent(
        worldID: world.id, id: "missing-event", title: "Must roll back", date: "", source: nil,
        order: nil, laneID: nil)
    }
    #expect(try store.records(worldID: world.id).count == 1)
    #expect(try store.events(worldID: world.id).count == 1)
  }

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
    let copiedEvent = try #require(try store.events(worldID: imported.id).first)
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

struct EventOrderTests {
  @Test func movingNumbersTheTimelineAndUndoRestoresIt() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Order")
    let source = try store.createRecord(worldID: world.id, title: "Annals")
    let a = try store.addEvent(worldID: world.id, title: "A", date: "", source: source.id)
    let b = try store.addEvent(worldID: world.id, title: "B", date: "", source: source.id)
    let c = try store.addEvent(worldID: world.id, title: "C", date: "", source: source.id)
    #expect(try store.events(worldID: world.id).map(\.id) == [a.id, b.id, c.id])
    let previous = try store.moveEvent(worldID: world.id, id: c.id, by: -1)
    #expect(try store.events(worldID: world.id).map(\.id) == [a.id, c.id, b.id])
    #expect(try store.events(worldID: world.id).map(\.order) == [1, 2, 3])
    // Moving past either end changes nothing.
    _ = try store.moveEvent(worldID: world.id, id: a.id, by: -1)
    #expect(try store.events(worldID: world.id).map(\.id) == [a.id, c.id, b.id])
    try store.restoreEventOrder(worldID: world.id, previous: previous)
    #expect(try store.events(worldID: world.id).map(\.id) == [a.id, b.id, c.id])
    #expect(try store.events(worldID: world.id).allSatisfy { $0.order == nil })
  }
}
