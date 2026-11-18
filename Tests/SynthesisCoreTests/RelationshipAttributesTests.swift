import Foundation
import Testing

@testable import SynthesisCore

struct RelationshipAttributesTests {
  @Test func legacyLabelsStayUnknownAndOneEdgeIsVisibleFromBothEndpoints() throws {
    let decoded = try JSONDecoder().decode(
      Relation.self,
      from: Data(#"{"id":"r","sourceID":"a","targetID":"b","label":"mentors"}"#.utf8))
    #expect(decoded.state == "draft")
    #expect(decoded.revision == 1)
    #expect(decoded.attributes == .init())

    let (store, world, first, second) = try Self.fixture()
    let edge = try store.addRelation(
      worldID: world.id, source: first.id, target: second.id, label: "mentors")
    #expect(edge.attributes.kind == .unknown)
    #expect(try store.relations(worldID: world.id, recordID: first.id) == [edge])
    #expect(try store.relations(worldID: world.id, recordID: second.id) == [edge])
    #expect(try store.relations(worldID: world.id) == [edge])
  }

  @Test func attributeEditsWriteHistoryAndActivityAndKeepArchivedEvidence() throws {
    let (store, world, first, second) = try Self.fixture()
    let witness = try store.createRecord(worldID: world.id, title: "Witness account")
    var attributes = RelationshipAttributes()
    attributes.kind = .mentor
    attributes.evidenceRecordIDs = [witness.id]
    let original = try store.addRelation(
      worldID: world.id, source: first.id, target: second.id, label: "mentors",
      attributes: attributes)
    try store.archiveRecord(worldID: world.id, id: witness.id)
    attributes.strength = .strong
    let edited = try store.updateRelation(
      worldID: world.id, expected: original, label: original.label, attributes: attributes)

    #expect(edited.attributes == attributes)
    #expect(edited.state == "draft")
    #expect(edited.revision == original.revision + 1)
    #expect(try store.relations(worldID: world.id, recordID: second.id) == [edited])
    #expect(throws: SynthesisError.self) {
      try store.updateRelation(
        worldID: world.id, expected: original, label: "Stale edit", attributes: .init())
    }
    #expect(throws: SynthesisError.self) {
      try store.archiveRelation(worldID: world.id, id: original.id, expected: original)
    }
    let history = try store.db.rows(
      "SELECT * FROM relationship_history WHERE world_id=? AND relationship_id=?",
      [world.id, original.id])
    let previousAttributes = try #require(history.first?["attributes"])
    #expect(try RelationshipAttributes.decodeStored(previousAttributes) == original.attributes)
    #expect(history.first?["revision"] == String(original.revision))
    #expect(history.count == 1)
    let activity = try store.worldChangeHistory(worldID: world.id, kind: .relationship)
    #expect(activity.first?.action == .updated)
    #expect(activity.first?.detail.contains("Relationship details updated") == true)

    try store.updateRelation(worldID: world.id, id: edited.id, label: "guides")
    try store.archiveRelation(worldID: world.id, id: edited.id)
    #expect(try store.relations(worldID: world.id, recordID: first.id).isEmpty)
    #expect(try store.relations(worldID: world.id, recordID: second.id).isEmpty)
    try store.restoreRelation(worldID: world.id, id: edited.id)
    let restored = try #require(try store.relations(worldID: world.id).first)
    #expect(restored.id == edited.id && restored.label == "guides")
    #expect(restored.attributes == attributes && restored.revision == edited.revision + 3)
    #expect(try store.record(worldID: world.id, id: first.id).canonical == nil)
  }

  @Test func rejectsUnscopedAttributesAndKeepsImportedCanonReadOnly() throws {
    let (store, world, first, second) = try Self.fixture()
    let other = try store.createWorld(name: "Another world")
    let foreign = try store.createRecord(worldID: other.id, title: "Foreign evidence")
    var attributes = RelationshipAttributes()
    attributes.evidenceRecordIDs = [foreign.id]
    #expect(throws: SynthesisError.self) {
      try store.addRelation(
        worldID: world.id, source: first.id, target: second.id, label: "protects",
        attributes: attributes)
    }
    attributes.evidenceRecordIDs = []
    attributes.startLabel = String(repeating: "x", count: RelationshipAttributes.dateLabelLimit + 1)
    #expect(throws: SynthesisError.self) {
      try store.addRelation(
        worldID: world.id, source: first.id, target: second.id, label: "protects",
        attributes: attributes)
    }
    #expect(try store.relations(worldID: world.id).isEmpty)
    try store.archiveRecord(worldID: world.id, id: second.id)
    #expect(throws: SynthesisError.self) {
      try store.addRelation(
        worldID: world.id, source: first.id, target: second.id, label: "protects")
    }
    try store.restoreRecord(worldID: world.id, id: second.id)
    let edge = try store.addRelation(
      worldID: world.id, source: first.id, target: second.id, label: "protects")
    #expect(throws: SynthesisError.self) {
      try store.updateRelation(
        worldID: other.id, expected: edge, label: "moved", attributes: .init())
    }

    let archive = try store.exportWorldArchive(worldID: world.id)
    var acceptedArchive = try JSONDecoder().decode(WorldArchive.self, from: archive)
    acceptedArchive.tables["relationships"]?[0]["state"] = "canon"
    let imported = try store.importWorldArchive(JSONEncoder().encode(acceptedArchive))
    let established = try #require(try store.relations(worldID: imported.id).first)
    #expect(established.state == "canon")
    attributes = .init()
    attributes.status = .ended
    #expect(throws: SynthesisError.self) {
      try store.updateRelation(
        worldID: imported.id, expected: established, label: established.label,
        attributes: attributes)
    }
    #expect(throws: SynthesisError.self) {
      try store.archiveRelation(worldID: imported.id, id: established.id)
    }
    #expect(try store.relations(worldID: imported.id) == [established])
  }

  @Test func portableArchivesPreserveDetailsAndRemapOnlyEvidenceAddresses() throws {
    let (store, world, first, second) = try Self.fixture()
    let evidence = try store.createRecord(worldID: world.id, title: "Testimony")
    var attributes = RelationshipAttributes()
    attributes.kind = .politicalSuperior
    attributes.startLabel = "Recordkeeping era \(evidence.id)"
    attributes.endLabel = "After the winter moot"
    attributes.strength = .moderate
    attributes.secrecy = .secret
    attributes.mutuality = .oneSided
    attributes.status = .ended
    attributes.evidenceRecordIDs = [evidence.id]
    let edge = try store.addRelation(
      worldID: world.id, source: first.id, target: second.id, label: "commands",
      attributes: attributes)
    try store.updateRelation(worldID: world.id, id: edge.id, label: "led")

    let archive = try store.exportWorldArchive(worldID: world.id)
    let portable = try JSONDecoder().decode(WorldArchive.self, from: archive)
    #expect(portable.version == 12)
    let copy = try store.importWorldArchiveMapping(archive)
    let copiedEdge = try #require(try store.relations(worldID: copy.world.id).first)
    var expected = attributes
    expected.evidenceRecordIDs = [try #require(copy.ids[evidence.id])]
    #expect(copiedEdge.attributes == expected)
    let history = try store.db.rows(
      "SELECT attributes FROM relationship_history WHERE world_id=?", [copy.world.id])
    #expect(
      try RelationshipAttributes.decodeStored(try #require(history.first?["attributes"]))
        == expected)

    var old = portable
    old.version = 10
    for table in ["relationships", "relationship_history"] {
      old.tables[table] = old.tables[table]?.map { row in
        row.filter { $0.key != "attributes" && $0.key != "revision" }
      }
    }
    let legacy = try store.importWorldArchive(JSONEncoder().encode(old))
    let legacyEdge = try #require(try store.relations(worldID: legacy.id).first)
    #expect(legacyEdge.attributes == .init() && legacyEdge.revision == 1)

    let count = try store.worlds().count
    for (table, badValue) in [
      ("relationships", #"{"kind":"invalid"}"#),
      ("relationships", "{\"evidenceRecordIDs\":[\"\(UUID().uuidString)\"]}"),
      ("relationship_history", "{\"evidenceRecordIDs\":[\"\(edge.id)\"]}"),
    ] {
      var malformed = portable
      malformed.tables[table]?[0]["attributes"] = badValue
      #expect(throws: (any Error).self) {
        try store.importWorldArchive(JSONEncoder().encode(malformed))
      }
      #expect(try store.worlds().count == count)
    }

    let markdown = try #require(
      try store.exportMarkdown(worldID: world.id).first { $0.path == "Relationships.md" })
    #expect(
      markdown.content.contains("Political superior") && markdown.content.contains("Testimony"))
    try store.archiveRecord(worldID: world.id, id: second.id)
    let json = try #require(
      JSONSerialization.jsonObject(with: store.exportWorld(world.id)) as? [String: Any])
    let hidden = try #require((json["hiddenRelationships"] as? [[String: String]])?.first)
    #expect(json["schemaVersion"] as? Int == 15)
    #expect(hidden["id"] == edge.id)
    #expect(
      try RelationshipAttributes.decodeStored(try #require(hidden["attributes"])) == attributes)
  }

  @Test func reviewedLabelOnlyProposalRetainsNewerRelationshipAttributes() throws {
    let (store, world, first, second) = try Self.fixture()
    let edge = try store.addRelation(
      worldID: world.id, source: first.id, target: second.id, label: "knows")
    let proposal = try #require(
      try store.stageProposal(
        worldID: world.id, conversationID: nil, messageID: nil,
        payload: [
          "changes": [["action": "revise_relationship", "id": edge.id, "label": "guided by"]]
        ]))
    var attributes = RelationshipAttributes()
    attributes.kind = .mentor
    try store.updateRelation(
      worldID: world.id, expected: edge, label: edge.label, attributes: attributes)
    let accepted = try store.resolveChange(
      worldID: world.id, proposalID: proposal.id, changeID: proposal.changes[0].id, accept: true,
      confirmation: proposal.id)
    let updated = try #require(try store.relations(worldID: world.id).first)
    #expect(accepted.changes[0].status == "accepted")
    #expect(updated.label == "guided by" && updated.attributes == attributes)
    #expect(updated.state == "draft")
  }

  private static func fixture() throws -> (WorkspaceStore, World, LoreRecord, LoreRecord) {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Relationships")
    let first = try store.createRecord(worldID: world.id, title: "Mira", kind: "entity")
    let second = try store.createRecord(worldID: world.id, title: "Tidekeepers", kind: "entity")
    return (store, world, first, second)
  }
}
