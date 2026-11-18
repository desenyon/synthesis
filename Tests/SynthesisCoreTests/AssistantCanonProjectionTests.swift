import Foundation
import Testing

@testable import SynthesisCore

struct AssistantCanonProjectionTests {
  @Test func projectionUsesTheFrozenRevisionAfterDraftMetadataAndTextChange() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Coast")
    let created = try store.createRecord(
      worldID: world.id, title: "Veil Lighthouse", kind: "entity", category: "Places")
    let frozen = try store.saveRecord(
      worldID: world.id, id: created.id, version: created.version, title: created.title,
      body: "A moonstone lantern lights the harbor.", rtf: "FROZEN_RICH_TEXT",
      tags: ["navigation"], aliases: ["Old Beacon"])
    let accepted = try store.promote(
      worldID: world.id, id: frozen.id, version: frozen.version, confirmation: frozen.id)
    let current = try store.saveRecord(
      worldID: world.id, id: accepted.id, version: accepted.version, title: "Private new name",
      body: "Unaccepted changes", rtf: "DRAFT_RICH_TEXT", category: "Private category",
      tags: ["private-tag"], aliases: ["Private alias"])
    let source = try #require(WorkspaceStore.assistantAcceptedRecords([current]).first)
    #expect(source.id == frozen.id && source.worldID == world.id)
    #expect(source.title == "Veil Lighthouse")
    #expect(source.body == "A moonstone lantern lights the harbor.")
    #expect(source.category == "Places" && source.kind == "entity")
    #expect(source.tags == ["navigation"] && source.aliases == ["Old Beacon"])
    #expect(source.version == frozen.version && source.state == "canon")
    #expect(source.rtf == nil && source.canonical == nil)
  }

  @Test func projectionRejectsMissingMalformedAndMismatchedSnapshots() throws {
    let frozen = record(id: "record-A", title: "Accepted title", body: "Accepted text")
    var current = frozen
    current.title = "Private draft name"
    current.body = "Private draft body"
    current.state = "canon"
    current.version += 1
    #expect(WorkspaceStore.assistantAcceptedRecords([current]).isEmpty)
    current.canonical = #"{"body":"Incomplete snapshot"}"#
    #expect(WorkspaceStore.assistantAcceptedRecords([current]).isEmpty)
    current.canonical = "{"
    #expect(WorkspaceStore.assistantAcceptedRecords([current]).isEmpty)

    var wrongID = frozen
    wrongID.id = "record-B"
    var wrongWorld = frozen
    wrongWorld.worldID = "world-B"
    var wrongKind = frozen
    wrongKind.kind = "entity"
    var wrongState = frozen
    wrongState.state = "unsupported"
    var wrongVersion = frozen
    wrongVersion.version = current.version
    for corrupt in [wrongID, wrongWorld, wrongKind, wrongState, wrongVersion] {
      current.canonical = try encoded(corrupt)
      #expect(WorkspaceStore.assistantAcceptedRecords([current]).isEmpty)
    }

    var legacy = frozen
    legacy.canonical = "The pre-existing snapshot retained by older builds."
    current.canonical = try encoded(legacy)
    let result = try #require(WorkspaceStore.assistantAcceptedRecords([current]).first)
    #expect(result.title == frozen.title && result.canonical == nil)
  }

  @Test func indexBoundsAndPrioritizesOnlyProjectedRecordSummaries() throws {
    let input = try (1...103).map { number in
      try updated(record(id: "record-\(number)", title: "Accepted \(number)", body: "BODY_MARKER"))
    }
    let projected = WorkspaceStore.assistantAcceptedRecords(input)
    let index = try WorkspaceStore.assistantAcceptedContextIndex(
      projected, prioritizedIDs: ["record-103", "record-103", "missing", "record-102"])
    let decoded = try #require(
      JSONSerialization.jsonObject(with: Data(index.utf8)) as? [String: Any])
    let summaries = try #require(decoded["records"] as? [[String: String]])
    #expect(summaries.count == 100)
    #expect(summaries.prefix(2).compactMap { $0["id"] } == ["record-103", "record-102"])
    #expect(summaries.allSatisfy { $0["state"] == "canon" })
    #expect((decoded["totals"] as? [String: Int])?["records"] == 103)
    #expect(!index.contains("PRIVATE_DRAFT") && !index.contains("BODY_MARKER"))
    #expect(Set(decoded.keys) == ["records", "totals"])
  }

  @Test func rankMatchesOnlyAcceptedText() throws {
    var unrelated = record(id: "newer", title: "West harbor", body: "Quiet tides")
    unrelated.updatedAt = "2026-11-17T12:00:00Z"
    var newerDraft = try updated(unrelated)
    newerDraft.title = "Moonstone"
    newerDraft.body = "Moonstone deposits dot the shore."
    let grounded = try updated(
      record(id: "accepted", title: "North harbor", body: "The moonstone lighthouse still stands."))
    let projected = WorkspaceStore.assistantAcceptedRecords([newerDraft, grounded])
    #expect(projected.first?.id == "newer")
    let ranked = WorkspaceStore.assistantAcceptedSources(
      projected, prompt: "Where is the moonstone?", limit: 1)
    #expect(ranked.map(\.id) == ["accepted"])
    #expect(ranked.first?.record.title == "North harbor")
  }

  private func record(id: String, title: String, body: String) -> LoreRecord {
    LoreRecord(
      id: id, worldID: "world-A", title: title, body: body, kind: "lore", category: "",
      state: "draft", origin: "user-authored", version: 1, canonical: nil, rtf: nil,
      updatedAt: "2026-11-17T00:00:00Z", tags: nil, aliases: nil)
  }

  private func updated(_ frozen: LoreRecord) throws -> LoreRecord {
    var current = frozen
    current.version += 2
    current.title = "PRIVATE_DRAFT"
    current.body = "PRIVATE_DRAFT"
    current.updatedAt = "2026-11-18T00:00:00Z"
    current.canonical = try encoded(frozen)
    return current
  }

  private func encoded(_ record: LoreRecord) throws -> String {
    String(decoding: try JSONEncoder().encode(record), as: UTF8.self)
  }
}
