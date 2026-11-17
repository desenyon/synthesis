import Foundation
import Testing

@testable import SynthesisCore

struct RecordArtworkTests {
  static let png = Data(
    base64Encoded:
      "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aAfkAAAAASUVORK5CYII="
  )!

  @Test func artworkPersistsAndUndoRejectsStaleOrForeignImages() throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    let path = folder.appendingPathComponent("world.sqlite").path
    let store = try WorkspaceStore(path: path)
    let world = try store.createWorld(name: "Aster")
    var record = try store.createRecord(
      worldID: world.id, title: "Mira", body: "A navigator", kind: "entity")
    record = try store.promote(
      worldID: world.id, id: record.id, version: record.version, confirmation: record.id)
    let original = try store.saveRecordArtwork(
      worldID: world.id, recordID: record.id, data: Self.png, expectedID: nil)
    #expect(
      try WorkspaceStore(path: path).recordArtwork(worldID: world.id, recordID: record.id)
        == original)
    let replacement = try store.saveRecordArtwork(
      worldID: world.id, recordID: record.id, data: Self.png, origin: "ai-generated",
      expectedID: original.id)
    #expect(try store.record(worldID: world.id, id: record.id) == record)
    #expect(try store.db.rows("SELECT id FROM record_artwork WHERE archived=1").count == 1)
    #expect(throws: SynthesisError.self) {
      try store.restoreRecordArtwork(
        worldID: world.id, recordID: record.id, id: nil, expectedID: original.id)
    }
    try store.restoreRecordArtwork(
      worldID: world.id, recordID: record.id, id: original.id, expectedID: replacement.id)
    #expect(try store.recordArtwork(worldID: world.id, recordID: record.id) == original)
    try store.restoreRecordArtwork(
      worldID: world.id, recordID: record.id, id: nil, expectedID: original.id)
    #expect(try store.recordArtwork(worldID: world.id, recordID: record.id) == nil)
    try store.restoreRecordArtwork(
      worldID: world.id, recordID: record.id, id: original.id, expectedID: nil)
    let other = try store.createWorld(name: "Other")
    #expect(try store.recordArtworks(worldID: other.id).isEmpty)
    #expect(throws: SynthesisError.self) {
      try store.recordArtwork(worldID: other.id, recordID: record.id)
    }
    let foreign = try store.createRecord(worldID: other.id, title: "Foreign", kind: "entity")
    #expect(throws: SynthesisError.self) {
      try store.restoreRecordArtwork(
        worldID: other.id, recordID: foreign.id, id: original.id, expectedID: nil)
    }
    try store.archiveRecord(worldID: world.id, id: record.id)
    #expect(try store.recordArtworks(worldID: world.id).isEmpty)
  }

  @Test func exportPreservesArtworkAndImportCreatesAnIndependentHistory() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Aster")
    let record = try store.createRecord(worldID: world.id, title: "Mira", kind: "entity")
    let first = try store.saveRecordArtwork(
      worldID: world.id, recordID: record.id, data: Self.png, expectedID: nil)
    let second = try store.saveRecordArtwork(
      worldID: world.id, recordID: record.id, data: Self.png, expectedID: first.id)
    let exported = try store.exportWorldArchive(worldID: world.id)
    let copy = try store.importWorldArchive(exported)
    let copiedRecord = try #require(try store.records(worldID: copy.id).first)
    let artwork = try #require(try store.recordArtwork(worldID: copy.id, recordID: copiedRecord.id))
    #expect(artwork.image == second.image && artwork.mimeType == "image/png")
    #expect(artwork.id != second.id && artwork.recordID != record.id)
    #expect(
      try store.db.rows("SELECT id FROM record_artwork WHERE world_id=?", [copy.id]).count == 2)
    let json = try #require(
      try JSONSerialization.jsonObject(with: store.exportWorld(world.id)) as? [String: Any])
    #expect((json["recordArtwork"] as? [[String: String]])?.count == 2)
    let markdown = try store.exportRecordMarkdown(worldID: world.id, recordID: record.id)
    #expect(markdown.content.contains("data:image/png;base64,\(second.image)"))
    var legacy = try JSONDecoder().decode(WorldArchive.self, from: exported)
    legacy.version = 7
    legacy.tables.removeValue(forKey: "record_artwork")
    let oldCopy = try store.importWorldArchive(JSONEncoder().encode(legacy))
    #expect(try store.recordArtworks(worldID: oldCopy.id).isEmpty)
  }

  @Test func invalidArtworkAndInvalidArchiveOwnersNeverLeavePartialWrites() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Aster")
    let record = try store.createRecord(worldID: world.id, title: "Mira", kind: "entity")
    let document = try store.createRecord(worldID: world.id, title: "Notes", kind: "lore")
    let art = try store.saveRecordArtwork(
      worldID: world.id, recordID: record.id, data: Self.png, expectedID: nil)
    for bytes in [Data(), Data("not an image".utf8), Data(repeating: 0, count: 6_000_001)] {
      #expect(throws: SynthesisError.self) {
        try store.saveRecordArtwork(
          worldID: world.id, recordID: record.id, data: bytes, expectedID: art.id)
      }
    }
    #expect(throws: SynthesisError.self) {
      try store.saveRecordArtwork(
        worldID: world.id, recordID: document.id, data: Self.png, expectedID: nil)
    }
    #expect(try store.recordArtwork(worldID: world.id, recordID: record.id) == art)
    let data = try store.exportWorldArchive(worldID: world.id)
    for invalid in ["image", "owner"] {
      var archive = try JSONDecoder().decode(WorldArchive.self, from: data)
      if invalid == "image" {
        archive.tables["record_artwork"]?[0]["image"] = "invalid"
      } else {
        archive.tables["record_artwork"]?[0]["record_id"] = document.id
      }
      #expect(throws: (any Error).self) {
        try store.importWorldArchive(JSONEncoder().encode(archive))
      }
      #expect(try store.worlds().count == 1)
    }
  }
}
