import Foundation
import Testing

@testable import SynthesisCore

struct RecordBacklinksTests {
  @Test func explicitLinksAndTextMentionsStayDistinct() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Glass Sea")
    let other = try store.createWorld(name: "Another universe")
    let target = try store.createRecord(worldID: world.id, title: "Mira Vale", kind: "entity")
    let named = try store.saveMetadata(
      worldID: world.id, id: target.id, version: target.version, tags: [], aliases: ["Cartographer"]
    )
    let typed = WorldReference(worldID: world.id, kind: .record, id: named.id)
    let foreignTyped = WorldReference(worldID: other.id, kind: .record, id: named.id)
    let linked = try store.createRecord(worldID: world.id, title: "Catalog")
    try store.linkRecord(worldID: world.id, source: linked.id, target: named.id)
    let inline = try store.createRecord(
      worldID: world.id, title: "Inline", body: "[Mira Vale](\(typed.url))")
    try store.linkRecord(worldID: world.id, source: inline.id, target: named.id)
    let legacy = try store.createRecord(
      worldID: world.id, title: "Legacy", body: "[Mira Vale](synthesis://record/\(named.id))")
    let mention = try store.createRecord(
      worldID: world.id, title: "Journal", body: "I spoke to the CARTOGRAPHER.")
    let both = try store.createRecord(
      worldID: world.id, title: "Interview", body: "Mira Vale said: [the navigator](\(typed.url)).")
    _ = try store.createRecord(worldID: world.id, title: "Word boundary", body: "Mira Valerian")
    _ = try store.createRecord(worldID: world.id, title: "Mira Vale", body: "No mention in prose")
    _ = try store.createRecord(
      worldID: world.id, title: "Foreign URL", body: "[Mira Vale](\(foreignTyped.url))")
    _ = try store.createRecord(worldID: other.id, title: "Foreign", body: "Mira Vale")
    let archived = try store.createRecord(worldID: world.id, title: "Archived", body: "Mira Vale")
    try store.linkRecord(worldID: world.id, source: archived.id, target: named.id)
    try store.archiveRecord(worldID: world.id, id: archived.id)

    let result = try store.recordBacklinks(worldID: world.id, recordID: named.id)
    #expect(Set(result.linked.map(\.id)) == [linked.id, inline.id, legacy.id, both.id])
    #expect(result.linked.count == 4)
    #expect(Set(result.mentioned.map(\.id)) == [mention.id, both.id])
    #expect(try store.record(worldID: world.id, id: named.id) == named)
    #expect(throws: SynthesisError.self) {
      try store.recordBacklinks(worldID: other.id, recordID: named.id)
    }
    let findings = try store.worldChecks(worldID: world.id)
    #expect(!findings.contains { $0.id == "mention:\(inline.id):\(named.id)" })
    #expect(!findings.contains { $0.id == "mention:\(both.id):\(named.id)" })
  }

  @Test func duplicateNamesDoNotTurnTextIntoAnExplicitAddress() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Glass Sea")
    let first = try store.createRecord(worldID: world.id, title: "Mira Vale", kind: "entity")
    let second = try store.createRecord(worldID: world.id, title: first.title, kind: "entity")
    _ = try store.saveMetadata(
      worldID: world.id, id: second.id, version: second.version, tags: [],
      aliases: ["Navigator"])
    let historical = try store.createEntityNamePeriod(
      worldID: world.id, recordID: first.id,
      draft: .init(kind: .alias, name: "Navigator"))
    let address = WorldReference(worldID: world.id, kind: .record, id: first.id)
    let linked = try store.createRecord(
      worldID: world.id, title: "Address", body: "See [Mira Vale](\(address.url)).")
    let mention = try store.createRecord(
      worldID: world.id, title: "Mention", body: "The navigator came ashore.")
    let firstBacklinks = try store.recordBacklinks(worldID: world.id, recordID: first.id)
    let secondBacklinks = try store.recordBacklinks(worldID: world.id, recordID: second.id)
    #expect(firstBacklinks.linked == [linked] && firstBacklinks.mentioned == [mention])
    #expect(secondBacklinks.linked.isEmpty && secondBacklinks.mentioned == [mention])
    try store.archiveEntityNamePeriod(worldID: world.id, expected: historical)
    #expect(try store.recordBacklinks(worldID: world.id, recordID: first.id).mentioned.isEmpty)
  }

  @MainActor @Test func fileBackedBacklinksAreIndependentOfTheLibraryResultLimit() async throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    let store = try WorkspaceStore(path: folder.appendingPathComponent("lore.sqlite").path)
    let world = try store.createWorld(name: "Glass Sea")
    let foreign = try store.createWorld(name: "Outside")
    let target = try store.createRecord(worldID: world.id, title: "Mira Vale")
    for index in 0..<52 {
      _ = try store.createRecord(
        worldID: world.id, title: "Entry \(index)", body: "Follow Mira Vale.")
    }
    _ = try store.createRecord(worldID: foreign.id, title: "Outside", body: "Follow Mira Vale.")
    let backlinks = try await store.loadRecordBacklinks(worldID: world.id, recordID: target.id)
    #expect(backlinks.linked.isEmpty && backlinks.mentioned.count == 52)
    #expect(Set(backlinks.mentioned.map(\.worldID)) == [world.id])
    #expect(try store.search(worldID: world.id, query: "Mira Vale").count == 50)
  }

  @Test func savedEditsArchiveAndRestoreUpdateBacklinksWithoutChangingSources() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Glass Sea")
    let target = try store.createRecord(worldID: world.id, title: "Mira Vale")
    let address = WorldReference(worldID: world.id, kind: .record, id: target.id)
    let source = try store.createRecord(worldID: world.id, title: "Report", body: "Mira Vale")
    #expect(try store.recordBacklinks(worldID: world.id, recordID: target.id).mentioned == [source])
    let body = "[Navigator](\(address.url))"
    let updated = try store.saveRecord(
      worldID: world.id, id: source.id, version: source.version, title: source.title,
      body: body, rtf: nil)
    try store.archiveRecord(worldID: world.id, id: target.id)
    #expect(try store.record(worldID: world.id, id: source.id) == updated)
    #expect(throws: SynthesisError.self) {
      try store.recordBacklinks(worldID: world.id, recordID: target.id)
    }
    try store.restoreRecord(worldID: world.id, id: target.id)
    let result = try store.recordBacklinks(worldID: world.id, recordID: target.id)
    #expect(result.linked == [updated])
    #expect(result.mentioned.isEmpty)
  }
}
