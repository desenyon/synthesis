import Foundation
import Testing

@testable import SynthesisCore

struct CreativeComponentTests {
  @Test func componentsPersistAndRoundTripWithoutCrossWorldReferences() throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
      .appendingPathComponent("world.sqlite").path
    defer {
      try? FileManager.default.removeItem(
        atPath: URL(fileURLWithPath: path).deletingLastPathComponent().path)
    }
    let store = try WorkspaceStore(path: path)
    let world = try store.createWorld(name: "Aster")
    let other = try store.createWorld(name: "Other")
    let entity = try store.createRecord(worldID: world.id, title: "Remembrance", kind: "entity")
    let item = try store.createCreativeComponent(
      worldID: world.id, scope: .entity, kind: .progression, parentID: entity.id, title: "Realms",
      body: "Listener\nKeeper\nWitness")
    for scope in CreativeScope.allCases where scope != .entity {
      try store.createCreativeComponent(
        worldID: world.id, scope: scope, kind: .notes, title: "Notes for \(scope.rawValue)")
    }
    let reopened = try WorkspaceStore(path: path)
    #expect(try reopened.creativeComponents(worldID: world.id).count == 8)
    #expect(try reopened.creativeComponents(worldID: other.id).isEmpty)
    #expect(
      try reopened.sectionParent(worldID: world.id, recordID: item.record.id)?.id == entity.id)
    #expect(
      try reopened.search(worldID: world.id, query: "Witness").contains { $0.id == item.record.id })
    #expect(throws: (any Error).self) {
      try store.createCreativeComponent(
        worldID: other.id, scope: .entity, kind: .facts, parentID: entity.id, title: "Invalid")
    }
    #expect(try store.records(worldID: other.id).isEmpty)
    let imported = try store.importWorldArchive(store.exportWorldArchive(worldID: world.id))
    let copies = try store.creativeComponents(worldID: imported.id)
    #expect(copies.count == 8)
    let copy = try #require(copies.first { $0.kind == .progression })
    #expect(copy.record.id != item.record.id && copy.parentID != entity.id)
    #expect(copy.record.body == item.record.body)
    let json = try #require(
      JSONSerialization.jsonObject(with: store.exportWorld(world.id)) as? [String: Any])
    #expect(json["schemaVersion"] as? Int == 18)
    #expect((json["creativeComponents"] as? [Any])?.count == 8)
    #expect(try store.workspaceContext(worldID: world.id).contains(item.record.id))
  }

  @Test func checklistRevisionsPreserveCanonAndRejectStaleOrForeignEdits() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Checklist")
    let other = try store.createWorld(name: "Other")
    let item = try store.createCreativeComponent(
      worldID: world.id, scope: .timeline, kind: .checklist, title: "Open history",
      body: "Introduction\n- [ ] Find the crossing\n  - [X] Read the ledger")
    let accepted = try store.promote(
      worldID: world.id, id: item.record.id, version: item.record.version,
      confirmation: item.record.id)
    try store.toggleCreativeCheck(
      worldID: world.id, id: item.id, version: accepted.version, line: 1)
    let edited = try store.record(worldID: world.id, id: item.record.id)
    #expect(edited.body == "Introduction\n- [x] Find the crossing\n  - [X] Read the ledger")
    #expect(edited.canonical == accepted.canonical)
    #expect(edited.state == "draft")
    #expect(throws: (any Error).self) {
      try store.toggleCreativeCheck(
        worldID: world.id, id: item.id, version: accepted.version, line: 2)
    }
    #expect(throws: (any Error).self) {
      try store.toggleCreativeCheck(
        worldID: other.id, id: item.id, version: edited.version, line: 2)
    }
    #expect(throws: (any Error).self) {
      try store.toggleCreativeCheck(
        worldID: world.id, id: item.id, version: edited.version, line: 0)
    }
    try store.setCreativeComponentArchived(worldID: world.id, id: item.id, archived: true)
    #expect(try store.creativeComponents(worldID: world.id).isEmpty)
    #expect(try store.record(worldID: world.id, id: item.record.id) == edited)
    try store.setCreativeComponentArchived(worldID: world.id, id: item.id, archived: false)
    #expect(try store.creativeComponents(worldID: world.id).count == 1)
  }

  @Test func proposalsValidatePresentationAndRequireExplicitApproval() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Review")
    let entity = try store.createRecord(worldID: world.id, title: "Tidekeepers", kind: "entity")
    let proposal = try #require(
      try store.stageProposal(
        worldID: world.id, conversationID: nil, messageID: nil,
        payload: [
          "changes": [
            [
              "action": "create_component", "scope": "entity", "source": entity.id, "kind": "facts",
              "title": "Traditions", "body": "Oath: Remember every crossing",
            ],
            [
              "action": "create_component", "scope": "atlas", "kind": "javascript",
              "title": "Unsafe", "body": "execute()",
            ],
            [
              "action": "create_component", "scope": "shell", "kind": "notes", "title": "Unknown",
              "body": "data",
            ],
            [
              "action": "create_component", "scope": "graph", "source": entity.id, "kind": "notes",
              "title": "Invalid parent", "body": "data",
            ],
          ]
        ]))
    #expect(proposal.changes.count == 1)
    #expect(try store.creativeComponents(worldID: world.id).isEmpty)
    #expect(throws: (any Error).self) {
      try store.resolveChange(
        worldID: world.id, proposalID: proposal.id, changeID: proposal.changes[0].id, accept: true,
        confirmation: "")
    }
    _ = try store.resolveChange(
      worldID: world.id, proposalID: proposal.id, changeID: proposal.changes[0].id, accept: true,
      confirmation: proposal.id)
    let item = try #require(try store.creativeComponents(worldID: world.id).first)
    #expect(item.kind == .facts && item.parentID == entity.id)
    #expect(item.record.origin == "ai-proposed" && item.record.state == "draft")
    #expect(item.record.canonical == nil)
    #expect(try store.record(worldID: world.id, id: entity.id) == entity)
  }

  @Test func oldArchivesImportAndMalformedComponentMembershipRollsBack() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Archive")
    let entity = try store.createRecord(worldID: world.id, title: "Mira", kind: "entity")
    try store.createCreativeComponent(
      worldID: world.id, scope: .entity, kind: .notes, parentID: entity.id, title: "Motives")
    let bytes = try store.exportWorldArchive(worldID: world.id)
    var archive = try JSONDecoder().decode(WorldArchive.self, from: bytes)
    archive.version = 4
    archive.tables.removeValue(forKey: "creative_components")
    let oldCopy = try store.importWorldArchive(JSONEncoder().encode(archive))
    #expect(try store.creativeComponents(worldID: oldCopy.id).isEmpty)
    archive = try JSONDecoder().decode(WorldArchive.self, from: bytes)
    archive.tables["record_sections"] = []
    let count = try store.worlds().count
    #expect(throws: (any Error).self) {
      try store.importWorldArchive(JSONEncoder().encode(archive))
    }
    #expect(try store.worlds().count == count)
  }
}
