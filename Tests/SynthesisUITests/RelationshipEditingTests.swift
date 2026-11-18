import SynthesisCore
import Testing

@testable import SynthesisUI

@MainActor struct RelationshipEditingTests {
  @Test func creatingAndEditingRelationshipsUsesTheSameAttributesAndEvidence() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let studio = try Studio(store: store)
    let world = studio.worldID
    let mentor = try store.createRecord(worldID: world, title: "Mira", kind: "entity")
    let pupil = try store.createRecord(worldID: world, title: "Oren", kind: "entity")
    let evidence = try store.createRecord(worldID: world, title: "Apprenticeship register")
    try studio.reload()

    var draft = RecordLinkDraft(worldID: world, sourceID: mentor.id, targetID: pupil.id)
    draft.label = "teaches"
    draft.attributes.kind = .mentor
    draft.attributes.startLabel = "Around the ninth winter"
    draft.attributes.strength = .strong
    draft.attributes.secrecy = .restricted
    draft.attributes.mutuality = .mutual
    draft.attributes.status = .active
    draft.attributes.evidenceRecordIDs = [evidence.id]
    #expect(studio.saveRecordLink(draft))

    let created = try #require(try store.relations(worldID: world).first)
    let target = RelationshipEditTarget(worldID: world, relation: created)
    var attributes = created.attributes
    attributes.kind = .formerAlly
    attributes.endLabel = "Before the council met"
    attributes.status = .ended
    #expect(studio.saveRelationshipEdit(target, label: "once worked with", attributes: attributes))
    #expect(!studio.saveRelationshipEdit(target, label: "stale change", attributes: .init()))

    let inspection = try studio.inspectionData(for: .relationship(created.id))
    #expect(inspection.title == "once worked with")
    #expect(
      inspection.properties.contains { $0.name == "Meaning" && $0.value == attributes.kind.title })
    #expect(inspection.properties.contains { $0.name == "End" && $0.value == attributes.endLabel })
    #expect(
      inspection.references.contains {
        $0.target == .record(evidence.id) && $0.detail == "Evidence"
      })
    #expect(!studio.archiveRelationship(target))
    let edited = try #require(try store.relations(worldID: world).first)
    #expect(studio.archiveRelationship(RelationshipEditTarget(worldID: world, relation: edited)))
    #expect(try store.relations(worldID: world).isEmpty)
    let undo = try #require(studio.toast?.action)
    undo()
    let restored = try #require(try store.relations(worldID: world).first)
    #expect(restored.id == created.id && restored.attributes == attributes)

    try store.archiveRecord(worldID: world, id: evidence.id)
    try studio.reload()
    let archivedEvidence = try studio.inspectionData(for: .relationship(created.id))
    #expect(!archivedEvidence.references.contains { $0.target == .record(evidence.id) })
    #expect(
      archivedEvidence.properties.contains {
        $0.name == "Evidence" && $0.value == "1 unavailable"
      })
  }

  @Test func relationshipFormsDoNotWriteAfterTheWorldChanges() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let studio = try Studio(store: store)
    let origin = studio.worldID
    let a = try store.createRecord(worldID: origin, title: "Mira", kind: "entity")
    let b = try store.createRecord(worldID: origin, title: "Oren", kind: "entity")
    let relationship = try store.addRelation(
      worldID: origin, source: a.id, target: b.id, label: "trusts")
    let before = RelationshipEditTarget(worldID: origin, relation: relationship)
    let other = try store.createWorld(name: "Another world")
    studio.switchWorld(other.id)

    #expect(!studio.saveRelationshipEdit(before, label: "betrayed", attributes: .init()))
    #expect(!studio.archiveRelationship(before))
    #expect(try store.relations(worldID: origin) == [relationship])
    #expect(try store.relations(worldID: other.id).isEmpty)
  }
}
