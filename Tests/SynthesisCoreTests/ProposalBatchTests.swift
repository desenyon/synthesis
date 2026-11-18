import Testing

@testable import SynthesisCore

struct ProposalBatchTests {
  @Test func approvalAppliesExactSelectionInDependencyOrderAndPreservesCanon() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "The old coast")
    let court = try store.createRecord(worldID: world.id, title: "Court", kind: "entity")
    let accepted = try store.promote(
      worldID: world.id, id: court.id, version: court.version, confirmation: court.id)
    let proposal = try #require(
      try store.stageProposal(
        worldID: world.id, conversationID: nil, messageID: nil,
        payload: [
          "changes": [
            ["action": "create_record", "ref": "crew", "title": "Crew", "kind": "entity"],
            ["action": "relate", "source": "$crew", "target": court.id, "label": "reports to"],
            ["action": "create_record", "title": "Unselected"],
          ]
        ]))
    let creation = proposal.changes[0]
    let relationship = proposal.changes[1]
    for selection in [[relationship], [creation, creation]] {
      #expect(throws: SynthesisError.self) {
        try store.resolveChanges(
          worldID: world.id, proposalID: proposal.id, changes: selection, accept: true,
          confirmation: proposal.id)
      }
    }
    #expect(throws: SynthesisError.self) {
      try store.resolveChanges(
        worldID: world.id, proposalID: proposal.id, changes: [creation], accept: true,
        confirmation: "another proposal")
    }
    let otherWorld = try store.createWorld(name: "Another coast")
    #expect(throws: SynthesisError.self) {
      try store.resolveChanges(
        worldID: otherWorld.id, proposalID: proposal.id, changes: [creation], accept: true,
        confirmation: proposal.id)
    }
    #expect(try store.records(worldID: world.id) == [accepted])

    let resolved = try store.resolveChanges(
      worldID: world.id, proposalID: proposal.id, changes: [relationship, creation], accept: true,
      confirmation: proposal.id)
    let createdID = try #require(resolved.changes[0].resultID)
    let crew = try store.record(worldID: world.id, id: createdID)
    let edges = try store.relations(worldID: world.id)
    #expect(crew.title == "Crew" && crew.state == "draft" && crew.canonical == nil)
    #expect(edges.count == 1 && edges[0].sourceID == crew.id && edges[0].targetID == court.id)
    #expect(resolved.pending == 1 && resolved.changes[2] == proposal.changes[2])
    #expect(try store.record(worldID: world.id, id: court.id) == accepted)
    #expect(throws: SynthesisError.self) {
      try store.resolveChanges(
        worldID: world.id, proposalID: proposal.id, changes: [relationship, creation], accept: true,
        confirmation: proposal.id)
    }
    #expect(try store.records(worldID: world.id).count == 2)
  }

  @Test func aLateSaveFailureRollsBackEarlierDraftsSearchAndActivity() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "The old coast")
    let court = try store.createRecord(worldID: world.id, title: "Court", body: "Ancestor")
    let proposal = try #require(
      try store.stageProposal(
        worldID: world.id, conversationID: nil, messageID: nil,
        payload: [
          "changes": [
            ["action": "create_record", "title": "Rollback sentinel"],
            ["action": "revise_record", "id": court.id, "body": "Proposed court"],
          ]
        ]))
    let changed = try store.saveRecord(
      worldID: world.id, id: court.id, version: court.version, title: court.title,
      body: "Newer author revision", rtf: nil)
    let activity = try store.recentWorldActivity(worldID: world.id)
    #expect(throws: SynthesisError.self) {
      try store.resolveChanges(
        worldID: world.id, proposalID: proposal.id, changes: proposal.changes, accept: true,
        confirmation: proposal.id)
    }
    #expect(try store.records(worldID: world.id) == [changed])
    #expect(try store.search(worldID: world.id, query: "Rollback").isEmpty)
    #expect(try store.recentWorldActivity(worldID: world.id) == activity)
    #expect(try store.proposal(worldID: world.id, id: proposal.id) == proposal)
  }
}
