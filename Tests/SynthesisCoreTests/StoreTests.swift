import Foundation
import Testing

@testable import SynthesisCore

struct StoreTests {
  func fixture() throws -> WorkspaceStore { try WorkspaceStore(path: ":memory:") }
  @Test func persistenceAcrossReopen() throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer {
      for suffix in ["", "-wal", "-shm"] {
        try? FileManager.default.removeItem(atPath: path + suffix)
      }
    }
    var s: WorkspaceStore? = try WorkspaceStore(path: path)
    let w = try s!.createWorld(name: "Aster")
    let c = try s!.createConversation(worldID: w.id)
    _ = try s!.appendMessage(
      worldID: w.id, conversationID: c.id, role: "user", body: "Build a sea", state: "complete")
    _ = try s!.createRecord(worldID: w.id, title: "Sea", body: "The water turns to glass")
    try s!.setPreference("mode", value: "manual")
    s = nil
    let reopened = try WorkspaceStore(path: path)
    #expect(try reopened.messages(worldID: w.id, conversationID: c.id).first?.body == "Build a sea")
    #expect(try reopened.records(worldID: w.id).first?.body == "The water turns to glass")
    #expect(try reopened.preference("mode") == "manual")
  }
  @Test func worldIsolation() throws {
    let s = try fixture()
    let a = try s.createWorld(name: "A")
    let b = try s.createWorld(name: "B")
    let r = try s.createRecord(worldID: a.id, title: "Secret moon", body: "hidden")
    let c = try s.createConversation(worldID: a.id)
    #expect(throws: Error.self) { try s.record(worldID: b.id, id: r.id) }
    #expect(throws: Error.self) { try s.messages(worldID: b.id, conversationID: c.id) }
    #expect(try s.search(worldID: b.id, query: "moon").isEmpty)
    #expect(try s.search(worldID: a.id, query: "moon").count == 1)
  }
  @Test func canonAndStaleSaveBoundary() throws {
    let s = try fixture()
    let w = try s.createWorld(name: "A")
    var r = try s.createRecord(worldID: w.id, title: "Rule", body: "One moon")
    #expect(throws: Error.self) {
      try s.promote(worldID: w.id, id: r.id, version: r.version, confirmation: "")
    }
    r = try s.promote(worldID: w.id, id: r.id, version: r.version, confirmation: r.id)
    let old = r.version
    r = try s.saveRecord(
      worldID: w.id, id: r.id, version: r.version, title: r.title, body: "Two moons", rtf: nil)
    #expect(r.canonical?.contains("One moon") == true)
    #expect(r.state == "draft")
    #expect(throws: Error.self) {
      try s.saveRecord(
        worldID: w.id, id: r.id, version: old, title: "Rule", body: "Stale", rtf: nil)
    }
    #expect(try s.history(worldID: w.id, id: r.id).count == 3)
  }
  @Test func relationshipIsolationAndUnknownDates() throws {
    let s = try fixture()
    let a = try s.createWorld(name: "A")
    let b = try s.createWorld(name: "B")
    let x = try s.createRecord(worldID: a.id, title: "X", body: "", kind: "entity")
    let y = try s.createRecord(worldID: b.id, title: "Y", body: "", kind: "entity")
    #expect(throws: Error.self) {
      try s.addRelation(worldID: a.id, source: x.id, target: y.id, label: "knows")
    }
    #expect(
      try s.addEvent(worldID: a.id, title: "Arrival", date: "", source: x.id).dateLabel == "unknown"
    )
  }
  @Test func richTextAndCanvasPersistence() throws {
    let s = try fixture()
    let w = try s.createWorld(name: "A")
    var r = try s.createRecord(worldID: w.id, title: "Page", body: "First")
    r = try s.saveRecord(
      worldID: w.id, id: r.id, version: r.version, title: "Page", body: "Bold", rtf: "encoded-rtf")
    #expect(try s.record(worldID: w.id, id: r.id).rtf == "encoded-rtf")
    let b = try s.saveBoard(
      worldID: w.id, name: "Ideas", kind: "canvas", content: "[{\"text\":\"A thought\"}]")
    #expect(try s.boards(worldID: w.id, kind: "canvas").first?.id == b.id)
  }
  @Test func linksMetadataAndExportsStayWorldScoped() throws {
    let s = try fixture()
    let a = try s.createWorld(name: "A")
    let b = try s.createWorld(name: "B")
    var page = try s.createRecord(worldID: a.id, title: "Crossing", body: "Before dawn")
    let entity = try s.createRecord(worldID: a.id, title: "Mira", kind: "entity")
    let foreign = try s.createRecord(worldID: b.id, title: "Other world", kind: "entity")
    try s.linkRecord(worldID: a.id, source: page.id, target: entity.id)
    try s.linkRecord(worldID: a.id, source: page.id, target: entity.id)
    #expect(try s.linkedRecords(worldID: a.id, id: page.id).count == 1)
    #expect(try s.linkedRecords(worldID: a.id, id: entity.id, incoming: true).first?.id == page.id)
    #expect(throws: Error.self) {
      try s.linkRecord(worldID: a.id, source: page.id, target: foreign.id)
    }
    page = try s.promote(worldID: a.id, id: page.id, version: page.version, confirmation: page.id)
    let canon = page.canonical
    page = try s.saveMetadata(
      worldID: a.id, id: page.id, version: page.version, tags: ["maritime"], aliases: ["Dawnwalk"])
    #expect(page.state == "draft" && page.canonical == canon)
    #expect(try s.search(worldID: a.id, query: "Dawnwalk").first?.id == page.id)
    #expect(try s.search(worldID: b.id, query: "Dawnwalk").isEmpty)
    #expect(try s.history(worldID: a.id, id: page.id).first?.snapshot.tags == ["maritime"])
    let exported = String(decoding: try s.exportWorld(a.id), as: UTF8.self)
    #expect(
      exported.contains("Dawnwalk") && exported.contains(entity.id)
        && !exported.contains(foreign.id))
  }
  @Test func boardsCannotBeOverwrittenFromAnotherWorld() throws {
    let s = try fixture()
    let a = try s.createWorld(name: "A")
    let b = try s.createWorld(name: "B")
    let board = try s.saveBoard(worldID: a.id, name: "Map", kind: "atlas", content: "{}")
    #expect(throws: Error.self) {
      try s.saveBoard(worldID: b.id, id: board.id, name: "Wrong", kind: "atlas", content: "{}")
    }
    #expect(try s.boards(worldID: a.id, kind: "atlas").first?.name == "Map")
  }
  @Test func revisionRestoreIncludesMetadataAndPreservesCanon() throws {
    let store = try fixture()
    let world = try store.createWorld(name: "Revision")
    var record = try store.createRecord(worldID: world.id, title: "Sea", body: "Old text")
    record = try store.saveMetadata(
      worldID: world.id, id: record.id, version: record.version, tags: ["old-tag"],
      aliases: ["Oldalias"])
    let old = try store.history(worldID: world.id, id: record.id).first!
    record = try store.promote(
      worldID: world.id, id: record.id, version: record.version, confirmation: record.id)
    let canon = record.canonical
    record = try store.saveMetadata(
      worldID: world.id, id: record.id, version: record.version, tags: ["new-tag"],
      aliases: ["Newalias"])
    record = try store.restoreRevision(
      worldID: world.id, id: record.id, version: record.version, revisionID: old.id)
    #expect(record.aliases == ["Oldalias"] && record.tags == ["old-tag"])
    #expect(record.state == "draft" && record.canonical == canon)
    #expect(try store.search(worldID: world.id, query: "Newalias").isEmpty)
    #expect(try store.search(worldID: world.id, query: "Oldalias").first?.id == record.id)
  }
  @Test func relationshipEditsAreScopedAuditedAndReversible() throws {
    let s = try fixture()
    let a = try s.createWorld(name: "A")
    let b = try s.createWorld(name: "B")
    let x = try s.createRecord(worldID: a.id, title: "Mira", kind: "entity")
    let y = try s.createRecord(worldID: a.id, title: "Tidekeepers", kind: "entity")
    let relation = try s.addRelation(worldID: a.id, source: x.id, target: y.id, label: "guided by")
    #expect(throws: Error.self) {
      try s.updateRelation(worldID: b.id, id: relation.id, label: "wrong")
    }
    #expect(throws: Error.self) { try s.archiveRelation(worldID: b.id, id: relation.id) }
    try s.updateRelation(worldID: a.id, id: relation.id, label: "trained by")
    #expect(try s.relations(worldID: a.id).first?.label == "trained by")
    try s.archiveRelation(worldID: a.id, id: relation.id)
    #expect(try s.relations(worldID: a.id).isEmpty)
    let export = String(decoding: try s.exportWorld(a.id), as: UTF8.self)
    #expect(
      export.contains("guided by") && export.contains("trained by") && export.contains("archive"))
    #expect(throws: Error.self) { try s.restoreRelation(worldID: b.id, id: relation.id) }
    try s.restoreRelation(worldID: a.id, id: relation.id)
    #expect(try s.relations(worldID: a.id).first?.id == relation.id)
    #expect(try s.record(worldID: a.id, id: x.id).canonical == nil)
  }
  @Test func archivingRecordsIsReversibleAndKeepsCanonAndHistory() throws {
    let s = try fixture()
    let a = try s.createWorld(name: "A")
    let b = try s.createWorld(name: "B")
    var mira = try s.createRecord(worldID: a.id, title: "Mira", body: "Mapmaker", kind: "entity")
    let order = try s.createRecord(worldID: a.id, title: "Order", kind: "entity")
    _ = try s.addRelation(worldID: a.id, source: mira.id, target: order.id, label: "guided by")
    try s.linkRecord(worldID: a.id, source: order.id, target: mira.id)
    mira = try s.promote(worldID: a.id, id: mira.id, version: mira.version, confirmation: mira.id)
    let revisions = try s.history(worldID: a.id, id: mira.id).count
    #expect(throws: Error.self) { try s.archiveRecord(worldID: b.id, id: mira.id) }
    try s.archiveRecord(worldID: a.id, id: mira.id)
    #expect(try s.records(worldID: a.id).map(\.id) == [order.id])
    #expect(try s.archivedRecords(worldID: a.id).map(\.id) == [mira.id])
    #expect(try s.search(worldID: a.id, query: "Mapmaker").isEmpty)
    #expect(try s.relations(worldID: a.id).isEmpty)
    #expect(try s.linkedRecords(worldID: a.id, id: order.id).isEmpty)
    // Hidden, not discarded: still resolvable, canon and history untouched, and exported.
    let hidden = try s.record(worldID: a.id, id: mira.id)
    #expect(hidden.state == "canon" && hidden.canonical == mira.canonical)
    #expect(try s.history(worldID: a.id, id: mira.id).count == revisions)
    let export = String(decoding: try s.exportWorld(a.id), as: UTF8.self)
    #expect(export.contains("Mapmaker") && export.contains("archivedRecordIDs"))
    try s.restoreRecord(worldID: a.id, id: mira.id)
    #expect(try s.records(worldID: a.id).count == 2)
    #expect(try s.relations(worldID: a.id).first?.label == "guided by")
    #expect(try s.search(worldID: a.id, query: "Mapmaker").first?.id == mira.id)
  }
  @Test func conversationsBoardsAndEventsArchiveWithinTheirWorld() throws {
    let s = try fixture()
    let a = try s.createWorld(name: "A")
    let b = try s.createWorld(name: "B")
    let chat = try s.createConversation(worldID: a.id, title: "Tides")
    try s.appendMessage(
      worldID: a.id, conversationID: chat.id, role: "user", body: "Keep this", state: "complete")
    #expect(throws: Error.self) {
      try s.setConversationArchived(worldID: b.id, id: chat.id, archived: true)
    }
    try s.setConversationArchived(worldID: a.id, id: chat.id, archived: true)
    #expect(try s.conversations(worldID: a.id).isEmpty)
    #expect(try s.conversations(worldID: a.id, archived: true).first?.id == chat.id)
    #expect(try s.messages(worldID: a.id, conversationID: chat.id).first?.body == "Keep this")
    try s.setConversationArchived(worldID: a.id, id: chat.id, archived: false)
    #expect(try s.conversations(worldID: a.id).first?.id == chat.id)

    let board = try s.saveBoard(worldID: a.id, name: "Coast", kind: "canvas", content: "{}")
    #expect(throws: Error.self) {
      try s.setBoardArchived(worldID: b.id, id: board.id, archived: true)
    }
    try s.setBoardArchived(worldID: a.id, id: board.id, archived: true)
    #expect(try s.boards(worldID: a.id, kind: "canvas").isEmpty)
    // An archived board can still be saved by an open editor without reappearing.
    _ = try s.saveBoard(
      worldID: a.id, id: board.id, name: "Coast", kind: "canvas", content: "{\"cards\":[]}")
    #expect(try s.boards(worldID: a.id, kind: "canvas").isEmpty)
    #expect(try s.boards(worldID: a.id, kind: "canvas", archived: true).first?.id == board.id)
    #expect(throws: Error.self) {
      try s.saveBoard(worldID: a.id, name: " ", kind: "canvas", content: "{}")
    }

    let source = try s.createRecord(worldID: a.id, title: "Source")
    let other = try s.createRecord(worldID: b.id, title: "Elsewhere")
    let event = try s.addEvent(worldID: a.id, title: "Flood", date: "", source: source.id)
    #expect(throws: Error.self) {
      try s.updateEvent(
        worldID: a.id, id: event.id, title: "Flood", date: "", source: other.id, order: nil)
    }
    #expect(throws: Error.self) {
      try s.setEventArchived(worldID: b.id, id: event.id, archived: true)
    }
    let edited = try s.updateEvent(
      worldID: a.id, id: event.id, title: "The flood", date: "Before memory", source: source.id,
      order: 2)
    #expect(edited.dateLabel == "Before memory" && edited.order == 2)
    #expect(try s.events(worldID: a.id).first?.title == "The flood")
    try s.setEventArchived(worldID: a.id, id: event.id, archived: true)
    #expect(try s.events(worldID: a.id).isEmpty)
    #expect(String(decoding: try s.exportWorld(a.id), as: UTF8.self).contains("The flood"))
    try s.setEventArchived(worldID: a.id, id: event.id, archived: false)
    #expect(try s.events(worldID: a.id).count == 1)
  }
  @Test func worldRenameValidatesAndLinksCanBeRemoved() throws {
    let s = try fixture()
    let w = try s.createWorld(name: "Draft world")
    #expect(throws: Error.self) { try s.renameWorld(w.id, name: "   ") }
    #expect(try s.renameWorld(w.id, name: " Aster ").name == "Aster")
    let page = try s.createRecord(worldID: w.id, title: "Page")
    let entity = try s.createRecord(worldID: w.id, title: "Mira", kind: "entity")
    try s.linkRecord(worldID: w.id, source: page.id, target: entity.id)
    try s.unlinkRecord(worldID: w.id, source: page.id, target: entity.id)
    #expect(try s.linkedRecords(worldID: w.id, id: page.id).isEmpty)
    #expect(try s.record(worldID: w.id, id: entity.id).title == "Mira")
  }
  @Test func contextIsRankedExplainedAndWorldScoped() throws {
    let s = try fixture()
    let a = try s.createWorld(name: "A")
    let b = try s.createWorld(name: "B")
    let sea = try s.createRecord(
      worldID: a.id, title: "The Glass Sea", body: "Water that turns solid at dawn.",
      kind: "entity")
    let order = try s.createRecord(worldID: a.id, title: "Tidekeepers", kind: "entity")
    let ledger = try s.createRecord(
      worldID: a.id, title: "Ledger", body: "Lists every lantern lit on the harbour wall.")
    let hidden = try s.createRecord(
      worldID: a.id, title: "Old lantern notes", body: "lantern lantern lantern")
    let unrelated = try s.createRecord(worldID: a.id, title: "Unrelated", body: "Nothing.")
    _ = try s.createRecord(worldID: b.id, title: "Other lantern", body: "lantern")
    _ = try s.addRelation(worldID: a.id, source: order.id, target: sea.id, label: "guards")
    try s.archiveRecord(worldID: a.id, id: hidden.id)
    let context = try s.contextRecords(
      worldID: a.id,
      prompt: "Who lights the lantern near [the sea](synthesis://record/\(sea.id))?")
    #expect(context.map(\.id) == [sea.id, ledger.id, order.id, unrelated.id])
    #expect(
      context.map(\.reason) == [
        "You referenced it", "Matches your message", "Related to The Glass Sea", "Recent work",
      ])
    #expect(try s.contextRecords(worldID: a.id, prompt: "lantern", limit: 1).count == 1)
    #expect(try s.contextRecords(worldID: b.id, prompt: "sea").map(\.record.worldID) == [b.id])
    #expect(WorkspaceStore.referencedRecordIDs(in: "no links here").isEmpty)
  }
  @Test func markdownImportAndExportArePortableAndLabelled() throws {
    let s = try fixture()
    let w = try s.createWorld(name: "Aster")
    let imported = try s.importDocument(
      worldID: w.id, filename: "notes.md", text: "\n# The Bell Tower\r\n\r\nIt rings at low tide.\n"
    )
    #expect(imported.title == "The Bell Tower" && imported.body == "It rings at low tide.")
    #expect(imported.origin == "imported" && imported.state == "draft" && imported.kind == "lore")
    let plain = try s.importDocument(
      worldID: w.id, filename: "loose thought.txt", text: "No heading")
    #expect(plain.title == "loose thought" && plain.body == "No heading")
    let mira = try s.createRecord(
      worldID: w.id, title: "Mira / Vale", body: "Mapmaker", kind: "entity", category: "Characters")
    let twin = try s.createRecord(
      worldID: w.id, title: "Mira : Vale", body: "Twin", kind: "entity", category: "Characters")
    _ = try s.addRelation(worldID: w.id, source: mira.id, target: twin.id, label: "sister of")
    _ = try s.addEvent(worldID: w.id, title: "The crossing", date: "", source: mira.id)
    let files = try s.exportMarkdown(worldID: w.id)
    let paths = files.map(\.path)
    #expect(Set(paths).count == paths.count)
    #expect(
      paths.contains("Documents/The Bell Tower.md") && paths.contains("Characters/Mira - Vale.md"))
    #expect(paths.contains("Characters/Mira - Vale 2.md"))
    let page = try #require(files.first { $0.path == "Documents/The Bell Tower.md" }?.content)
    #expect(page.contains("origin: imported") && page.contains("state: draft"))
    #expect(page.contains("# The Bell Tower") && page.contains("It rings at low tide."))
    #expect(
      files.first { $0.path == "Relationships.md" }?.content.contains("— sister of →") == true)
    #expect(
      files.first { $0.path == "Timeline.md" }?.content.contains("**Date unknown** — The crossing")
        == true)
  }
  @Test func nestedStoreOperationsRollBackTogether() throws {
    let s = try fixture()
    let w = try s.createWorld(name: "A")
    let chat = try s.createConversation(worldID: w.id)
    let proposal = try #require(
      try s.stageProposal(
        worldID: w.id, conversationID: chat.id, messageID: nil,
        payload: [
          "summary": "One oversized record",
          "changes": [["action": "create_record", "kind": "entity", "title": "Kept pending"]],
        ]))
    // Force the inner create to fail after staging by making the title invalid in place.
    var broken = proposal.changes
    broken[0].title = String(repeating: "x", count: 400)
    try s.db.execute(
      "UPDATE proposals SET payload=? WHERE id=?",
      [String(decoding: try JSONEncoder().encode(broken), as: UTF8.self), proposal.id])
    #expect(throws: Error.self) {
      try s.resolveChange(
        worldID: w.id, proposalID: proposal.id, changeID: proposal.changes[0].id, accept: true,
        confirmation: proposal.id)
    }
    #expect(try s.records(worldID: w.id).isEmpty)
    #expect(try s.proposal(worldID: w.id, id: proposal.id).changes[0].status == "pending")
    // The store is still usable: the failed savepoint did not leave a transaction open.
    #expect(try s.createRecord(worldID: w.id, title: "Still works").title == "Still works")
  }

}
