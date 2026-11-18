import Foundation
import Testing

@testable import SynthesisCore

struct StructuredFactsTests {
  private static func fixture() throws -> (WorkspaceStore, World, LoreRecord, LoreRecord) {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "The Coast")
    let entity = try store.createRecord(worldID: world.id, title: "Mira", kind: "entity")
    let source = try store.createRecord(worldID: world.id, title: "Arrival", body: "First entry.")
    return (store, world, entity, source)
  }

  @Test func importRejectsAnExhaustedFactVersion() throws {
    let (store, world, entity, _) = try Self.fixture()
    _ = try store.createStructuredFact(
      worldID: world.id, subjectID: entity.id, predicate: "Title",
      draft: .init(value: .text("Keeper")))
    var archive = try JSONDecoder().decode(
      WorldArchive.self, from: store.exportWorldArchive(worldID: world.id))
    archive.tables["structured_facts"]?[0]["version"] = String(Int.max)
    let payload = try JSONEncoder().encode(archive)
    #expect(throws: SynthesisError.self) { try store.importWorldArchive(payload) }
    #expect(try store.worlds().map(\.id) == [world.id])
  }

  @Test func explicitApprovalFreezesTheExactRevisionAndProvenance() throws {
    let (store, world, entity, source) = try Self.fixture()
    let evidence = try store.structuredFactEvidence(worldID: world.id, recordID: source.id)
    let first = try store.createStructuredFact(
      worldID: world.id, subjectID: entity.id, predicate: "Title",
      draft: .init(value: .text("Keeper"), evidence: evidence))
    #expect(first.accepted == nil && first.working.status == .draft)
    #expect(throws: SynthesisError.self) {
      try store.approveStructuredFact(worldID: world.id, expected: first, confirmation: source.id)
    }
    let approved = try store.approveStructuredFact(
      worldID: world.id, expected: first, confirmation: first.working.id)
    #expect(approved.accepted?.value == .text("Keeper"))
    #expect(approved.accepted?.evidence == evidence)
    #expect(approved.accepted?.author == "Local creator")
    let dispute = try store.reviseStructuredFact(
      worldID: world.id, expected: approved, draft: .init(value: .text("Warden"), disputed: true))
    #expect(dispute.working.status == .disputed)
    #expect(dispute.accepted == approved.accepted)
    #expect(
      try store.structuredFacts(worldID: world.id, subjectID: entity.id, predicate: "title") == [
        dispute
      ])
    #expect(throws: SynthesisError.self) {
      try store.approveStructuredFact(
        worldID: world.id, expected: approved, confirmation: approved.working.id)
    }
    #expect(throws: SynthesisError.self) {
      try store.approveStructuredFact(
        worldID: world.id, expected: dispute, confirmation: dispute.working.id)
    }
    let _ = try store.saveRecord(
      worldID: world.id, id: source.id, version: source.version, title: "Changed",
      body: "New writing", rtf: nil)
    try store.archiveRecord(worldID: world.id, id: source.id)
    #expect(
      try store.structuredFactSource(worldID: world.id, evidence: evidence).body == "First entry.")
    #expect(
      try store.structuredFactHistory(worldID: world.id, factID: first.id).map(\.status) == [
        .draft, .canon, .disputed,
      ])
    #expect(try store.record(worldID: world.id, id: entity.id) == entity)

    let archived = try store.setStructuredFactArchived(
      worldID: world.id, expected: dispute, archived: true)
    #expect(try store.structuredFacts(worldID: world.id, subjectID: entity.id).isEmpty)
    let restored = try store.setStructuredFactArchived(
      worldID: world.id, expected: archived, archived: false)
    #expect(restored.working == dispute.working && restored.accepted == approved.accepted)
    #expect(throws: SynthesisError.self) {
      try store.setStructuredFactArchived(worldID: world.id, expected: archived, archived: false)
    }
  }

  @Test func subjectValuesAndEvidenceAreScopedAndValidatedBeforeSaving() throws {
    let (store, world, entity, source) = try Self.fixture()
    let other = try store.createWorld(name: "The Hills")
    let foreign = try store.createRecord(worldID: other.id, title: "Foreign", kind: "entity")
    let foreignSource = try store.structuredFactEvidence(worldID: other.id, recordID: foreign.id)
    let invalidDrafts: [StructuredFactDraft] = [
      .init(value: .entity(foreign.id)), .init(value: .entity(source.id)),
      .init(value: .text("Value"), evidence: foreignSource), .init(value: .text(" \0 ")),
    ]
    for draft in invalidDrafts {
      #expect(throws: SynthesisError.self) {
        try store.createStructuredFact(
          worldID: world.id, subjectID: entity.id, predicate: "Place", draft: draft)
      }
    }
    #expect(try store.structuredFacts(worldID: world.id, subjectID: entity.id).isEmpty)
    try store.archiveRecord(worldID: world.id, id: entity.id)
    #expect(throws: SynthesisError.self) {
      try store.createStructuredFact(
        worldID: world.id, subjectID: entity.id, predicate: "Place",
        draft: .init(value: .text("Coast")))
    }
  }

  @Test func archiveRemapsFactEntityAndSourceIDsAndPreservesLiteralText() throws {
    let (store, world, entity, source) = try Self.fixture()
    let evidence = try store.structuredFactEvidence(worldID: world.id, recordID: source.id)
    let first = try store.createStructuredFact(
      worldID: world.id, subjectID: entity.id, predicate: "Ref",
      draft: .init(value: .entity(entity.id), evidence: evidence))
    let literal = "Text \(entity.id)"
    let _ = try store.reviseStructuredFact(
      worldID: world.id, expected: first, draft: .init(value: .text(literal), evidence: evidence))
    let archive = try store.exportWorldArchive(worldID: world.id)
    let copy = try store.importWorldArchiveMapping(archive)
    let copySubject = try #require(copy.ids[entity.id])
    let copyFacts = try store.structuredFacts(worldID: copy.world.id, subjectID: copySubject)
    let copied = try #require(copyFacts.first)
    #expect(copied.id == copy.ids[first.id] && copied.working.value == .text(literal))
    #expect(copied.working.evidence?.recordID == copy.ids[source.id])
    let history = try store.structuredFactHistory(worldID: copy.world.id, factID: copied.id)
    #expect(history.first?.value == .entity(copySubject))
    let markdown = try store.exportRecordMarkdown(worldID: world.id, recordID: entity.id)
    #expect(markdown.content.contains("Structured facts") && markdown.content.contains(literal))
    let json = try #require(
      JSONSerialization.jsonObject(with: store.exportWorld(world.id)) as? [String: Any])
    #expect((json["structuredFacts"] as? [[String: String]])?.count == 1)
    #expect((json["structuredFactRevisions"] as? [[String: String]])?.count == 2)

    var legacy = try JSONDecoder().decode(WorldArchive.self, from: archive)
    legacy.version = 12
    legacy.tables.removeValue(forKey: "structured_facts")
    legacy.tables.removeValue(forKey: "structured_fact_revisions")
    let old = try store.importWorldArchiveMapping(JSONEncoder().encode(legacy))
    let oldSubject = try #require(old.ids[entity.id])
    #expect(try store.structuredFacts(worldID: old.world.id, subjectID: oldSubject).isEmpty)
    var invalid = try JSONDecoder().decode(WorldArchive.self, from: archive)
    invalid.tables["structured_facts"]?[0]["accepted_revision"] = "1"
    let count = try store.worlds().count
    #expect(throws: SynthesisError.self) {
      try store.importWorldArchive(JSONEncoder().encode(invalid))
    }
    #expect(try store.worlds().count == count)
  }

  @Test func committedFactChangesAppearInSubjectActivity() throws {
    let (store, world, subject, _) = try Self.fixture()
    let draft = try store.createStructuredFact(
      worldID: world.id, subjectID: subject.id, predicate: "Title",
      draft: .init(value: .text("Keeper")))
    let canon = try store.approveStructuredFact(
      worldID: world.id, expected: draft, confirmation: draft.working.id)
    let disputed = try store.reviseStructuredFact(
      worldID: world.id, expected: canon, draft: .init(value: .text("Warden"), disputed: true))
    let archived = try store.setStructuredFactArchived(
      worldID: world.id, expected: disputed, archived: true)
    try store.setStructuredFactArchived(worldID: world.id, expected: archived, archived: false)
    let activity = try store.worldChangeHistory(worldID: world.id, kind: .record)
      .filter { $0.detail.hasPrefix("Fact ") }
    let actions: [WorldChange.Action] = [.restored, .archived, .updated, .approved, .created]
    #expect(activity.map(\.action) == actions)
    #expect(activity.allSatisfy { $0.objectID == subject.id && $0.revision == nil })

    let copy = try store.importWorldArchiveMapping(store.exportWorldArchive(worldID: world.id))
    let copied = try store.worldChangeHistory(worldID: copy.world.id, kind: .record)
      .filter { $0.detail.hasPrefix("Fact ") }
    #expect(copied.map(\.action) == actions)
    #expect(copied.allSatisfy { $0.objectID == copy.ids[subject.id] })
  }
}
