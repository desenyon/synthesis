import Foundation
import Testing

@testable import SynthesisCore

struct EditorJournalTests {
  @Test func journalSurvivesReopenAndClearsWhenSaved() throws {
    let path = FileManager.default.temporaryDirectory
      .appendingPathComponent("journal-\(UUID().uuidString).sqlite").path
    defer { try? FileManager.default.removeItem(atPath: path) }
    var worldID = ""
    var recordID = ""
    do {
      let store = try WorkspaceStore(path: path)
      let world = try store.createWorld(name: "Recovery")
      let record = try store.createRecord(worldID: world.id, title: "Notes", body: "saved")
      worldID = world.id
      recordID = record.id
      try store.writeJournal(
        worldID: world.id, recordID: record.id, title: "Notes", body: "saved and more typing",
        rtf: nil, category: "", baseVersion: record.version)
    }
    // A new process: the database reopens with the recovery copy intact.
    let store = try WorkspaceStore(path: path)
    let entry = try #require(try store.journal(worldID: worldID, recordID: recordID))
    #expect(entry.body == "saved and more typing")
    #expect(try store.journals(worldID: worldID).count == 1)
    // Saving the same text makes the copy redundant; it is dropped rather than offered.
    let record = try store.record(worldID: worldID, id: recordID)
    _ = try store.saveRecord(
      worldID: worldID, id: recordID, version: record.version, title: "Notes",
      body: "saved and more typing", rtf: nil)
    #expect(try store.journal(worldID: worldID, recordID: recordID) == nil)
    #expect(try store.journals(worldID: worldID).isEmpty)
  }

  @Test func journalIsWorldScopedAndExcludedFromExports() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "A")
    let other = try store.createWorld(name: "B")
    let record = try store.createRecord(worldID: world.id, title: "Secret draft", body: "")
    try store.writeJournal(
      worldID: world.id, recordID: record.id, title: "Secret draft", body: "unsaved words",
      rtf: nil, category: "", baseVersion: 1)
    #expect(throws: (any Error).self) {
      try store.writeJournal(
        worldID: other.id, recordID: record.id, title: "x", body: "y", rtf: nil, category: "",
        baseVersion: 1)
    }
    #expect(try store.journals(worldID: other.id).isEmpty)
    let json = String(decoding: try store.exportWorld(world.id), as: UTF8.self)
    #expect(!json.contains("unsaved words"))
  }
}
