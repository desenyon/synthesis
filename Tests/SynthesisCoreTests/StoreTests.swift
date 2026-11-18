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
  @Test func anOpenCanonReviewCannotPromoteAnArchivedRecord() throws {
    let store = try fixture()
    let world = try store.createWorld(name: "Archive review")
    let record = try store.createRecord(worldID: world.id, title: "Frozen draft")
    try store.archiveRecord(worldID: world.id, id: record.id)
    #expect(throws: SynthesisError.self) {
      try store.promote(
        worldID: world.id, id: record.id, version: record.version, confirmation: record.id)
    }
    #expect(try store.record(worldID: world.id, id: record.id).canonical == nil)
    #expect(try store.history(worldID: world.id, id: record.id).count == 1)
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
  @Test func worldChecksFindRealProblemsLocallyAndRememberDismissals() throws {
    let s = try fixture()
    let w = try s.createWorld(name: "Aster")
    let other = try s.createWorld(name: "Elsewhere")
    let mira = try s.createRecord(
      worldID: w.id, title: "Mira Vale", body: "A cartographer.", kind: "entity")
    let order = try s.createRecord(
      worldID: w.id, title: "Tidekeepers", body: "Guides of the coast.", kind: "entity")
    let twin = try s.createRecord(worldID: w.id, title: "mira vale", body: "A namesake.")
    let page = try s.createRecord(
      worldID: w.id, title: "The crossing",
      body: "Mira Vale walked out while the Tidekeepers watched. Miravalescent is not a match.")
    let empty = try s.createRecord(worldID: w.id, title: "Blank", kind: "entity")
    let gone = try s.createRecord(worldID: w.id, title: "Lost source")
    _ = try s.addEvent(worldID: w.id, title: "The flood", date: "", source: gone.id)
    try s.archiveRecord(worldID: w.id, id: gone.id)
    _ = try s.addRelation(worldID: w.id, source: mira.id, target: order.id, label: "guided by")
    try s.linkRecord(worldID: w.id, source: page.id, target: order.id)
    _ = try s.createRecord(worldID: other.id, title: "Mira Vale", body: "Mira Vale", kind: "entity")

    let findings = try s.worldChecks(worldID: w.id)
    let kinds = Dictionary(grouping: findings, by: \.kind).mapValues(\.count)
    #expect(kinds[.duplicateName] == 1 && kinds[.orphanedEvent] == 1)
    #expect(findings.first?.kind == .duplicateName)
    #expect(findings.first?.recordIDs.sorted() == [mira.id, twin.id].sorted())
    // The page names Mira without a link; it is already linked to the Tidekeepers.
    let mentions = findings.filter { $0.kind == .unlinkedMention }
    #expect(mentions.map(\.recordIDs) == [[page.id, mira.id]])
    #expect(findings.contains { $0.kind == .isolatedEntity && $0.recordIDs == [empty.id] })
    #expect(!findings.contains { $0.kind == .isolatedEntity && $0.recordIDs == [mira.id] })
    #expect(findings.contains { $0.kind == .emptyRecord && $0.recordIDs == [empty.id] })
    // Nothing was changed by looking, and another world's records never appear.
    #expect(try s.linkedRecords(worldID: w.id, id: page.id).map(\.id) == [order.id])
    #expect(findings.allSatisfy { finding in !finding.detail.contains("Elsewhere") })
    #expect(try s.worldChecks(worldID: other.id).allSatisfy { $0.kind != .duplicateName })

    // Linking resolves the mention; dismissing hides a finding until checks are restored.
    try s.linkRecord(worldID: w.id, source: page.id, target: mira.id)
    #expect(try s.worldChecks(worldID: w.id).allSatisfy { $0.kind != .unlinkedMention })
    let duplicate = try #require(findings.first)
    try s.dismissCheck(worldID: w.id, id: duplicate.id)
    #expect(try s.worldChecks(worldID: w.id).allSatisfy { $0.id != duplicate.id })
    #expect(try s.dismissedCheckCount(worldID: w.id) == 1)
    try s.restoreChecks(worldID: w.id)
    #expect(try s.worldChecks(worldID: w.id).contains { $0.id == duplicate.id })

    var rule = try s.createRecord(worldID: w.id, title: "Rule", body: "One moon")
    rule = try s.promote(worldID: w.id, id: rule.id, version: rule.version, confirmation: rule.id)
    #expect(try s.canonQueue(worldID: w.id).isEmpty)
    _ = try s.saveRecord(
      worldID: w.id, id: rule.id, version: rule.version, title: "Rule", body: "Two moons", rtf: nil)
    #expect(try s.canonQueue(worldID: w.id).map(\.id) == [rule.id])
  }

  @Test func rulesStayWorldScopedDraftUntilAcceptedAndReversible() throws {
    let s = try fixture()
    let w = try s.createWorld(name: "Aster")
    let other = try s.createWorld(name: "Elsewhere")
    let art = try s.createRecord(
      worldID: w.id, title: "Remembrance", body: "", kind: "entity", category: "Power systems")
    let page = try s.createRecord(worldID: w.id, title: "Notes", body: "")
    #expect(try s.powerSystems(worldID: w.id).map(\.id) == [art.id])
    #expect(try s.powerSystems(worldID: other.id).isEmpty)
    #expect(try s.ruleChecks(worldID: w.id, systemID: art.id).map(\.id) == ["empty"])

    // Rules attach to entities only, and never across worlds.
    #expect(throws: SynthesisError.self) {
      try s.addRule(worldID: w.id, systemID: page.id, kind: .cost, title: "Price", body: "")
    }
    #expect(throws: SynthesisError.self) {
      try s.addRule(worldID: other.id, systemID: art.id, kind: .cost, title: "Price", body: "")
    }
    #expect(throws: SynthesisError.self) {
      try s.addRule(worldID: w.id, systemID: art.id, kind: .cost, title: "  ", body: "")
    }

    let technique = try s.addRule(
      worldID: w.id, systemID: art.id, kind: .technique, title: "Recall", body: "Relive a day")
    var cost = try s.addRule(
      worldID: w.id, systemID: art.id, kind: .cost, title: "A memory", body: "One is lost")
    #expect(cost.state == "draft" && cost.origin == "user-authored" && cost.accepted == nil)
    // Grouped by kind in a fixed order, not by when they were written.
    #expect(try s.rules(worldID: w.id, systemID: art.id).map(\.id) == [cost.id, technique.id])
    #expect(throws: SynthesisError.self) { try s.rules(worldID: other.id, systemID: art.id) }
    #expect(throws: SynthesisError.self) { try s.rule(worldID: other.id, id: cost.id) }
    var checks = try s.ruleChecks(worldID: w.id, systemID: art.id).map(\.id)
    #expect(checks.contains("no-limit") && checks.contains("no-source"))
    #expect(!checks.contains("no-cost") && checks.contains("no-scenarios"))

    // Canon needs the rule's own ID, in its own world.
    #expect(throws: SynthesisError.self) {
      try s.promoteRule(worldID: w.id, id: cost.id, confirmation: "yes")
    }
    #expect(throws: SynthesisError.self) {
      try s.promoteRule(worldID: other.id, id: cost.id, confirmation: cost.id)
    }
    #expect(try s.rule(worldID: w.id, id: cost.id).state == "draft")
    cost = try s.promoteRule(worldID: w.id, id: cost.id, confirmation: cost.id)
    #expect(cost.state == "canon" && cost.accepted?.body == "One is lost")

    // Editing returns it to draft and keeps the accepted wording for comparison.
    cost = try s.updateRule(
      worldID: w.id, id: cost.id, kind: .cost, title: "A memory", body: "Two are lost")
    #expect(cost.state == "draft" && cost.accepted?.body == "One is lost")
    checks = try s.ruleChecks(worldID: w.id, systemID: art.id).map(\.id)
    #expect(checks.contains("changed-canon"))
    #expect(throws: SynthesisError.self) {
      try s.updateRule(worldID: other.id, id: cost.id, kind: .cost, title: "X", body: "")
    }

    // Scenarios: saved, updated, scoped; an empty verdict is reported.
    var test = try s.saveScenario(
      worldID: w.id, systemID: art.id, title: "Recall a stranger's day",
      situation: "Mira tries to relive a day she never lived.", expectation: "fails")
    #expect(try s.ruleChecks(worldID: w.id, systemID: art.id).contains { $0.id == "untested" })
    test = try s.saveScenario(
      worldID: w.id, systemID: art.id, id: test.id, title: test.title, situation: test.situation,
      expectation: "fails", verdict: "Fails: nothing states she can.")
    #expect(try s.scenarios(worldID: w.id, systemID: art.id) == [test])
    #expect(try !s.ruleChecks(worldID: w.id, systemID: art.id).contains { $0.id == "untested" })
    #expect(throws: SynthesisError.self) {
      try s.saveScenario(
        worldID: w.id, systemID: art.id, title: "Bad", situation: "", expectation: "maybe")
    }
    #expect(throws: SynthesisError.self) {
      try s.setScenarioArchived(worldID: other.id, id: test.id, archived: true)
    }

    // Rules travel in both exports, labelled with their state.
    let text = try s.rulesText(worldID: w.id, systemID: art.id)
    #expect(text.contains("Costs:\n- A memory: Two are lost [draft]"))
    let file = try #require(
      try s.exportMarkdown(worldID: w.id).first { $0.path == "Power systems/Remembrance.md" })
    #expect(file.content.contains("## Rules") && file.content.contains("- Recall: Relive a day"))
    let json = String(decoding: try s.exportWorld(w.id), as: UTF8.self)
    #expect(json.contains("\"ruleScenarios\"") && json.contains("Two are lost"))
    #expect(!String(decoding: try s.exportWorld(other.id), as: UTF8.self).contains("Two are lost"))

    // Archiving hides a rule and can be undone; nothing is deleted.
    try s.setRuleArchived(worldID: w.id, id: technique.id, archived: true)
    #expect(try s.rules(worldID: w.id, systemID: art.id).map(\.id) == [cost.id])
    try s.setRuleArchived(worldID: w.id, id: technique.id, archived: false)
    #expect(try s.rules(worldID: w.id, systemID: art.id).count == 2)
    try s.setScenarioArchived(worldID: w.id, id: test.id, archived: true)
    #expect(try s.scenarios(worldID: w.id, systemID: art.id).isEmpty)
  }
}

struct SearchScaleTests {
  @Test func indexedSearchRemainsWorldScopedAtScale() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Large world")
    let other = try store.createWorld(name: "Private world")
    try store.db.transaction {
      for i in 0..<2000 {
        _ = try store.createRecord(
          worldID: world.id, title: "Chronicle \(i)",
          body: "A navigator from the northern archipelago keeps the winter records.")
      }
    }
    _ = try store.createRecord(worldID: other.id, title: "Private navigator", body: "A navigator")
    let start = ContinuousClock.now
    for _ in 0..<20 {
      let result = try store.search(worldID: world.id, query: "navigator archipelago")
      #expect(result.count == 50)
      #expect(result.allSatisfy { $0.worldID == world.id })
    }
    print("Search benchmark: 20 indexed queries over 2,000 records: \(start.duration(to: .now))")
  }
}
