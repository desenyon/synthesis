import Foundation
import SynthesisCore
import Testing

@testable import SynthesisUI

@MainActor struct OperationFeedbackTests {
  @Test func reviewedBatchReportsCommittedChangesAndPreservesCanon() async throws {
    let store = try WorkspaceStore(path: ":memory:")
    let studio = try Studio(store: store)
    studio.setMode(.manual)
    let proposal = try #require(
      try store.stageProposal(
        worldID: studio.worldID, conversationID: nil, messageID: nil,
        payload: [
          "changes": [
            ["action": "create_record", "title": "First", "kind": "entity"],
            ["action": "create_record", "title": "Second", "kind": "entity"],
          ]
        ]))
    studio.resolveAll(proposal, accept: true)
    #expect(studio.reviewProgress?.phase == .waiting)
    while studio.reviewingProposal { await Task.yield() }
    let progress = try #require(studio.reviewProgress)
    #expect(progress.completed == 2 && progress.total == 2 && progress.phase == .complete)
    #expect(progress.feedback.fraction == 1)
    #expect(studio.records.allSatisfy { $0.canonical == nil })
    #expect(studio.mode == .manual)
  }

  @Test func failedBatchReportsZeroAndLeavesEveryDecisionPending() async throws {
    let store = try WorkspaceStore(path: ":memory:")
    let studio = try Studio(store: store)
    let record = try store.createRecord(worldID: studio.worldID, title: "Source", body: "Old")
    let proposal = try #require(
      try store.stageProposal(
        worldID: studio.worldID, conversationID: nil, messageID: nil,
        payload: [
          "changes": [
            ["action": "create_record", "title": "First", "kind": "entity"],
            ["action": "revise_record", "id": record.id, "body": "Proposed"],
          ]
        ]))
    _ = try store.saveRecord(
      worldID: studio.worldID, id: record.id, version: record.version,
      title: record.title, body: "Newer human writing", rtf: nil)
    studio.resolveAll(proposal, accept: true)
    while studio.reviewingProposal { await Task.yield() }
    #expect(studio.reviewProgress?.completed == 0 && studio.reviewProgress?.phase == .failed)
    #expect(studio.reviewProgress?.feedback.fraction == 0 && studio.error != nil)
    #expect(studio.pendingProposals.first?.pending == 2)
    #expect(try store.record(worldID: studio.worldID, id: record.id).body == "Newer human writing")
    #expect(!studio.records.contains { $0.title == "First" })
    #expect(try store.search(worldID: studio.worldID, query: "First").isEmpty)
  }

  @Test func changingWorldBeforeReviewCannotApplyDecisionsIntoEitherWorld() async throws {
    let store = try WorkspaceStore(path: ":memory:")
    let studio = try Studio(store: store)
    let original = studio.worldID
    let other = try store.createWorld(name: "Elsewhere")
    let proposal = try #require(
      try store.stageProposal(
        worldID: original, conversationID: nil, messageID: nil,
        payload: ["changes": [["action": "create_record", "title": "Stop before applying"]]]))
    studio.resolveAll(proposal, accept: true)
    studio.switchWorld(other.id)
    while studio.reviewingProposal { await Task.yield() }
    #expect(studio.reviewProgress?.phase == .cancelled && studio.reviewProgress?.completed == 0)
    #expect(studio.reviewProgress?.worldID == original && studio.worldID == other.id)
    #expect(try store.records(worldID: original).isEmpty)
    #expect(try store.records(worldID: other.id).isEmpty)
  }

  @Test func activityErrorsAndCancellationsNeverBecomeSuccessLabels() {
    let ready = AgentActivity(id: "lore", title: "Context ready", state: .complete)
    let failed = AgentActivity(id: "response", title: "Connection ended", state: .failed)
    #expect(ActivitySummary([ready, failed]).state == .failed)
    #expect(ActivitySummary([ready, failed]).title == "Connection ended")
    let cancelled = AgentActivity(id: "response", title: "Stopped", state: .cancelled)
    #expect(ActivitySummary([ready, cancelled]).state == .cancelled)
    #expect(ActivitySummary([]).state == .running)
  }

  @Test func successfulSaveIncludesTheSearchIndexAndFailedSaveDoesNotReplaceIt() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "World")
    let record = try store.createRecord(worldID: world.id, title: "Navigator", body: "Oldword")
    let saved = try store.saveRecord(
      worldID: world.id, id: record.id, version: record.version,
      title: record.title, body: "Newword", rtf: nil)
    #expect(try store.search(worldID: world.id, query: "Newword").map(\.id) == [record.id])
    #expect(try store.search(worldID: world.id, query: "Oldword").isEmpty)
    #expect(throws: (any Error).self) {
      try store.saveRecord(
        worldID: world.id, id: record.id, version: record.version,
        title: record.title, body: "Rejectedword", rtf: nil)
    }
    #expect(try store.search(worldID: world.id, query: "Rejectedword").isEmpty)
    #expect(try store.record(worldID: world.id, id: record.id) == saved)
  }
}
