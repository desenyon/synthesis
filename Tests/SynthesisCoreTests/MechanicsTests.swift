import Foundation
import Testing

@testable import SynthesisCore

struct MechanicsTests {
  @Test func approvedMechanicsStayDraftsAndRejectDocumentParents() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Mechanics")
    let entity = try store.createRecord(worldID: world.id, title: "Remembrance", kind: "entity")
    let rule = try store.addRule(
      worldID: world.id, systemID: entity.id, kind: .cost, title: "Price", body: "One memory")
    _ = try store.promoteRule(worldID: world.id, id: rule.id, confirmation: rule.id)
    let proposal = try #require(
      try store.stageProposal(
        worldID: world.id, conversationID: nil, messageID: nil,
        payload: [
          "changes": [
            ["action": "revise_rule", "id": rule.id, "body": "A willing memory"]
          ]
        ]))
    _ = try store.resolveChange(
      worldID: world.id, proposalID: proposal.id, changeID: proposal.changes[0].id,
      accept: true, confirmation: proposal.id)
    let changed = try store.rule(worldID: world.id, id: rule.id)
    #expect(changed.state == "draft" && changed.body == "A willing memory")
    #expect(changed.accepted?.body == "One memory")
    let invalid = try #require(
      try store.stageProposal(
        worldID: world.id, conversationID: nil, messageID: nil,
        payload: [
          "changes": [
            ["action": "create_record", "title": "A notebook", "kind": "lore", "body": "Notes"],
            [
              "action": "add_rule", "source": "A notebook", "title": "Price", "kind": "cost",
              "body": "A memory",
            ],
            [
              "action": "add_scenario", "source": "A notebook", "title": "Cross",
              "expectation": "unclear", "body": "A crossing",
            ],
          ]
        ]))
    #expect(invalid.changes.count == 1)
  }
  @Test func ruleHistoryPreservesEarlierCanonAndRoundTrips() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Mechanics")
    let entity = try store.createRecord(worldID: world.id, title: "Remembrance", kind: "entity")
    var rule = try store.addRule(
      worldID: world.id, systemID: entity.id, kind: .cost, title: "Price", body: "One memory")
    rule = try store.promoteRule(worldID: world.id, id: rule.id, confirmation: rule.id)
    _ = try store.updateRule(
      worldID: world.id, id: rule.id, kind: .cost, title: rule.title, body: "Two memories")
    _ = try store.promoteRule(worldID: world.id, id: rule.id, confirmation: rule.id)
    #expect(throws: (any Error).self) {
      try store.promoteRule(worldID: world.id, id: rule.id, confirmation: rule.id, expected: rule)
    }
    let history = try store.ruleHistory(worldID: world.id, id: rule.id)
    #expect(history.contains { $0.state == "canon" && $0.accepted?.body == "One memory" })
    #expect(history.first?.accepted?.body == "Two memories")
    #expect(throws: (any Error).self) {
      try store.updateRule(worldID: world.id, id: rule.id, kind: .cost, title: "", body: "invalid")
    }
    #expect(try store.ruleHistory(worldID: world.id, id: rule.id).count == history.count)
    let copy = try store.importWorldArchive(store.exportWorldArchive(worldID: world.id))
    let copiedEntity = try #require(try store.records(worldID: copy.id).first)
    let copiedRule = try #require(
      try store.rules(worldID: copy.id, systemID: copiedEntity.id).first)
    let copiedHistory = try store.ruleHistory(worldID: copy.id, id: copiedRule.id)
    #expect(copiedHistory.count == history.count)
    #expect(
      copiedHistory.allSatisfy {
        $0.worldID == copy.id && $0.systemID == copiedEntity.id && $0.id == copiedRule.id
      })
    try store.setRuleArchived(worldID: world.id, id: rule.id, archived: true)
    #expect(throws: (any Error).self) {
      try store.promoteRule(worldID: world.id, id: rule.id, confirmation: rule.id)
    }
  }
  @Test func reviewedRulesRejectStaleProposalsAndScenariosDoNotInventVerdicts() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Mechanics")
    let entity = try store.createRecord(worldID: world.id, title: "Remembrance", kind: "entity")
    let rule = try store.addRule(
      worldID: world.id, systemID: entity.id, kind: .cost, title: "Price", body: "One memory")
    let proposal = try #require(
      try store.stageProposal(
        worldID: world.id, conversationID: nil, messageID: nil,
        payload: [
          "changes": [
            ["action": "revise_rule", "id": rule.id, "body": "Two memories"],
            [
              "action": "add_scenario", "source": entity.id, "title": "Borrow tomorrow",
              "body": "Mira tries to remember a day not yet lived.", "expectation": "fails",
            ],
          ]
        ]))
    #expect(proposal.changes.count == 2)
    #expect(try store.scenarios(worldID: world.id, systemID: entity.id).isEmpty)
    #expect(throws: (any Error).self) {
      try store.resolveChange(
        worldID: world.id, proposalID: proposal.id, changeID: proposal.changes[0].id, accept: true,
        confirmation: "")
    }
    _ = try store.updateRule(
      worldID: world.id, id: rule.id, kind: .cost, title: "Price", body: "A willing memory")
    #expect(throws: (any Error).self) {
      try store.resolveChange(
        worldID: world.id, proposalID: proposal.id, changeID: proposal.changes[0].id, accept: true,
        confirmation: proposal.id)
    }
    _ = try store.resolveChange(
      worldID: world.id, proposalID: proposal.id, changeID: proposal.changes[1].id, accept: true,
      confirmation: proposal.id)
    let scenario = try #require(try store.scenarios(worldID: world.id, systemID: entity.id).first)
    #expect(scenario.verdict.isEmpty && scenario.expectation == "fails")
    #expect(try store.workspaceContext(worldID: world.id).contains(scenario.title))
    try store.archiveRecord(worldID: world.id, id: entity.id)
    #expect(throws: (any Error).self) {
      try store.saveScenario(
        worldID: world.id, systemID: entity.id, title: "Archived", situation: "",
        expectation: "unclear")
    }
    #expect(throws: (any Error).self) {
      try store.addRule(
        worldID: world.id, systemID: entity.id, kind: .cost, title: "Archived", body: "")
    }
  }
}
