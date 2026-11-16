import Foundation
import Testing

@testable import SynthesisCore

struct RecordSectionTests {
  @Test func membershipsAreScopedAndOnlyActive() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Sections")
    let other = try store.createWorld(name: "Other")
    let parent = try store.createRecord(
      worldID: world.id, title: "Mira", kind: "entity", category: "Characters")
    let sections = try (1...3).map {
      try store.createRecordSection(worldID: world.id, parentID: parent.id, title: "Section \($0)")
    }
    let memberships = try store.sectionMemberships(worldID: world.id)
    #expect(memberships.count == 3)
    #expect(
      try store.records(worldID: world.id).filter {
        memberships[$0.id] == nil && $0.category == "Characters"
      }.count == 1)
    #expect(try store.sectionMemberships(worldID: other.id).isEmpty)
    try store.setRecordSectionArchived(worldID: world.id, id: sections[0].id, archived: true)
    #expect(try store.sectionMemberships(worldID: world.id)[sections[0].record.id] == nil)
    #expect(try store.search(worldID: world.id, query: "Section").count == 3)
    try store.archiveRecord(worldID: world.id, id: parent.id)
    #expect(try store.sectionMemberships(worldID: world.id).isEmpty)
  }

  @Test func sectionProposalStaysPendingUntilScopedApproval() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Sections")
    let parent = try store.createRecord(worldID: world.id, title: "Mira", kind: "entity")
    let proposal = try #require(
      try store.stageProposal(
        worldID: world.id, conversationID: nil, messageID: nil,
        payload: [
          "changes": [
            [
              "action": "add_section", "source": parent.id,
              "title": "Motivations", "body": "Find the lost observatory.",
            ]
          ]
        ]))
    #expect(try store.records(worldID: world.id).count == 1)
    #expect(throws: (any Error).self) {
      try store.resolveChange(
        worldID: world.id, proposalID: proposal.id,
        changeID: proposal.changes[0].id, accept: true, confirmation: "")
    }
    _ = try store.resolveChange(
      worldID: world.id, proposalID: proposal.id,
      changeID: proposal.changes[0].id, accept: true, confirmation: proposal.id)
    let child = try #require(store.records(worldID: world.id).first { $0.id != parent.id })
    #expect(child.body == "Find the lost observatory.")
    #expect(child.origin == "ai-proposed")
    #expect(child.state == "draft")
    #expect(child.canonical == nil)
    #expect(try store.record(worldID: world.id, id: parent.id) == parent)
  }
}

struct RecordSectionPersistenceTests {
  @Test func sectionsSurviveRestartReorderArchiveAndIndependentImport() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let path = directory.appendingPathComponent("world.sqlite").path
    let store = try WorkspaceStore(path: path)
    let world = try store.createWorld(name: "Aster")
    let parent = try store.createRecord(worldID: world.id, title: "Mira", kind: "entity")
    let one = try store.createRecordSection(
      worldID: world.id, parentID: parent.id, title: "History", body: "Born in the observatory.")
    let two = try store.createRecordSection(
      worldID: world.id, parentID: parent.id, title: "Motivations", body: "Find the missing chart.")
    try store.reorderRecordSections(
      worldID: world.id, parentID: parent.id, orderedIDs: [two.id, one.id])
    let reopened = try WorkspaceStore(path: path)
    #expect(
      try reopened.recordSections(worldID: world.id, parentID: parent.id).map(\.record.title) == [
        "Motivations", "History",
      ])
    #expect(
      try reopened.search(worldID: world.id, query: "observatory").map(\.id) == [one.record.id])
    #expect(try reopened.sectionParent(worldID: world.id, recordID: one.record.id)?.id == parent.id)
    let imported = try store.importWorldArchive(store.exportWorldArchive(worldID: world.id))
    let importedParent = try #require(
      store.records(worldID: imported.id).first { $0.kind == "entity" })
    let copies = try store.recordSections(worldID: imported.id, parentID: importedParent.id)
    #expect(copies.map(\.record.title) == ["Motivations", "History"])
    #expect(copies.allSatisfy { $0.record.id != one.record.id && $0.record.id != two.record.id })
    try store.setRecordSectionArchived(worldID: world.id, id: one.id, archived: true)
    #expect(try store.recordSections(worldID: world.id, parentID: parent.id).count == 1)
    #expect(
      try store.record(worldID: world.id, id: one.record.id).body == "Born in the observatory.")
    #expect(try store.sectionParent(worldID: world.id, recordID: one.record.id) == nil)
    try store.setRecordSectionArchived(worldID: world.id, id: one.id, archived: false)
    #expect(try store.recordSections(worldID: world.id, parentID: parent.id).count == 2)
    let json = try #require(
      try JSONSerialization.jsonObject(with: store.exportWorld(world.id)) as? [String: Any])
    #expect((json["recordSections"] as? [[String: Any]])?.count == 2)
    let markdown = try store.exportMarkdown(worldID: world.id)
    #expect(
      markdown.contains {
        $0.content.contains("## Sections")
          && $0.content.contains("[History](../Documents/History.md)")
      }
    )
  }

  @Test func invalidParentAndStaleOrderNeverLeavePartialData() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "One")
    let other = try store.createWorld(name: "Two")
    let parent = try store.createRecord(worldID: world.id, title: "Mira", kind: "entity")
    let foreign = try store.createRecord(worldID: other.id, title: "Foreign", kind: "entity")
    #expect(throws: (any Error).self) {
      try store.createRecordSection(worldID: world.id, parentID: foreign.id, title: "No")
    }
    #expect(throws: (any Error).self) {
      try store.createRecordSection(worldID: world.id, parentID: parent.id, title: " ")
    }
    #expect(try store.records(worldID: world.id).count == 1)
    let one = try store.createRecordSection(worldID: world.id, parentID: parent.id, title: "First")
    let two = try store.createRecordSection(worldID: world.id, parentID: parent.id, title: "Second")
    #expect(throws: (any Error).self) {
      try store.reorderRecordSections(
        worldID: world.id, parentID: parent.id, orderedIDs: [one.id, one.id])
    }
    #expect(throws: (any Error).self) {
      try store.setRecordSectionArchived(worldID: other.id, id: one.id, archived: true)
    }
    #expect(
      try store.recordSections(worldID: world.id, parentID: parent.id).map(\.id) == [
        one.id, two.id,
      ])
    try store.archiveRecord(worldID: world.id, id: parent.id)
    #expect(throws: (any Error).self) {
      try store.createRecordSection(worldID: world.id, parentID: parent.id, title: "No")
    }
    #expect(try store.sectionParent(worldID: world.id, recordID: one.record.id) == nil)
  }

  @Test func sectionEditPreservesBothCanonSnapshotsAndRejectsStaleWrites() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "One")
    var parent = try store.createRecord(
      worldID: world.id, title: "Mira", body: "A cartographer.", kind: "entity")
    parent = try store.promote(
      worldID: world.id, id: parent.id, version: parent.version, confirmation: parent.id)
    let section = try store.createRecordSection(
      worldID: world.id, parentID: parent.id, title: "History", body: "Born inland.")
    let accepted = try store.promote(
      worldID: world.id, id: section.record.id, version: section.record.version,
      confirmation: section.record.id)
    let edited = try store.saveRecord(
      worldID: world.id, id: accepted.id, version: accepted.version, title: accepted.title,
      body: "Born at sea.", rtf: nil)
    #expect(edited.state == "draft")
    #expect(edited.canonical == accepted.canonical)
    #expect(try store.record(worldID: world.id, id: parent.id) == parent)
    #expect(throws: (any Error).self) {
      try store.saveRecord(
        worldID: world.id, id: accepted.id, version: accepted.version, title: accepted.title,
        body: "Stale", rtf: nil)
    }
    #expect(try store.history(worldID: world.id, id: edited.id).count == 3)
  }

  @Test func referencedEntityBringsItsSectionsIntoBoundedContext() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "One")
    let parent = try store.createRecord(worldID: world.id, title: "Mira", kind: "entity")
    let section = try store.createRecordSection(
      worldID: world.id, parentID: parent.id, title: "History", body: "Born inland.")
    for i in 0..<20 { _ = try store.createRecord(worldID: world.id, title: "Unrelated \(i)") }
    let context = try store.contextRecords(
      worldID: world.id, prompt: "Develop [Mira](synthesis://record/\(parent.id))", limit: 2)
    #expect(context.map(\.id) == [parent.id, section.record.id])
    #expect(context.last?.reason == "Section of Mira")
    #expect(try store.workspaceContext(worldID: world.id).contains(section.record.id))
  }
}

struct RecordSectionBoundaryTests {
  @Test func newEntitySectionDependsOnItsAcceptedParent() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "One")
    let proposal = try #require(
      try store.stageProposal(
        worldID: world.id,
        conversationID: nil, messageID: nil,
        payload: [
          "changes": [
            [
              "action": "create_record", "kind": "entity", "title": "New order",
              "body": "A proposed order.",
            ],
            [
              "action": "add_section", "source": "New order", "title": "Traditions",
              "body": "Unwritten rules.",
            ],
          ]
        ]))
    #expect(proposal.changes.count == 2)
    #expect(throws: (any Error).self) {
      try store.resolveChange(
        worldID: world.id, proposalID: proposal.id,
        changeID: proposal.changes[1].id, accept: true, confirmation: proposal.id)
    }
    #expect(try store.records(worldID: world.id).isEmpty)
    _ = try store.resolveChange(
      worldID: world.id, proposalID: proposal.id,
      changeID: proposal.changes[0].id, accept: true, confirmation: proposal.id)
    _ = try store.resolveChange(
      worldID: world.id, proposalID: proposal.id,
      changeID: proposal.changes[1].id, accept: true, confirmation: proposal.id)
    let parent = try #require(store.records(worldID: world.id).first { $0.kind == "entity" })
    #expect(
      try store.recordSections(worldID: world.id, parentID: parent.id).first?.record.body
        == "Unwritten rules.")
  }

  @Test func oldSnapshotsImportAndMalformedMembershipRollsBack() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "One")
    let parent = try store.createRecord(worldID: world.id, title: "Entity", kind: "entity")
    let child = try store.createRecordSection(
      worldID: world.id, parentID: parent.id, title: "Notes")
    var archive = try JSONDecoder().decode(
      WorldArchive.self, from: store.exportWorldArchive(worldID: world.id))
    // A section cannot recursively become another section's parent via an imported payload.
    archive.tables["records"] = archive.tables["records"]?.map { row in
      var value = row
      if value["id"] == parent.id { value["kind"] = "lore" }
      return value
    }
    #expect(throws: (any Error).self) {
      try store.importWorldArchive(JSONEncoder().encode(archive))
    }
    #expect(try store.worlds().count == 1)
    archive = try JSONDecoder().decode(
      WorldArchive.self, from: store.exportWorldArchive(worldID: world.id))
    archive.version = 2
    archive.tables.removeValue(forKey: "record_sections")
    let imported = try store.importWorldArchive(JSONEncoder().encode(archive))
    #expect(try store.records(worldID: imported.id).count == 2)
    #expect(try store.record(worldID: world.id, id: child.record.id).title == "Notes")
    archive.version = 1
    archive.tables.removeValue(forKey: "chronology_lanes")
    archive.tables.removeValue(forKey: "chronology_placements")
    _ = try store.importWorldArchive(JSONEncoder().encode(archive))
    #expect(try store.worlds().count == 3)
  }

  @Test func pendingSectionCannotAttachToAnArchivedParent() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "One")
    let parent = try store.createRecord(worldID: world.id, title: "Entity", kind: "entity")
    let proposal = try #require(
      try store.stageProposal(
        worldID: world.id,
        conversationID: nil, messageID: nil,
        payload: [
          "changes": [
            [
              "action": "add_section", "source": parent.id, "title": "Notes",
              "body": "A suggestion.",
            ]
          ]
        ]))
    try store.archiveRecord(worldID: world.id, id: parent.id)
    #expect(throws: (any Error).self) {
      try store.resolveChange(
        worldID: world.id, proposalID: proposal.id,
        changeID: proposal.changes[0].id, accept: true, confirmation: proposal.id)
    }
    #expect(try store.records(worldID: world.id).isEmpty)
    #expect(try store.proposal(worldID: world.id, id: proposal.id).changes[0].status == "pending")
  }
}
