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
}
