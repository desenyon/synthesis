import Foundation
import Testing

@testable import SynthesisCore

struct WorldArchiveTests {
  @Test func roundTripIsIndependentAndPreservesConnections() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Archive world")
    let a = try store.createRecord(
      worldID: world.id, title: "Captain", body: "A navigator", kind: "entity")
    let b = try store.createRecord(worldID: world.id, title: "Port", body: "Home", kind: "entity")
    _ = try store.addRelation(worldID: world.id, source: a.id, target: b.id, label: "lives in")
    let chat = try store.createConversation(worldID: world.id)
    _ = try store.appendMessage(
      worldID: world.id, conversationID: chat.id, role: "user", body: "About \(a.id)",
      state: "complete")
    _ = try store.saveBoard(
      worldID: world.id, name: "Ideas", kind: "canvas", content: "{\"recordID\":\"\(a.id)\"}")
    try store.setPreference("provider", value: "private-device-setting")
    try store.setPreference("composer:\(world.id)", value: "Ask about \(a.id)")
    let data = try store.exportWorldArchive(worldID: world.id)
    #expect(!String(decoding: data, as: UTF8.self).contains("private-device-setting"))
    let copy = try store.importWorldArchive(data)
    let pages = try store.records(worldID: copy.id)
    #expect(copy.id != world.id)
    #expect(pages.count == 2)
    let copiedCaptain = try #require(pages.first { $0.title == "Captain" })
    #expect(copiedCaptain.id != a.id)
    let relations = try store.relations(worldID: copy.id)
    #expect(relations.first?.sourceID == copiedCaptain.id)
    #expect(relations.first?.label == "lives in")
    #expect(try store.preference("composer:\(copy.id)") == "Ask about \(copiedCaptain.id)")
    #expect(
      try store.boards(worldID: copy.id, kind: "canvas").first?.content.contains(copiedCaptain.id)
        == true)
    let copiedChat = try #require(store.conversations(worldID: copy.id).first)
    #expect(
      try store.messages(worldID: copy.id, conversationID: copiedChat.id).first?.body.contains(
        copiedCaptain.id) == true)
    #expect(try store.records(worldID: world.id).count == 2)
    let secondCopy = try store.importWorldArchive(data)
    #expect(secondCopy.id != copy.id)
  }

  @Test func maliciousCrossWorldImportRollsBack() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Original")
    let other = try store.createWorld(name: "Private")
    let secret = try store.createRecord(
      worldID: other.id, title: "Secret", body: "Hidden", kind: "entity")
    var archive = try JSONDecoder().decode(
      WorldArchive.self, from: store.exportWorldArchive(worldID: world.id))
    archive.tables["message_context"] = [
      [
        "world_id": world.id, "message_id": UUID().uuidString, "record_id": secret.id,
        "reason": "injected", "position": "0",
      ]
    ]
    #expect(throws: (any Error).self) {
      try store.importWorldArchive(JSONEncoder().encode(archive))
    }
    #expect(try store.worlds().count == 2)
    archive.tables["evil_sql"] = []
    #expect(throws: (any Error).self) {
      try store.importWorldArchive(JSONEncoder().encode(archive))
    }
    #expect(try store.records(worldID: other.id).first?.body == "Hidden")
  }
}

struct RelationshipPairTests {
  @Test func inverseRelationshipsSaveTogetherAndCannotCrossWorlds() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Systems")
    let a = try store.createRecord(worldID: world.id, title: "Clan", body: "", kind: "entity")
    let b = try store.createRecord(worldID: world.id, title: "Member", body: "", kind: "entity")
    try store.addRelationshipPair(
      worldID: world.id, source: a.id, target: b.id, label: "protects", inverse: "belongs to")
    let links = try store.relations(worldID: world.id)
    #expect(links.count == 2)
    #expect(links.contains { $0.sourceID == b.id && $0.label == "belongs to" })
    #expect(throws: (any Error).self) {
      try store.addRelationshipPair(
        worldID: world.id, source: a.id, target: b.id, label: "teaches", inverse: "")
    }
    #expect(try store.relations(worldID: world.id).count == 2)
    let other = try store.createWorld(name: "Other")
    #expect(throws: (any Error).self) {
      try store.addRelationshipPair(
        worldID: other.id, source: a.id, target: b.id, label: "protects")
    }
  }
}

struct ExportPathTests {
  @Test func importedCategoryCannotEscapeMarkdownExportFolder() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Portable")
    _ = try store.createRecord(
      worldID: world.id, title: "../../outside", body: "Preserve this writing", kind: "entity",
      category: "../../outside")
    let files = try store.exportMarkdown(worldID: world.id)
    #expect(
      files.allSatisfy { !$0.path.hasPrefix("/") && !$0.path.split(separator: "/").contains("..") })
    #expect(files.contains { $0.content.contains("Preserve this writing") })
  }
}
