import Foundation
import Testing

@testable import SynthesisCore

struct TechniqueTreeTests {
  @Test func prerequisitesRejectLoopsAndOtherSystemsAndArchiveRemovals() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Tree")
    let system = try store.createRecord(
      worldID: world.id, title: "Remembrance", kind: "entity", category: "Power systems")
    let other = try store.createRecord(
      worldID: world.id, title: "Tidecraft", kind: "entity", category: "Power systems")
    func technique(_ title: String, in id: String) throws -> WorldRule {
      try store.addRule(worldID: world.id, systemID: id, kind: .technique, title: title, body: "x")
    }
    let a = try technique("Recall", in: system.id)
    let b = try technique("Tide sight", in: system.id)
    let c = try technique("Drowned chart", in: system.id)
    let foreign = try technique("Wave step", in: other.id)

    try store.setPrerequisites(worldID: world.id, ruleID: b.id, requires: [a.id])
    try store.setPrerequisites(worldID: world.id, ruleID: c.id, requires: [a.id, b.id])
    #expect(try store.prerequisites(worldID: world.id, systemID: system.id).count == 3)

    #expect(throws: SynthesisError.self) {
      try store.setPrerequisites(worldID: world.id, ruleID: a.id, requires: [c.id])
    }
    #expect(throws: SynthesisError.self) {
      try store.setPrerequisites(worldID: world.id, ruleID: a.id, requires: [foreign.id])
    }
    #expect(try store.prerequisites(worldID: world.id, systemID: system.id).count == 3)

    // Removing a requirement archives the edge; re-adding it restores the same row.
    try store.setPrerequisites(worldID: world.id, ruleID: c.id, requires: [b.id])
    #expect(try store.prerequisites(worldID: world.id, systemID: system.id).count == 2)
    #expect(
      try store.db.rows("SELECT * FROM rule_prerequisites WHERE archived=1").count == 1)
    try store.setPrerequisites(worldID: world.id, ruleID: c.id, requires: [a.id, b.id])
    #expect(try store.db.rows("SELECT * FROM rule_prerequisites").count == 3)

    // An archived rule drops out of the tree without losing its edges.
    try store.setRuleArchived(worldID: world.id, id: a.id, archived: true)
    #expect(try store.prerequisites(worldID: world.id, systemID: system.id).count == 1)
  }

  @Test func dormantPrerequisitesPreventLoopsAndSurviveEdits() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Tree")
    let system = try store.createRecord(
      worldID: world.id, title: "Remembrance", kind: "entity", category: "Power systems")
    func step(_ title: String) throws -> WorldRule {
      try store.addRule(
        worldID: world.id, systemID: system.id, kind: .technique, title: title, body: "Original")
    }
    let a = try step("Recall")
    let b = try step("Tide sight")
    let c = try step("Drowned chart")
    try store.setPrerequisites(worldID: world.id, ruleID: a.id, requires: [b.id])
    try store.setPrerequisites(worldID: world.id, ruleID: b.id, requires: [c.id])
    try store.setRuleArchived(worldID: world.id, id: b.id, archived: true)
    #expect(try store.prerequisites(worldID: world.id, systemID: system.id).isEmpty)

    #expect(throws: SynthesisError.self) {
      try store.setPrerequisites(worldID: world.id, ruleID: c.id, requires: [a.id])
    }
    #expect(throws: SynthesisError.self) {
      try store.setPrerequisites(worldID: world.id, ruleID: b.id, requires: [])
    }
    #expect(throws: SynthesisError.self) {
      try store.setPrerequisites(worldID: world.id, ruleID: c.id, requires: [b.id])
    }
    // The editor submits only visible prerequisites. Text edits must retain dormant edges.
    _ = try store.saveRule(
      worldID: world.id, systemID: system.id, existing: a, kind: .technique,
      title: a.title, body: "Edited", requires: [])
    try store.setRuleArchived(worldID: world.id, id: b.id, archived: false)
    let edges = Set(try store.prerequisites(worldID: world.id, systemID: system.id))
    #expect(
      edges == [
        RulePrerequisite(ruleID: a.id, requiresID: b.id),
        RulePrerequisite(ruleID: b.id, requiresID: c.id),
      ])
  }

  @Test func saveRuleIsAtomicAndTreeSurvivesPortableCopy() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Tree")
    let system = try store.createRecord(
      worldID: world.id, title: "Remembrance", kind: "entity", category: "Power systems")
    let a = try store.saveRule(
      worldID: world.id, systemID: system.id, existing: nil, kind: .progression,
      title: "First surrender", body: "x", requires: [])
    let b = try store.saveRule(
      worldID: world.id, systemID: system.id, existing: nil, kind: .technique, title: "Recall",
      body: "y", requires: [a.id])
    // A loop is rejected and the attempted rename is rolled back with it.
    #expect(throws: SynthesisError.self) {
      try store.saveRule(
        worldID: world.id, systemID: system.id, existing: a, kind: .progression,
        title: "Renamed", body: "x", requires: [b.id])
    }
    #expect(try store.rule(worldID: world.id, id: a.id).title == "First surrender")

    let copy = try store.importWorldArchive(try store.exportWorldArchive(worldID: world.id))
    let copied = try #require(try store.powerSystems(worldID: copy.id).first)
    let edges = try store.prerequisites(worldID: copy.id, systemID: copied.id)
    #expect(edges.count == 1)
    #expect(edges[0].ruleID != b.id)
    let rules = try store.rules(worldID: copy.id, systemID: copied.id)
    #expect(rules.first { $0.id == edges[0].ruleID }?.title == "Recall")
  }

  @Test func newPrerequisitesCannotAttachToAnExistingLoop() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Legacy tree")
    let system = try store.createRecord(worldID: world.id, title: "Remembrance", kind: "entity")
    func rule(_ title: String) throws -> WorldRule {
      try store.addRule(
        worldID: world.id, systemID: system.id, kind: .technique, title: title, body: "Example")
    }
    let a = try rule("Recall")
    let b = try rule("Tide sight")
    let c = try rule("Drowned chart")
    try store.setPrerequisites(worldID: world.id, ruleID: b.id, requires: [c.id])
    // Old world archives could contain a loop before this mutation is attempted.
    let now = timestamp()
    try store.db.execute(
      "INSERT INTO rule_prerequisites VALUES(?,?,?,?,0,?,?)",
      [
        UUID().uuidString, world.id, c.id, b.id, now, now,
      ])
    #expect(throws: SynthesisError.self) {
      try store.setPrerequisites(worldID: world.id, ruleID: a.id, requires: [b.id])
    }
    #expect(try store.prerequisites(worldID: world.id, systemID: system.id).count == 2)
  }
}
