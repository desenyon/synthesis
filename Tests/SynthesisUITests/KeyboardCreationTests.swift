import Foundation
import SynthesisCore
import Testing

@testable import SynthesisUI

@MainActor struct KeyboardCreationTests {
  @Test func creationCommandsShareTheFormAndRespectUnsavedWriting() throws {
    let studio = try Studio(store: WorkspaceStore(path: ":memory:"))
    studio.setMode(.manual)
    studio.sheet = nil
    let count = studio.records.count
    studio.editorSave = { false }
    studio.beginRecordCreation(kind: "entity")
    studio.createRecord(title: "Must not create", kind: "entity")
    #expect(studio.sheet == nil && studio.records.count == count)
    studio.editorSave = nil
    let command = try #require(
      CommandPalette.results(studio: studio, query: "New entity", indexed: []).first {
        $0.id == "new-entity"
      })
    #expect(command.detail == "⌥⌘N")
    command.run()
    #expect(studio.newRecordKind == "entity" && studio.sheet == .document)
    studio.beginRecordCreation(kind: "capture")
    #expect(studio.newRecordKind == "entity")
    studio.createRecord(title: "New cartographer", kind: "entity", category: "Characters")
    #expect(studio.sheet == nil && studio.selectedRecord?.title == "New cartographer")
    #expect(studio.selectedRecord?.state == "draft" && studio.selectedRecord?.canonical == nil)
    #expect(studio.mode == .manual && !studio.busy)
  }

  @Test func referencesAndDirectionalRelationshipsPersistWithoutChangingCanon() throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    let path = folder.appendingPathComponent("world.sqlite").path
    let studio = try Studio(store: WorkspaceStore(path: path))
    let world = studio.worldID
    let a = try studio.store.createRecord(worldID: world, title: "Mira", kind: "entity")
    let b = try studio.store.createRecord(worldID: world, title: "Tidekeepers", kind: "entity")
    let prose = try studio.store.createRecord(worldID: world, title: "A crossing")
    try studio.reload()
    var draft = RecordLinkDraft(worldID: world, sourceID: prose.id, targetID: a.id)
    draft.kind = .reference
    #expect(studio.saveRecordLink(draft))
    #expect(studio.saveRecordLink(draft))
    #expect(try studio.store.linkedRecords(worldID: world, id: prose.id).map(\.id) == [a.id])
    #expect(
      try studio.store.linkedRecords(worldID: world, id: a.id, incoming: true).map(\.id) == [
        prose.id
      ])
    draft = RecordLinkDraft(worldID: world, sourceID: a.id, targetID: b.id, label: " guided by ")
    draft.reverse = true
    draft.reverseLabel = "guides"
    #expect(studio.saveRecordLink(draft))
    let reopened = try WorkspaceStore(path: path)
    let relations = try reopened.relations(worldID: world)
    #expect(relations.count == 2)
    #expect(
      relations.contains { $0.sourceID == a.id && $0.targetID == b.id && $0.label == "guided by" })
    #expect(
      relations.contains { $0.sourceID == b.id && $0.targetID == a.id && $0.label == "guides" })
    #expect(try reopened.record(worldID: world, id: a.id) == a)
    #expect(try reopened.record(worldID: world, id: b.id) == b)
    #expect(try reopened.record(worldID: world, id: prose.id) == prose)
  }

  @Test func failedSavesAndStaleOrForeignEndpointsCannotCreateLinks() throws {
    let studio = try Studio(store: WorkspaceStore(path: ":memory:"))
    studio.sheet = nil
    let world = studio.worldID
    let a = try studio.store.createRecord(worldID: world, title: "Mira", kind: "entity")
    let b = try studio.store.createRecord(worldID: world, title: "Coast", kind: "entity")
    try studio.reload()
    let draft = RecordLinkDraft(worldID: world, sourceID: a.id, targetID: b.id, label: "maps")
    studio.editorSave = { false }
    studio.beginLinkRecords()
    #expect(studio.sheet == nil && !studio.saveRecordLink(draft))
    studio.editorSave = nil
    var invalid = draft
    invalid.reverse = true
    invalid.reverseLabel = String(repeating: "x", count: 81)
    #expect(!studio.saveRecordLink(invalid))
    #expect(try studio.store.relations(worldID: world).isEmpty)
    try studio.store.archiveRecord(worldID: world, id: b.id)
    #expect(!studio.saveRecordLink(draft))
    invalid.kind = .reference
    #expect(!studio.saveRecordLink(invalid))
    let other = try studio.store.createWorld(name: "Other")
    try studio.reload()
    studio.switchWorld(other.id)
    #expect(!studio.saveRecordLink(draft))
    #expect(try studio.store.relations(worldID: world).isEmpty)
    #expect(try studio.store.linkedRecords(worldID: world, id: a.id).isEmpty)
  }

  @Test func linkingUsesTheFocusedRecordOrCurrentSpatialSelection() throws {
    let studio = try Studio(store: WorkspaceStore(path: ":memory:"))
    studio.sheet = nil
    studio.setMode(.manual)
    let a = try studio.store.createRecord(worldID: studio.worldID, title: "Mira", kind: "entity")
    let b = try studio.store.createRecord(worldID: studio.worldID, title: "Coast", kind: "entity")
    try studio.reload()
    studio.openRecord(a)
    studio.beginLinkRecords()
    #expect(studio.recordLinkDraft?.sourceID == a.id)
    studio.sheet = nil
    studio.beginRelationship(sourceID: a.id, targetID: b.id, entitiesOnly: true)
    #expect(
      studio.recordLinkDraft?.targetID == b.id && studio.recordLinkDraft?.entitiesOnly == true)
    studio.sheet = nil
    studio.navigate(.knowledge)
    studio.graphSelectedID = b.id
    studio.beginLinkRecords()
    #expect(studio.recordLinkDraft?.sourceID == b.id)
    studio.sheet = nil
    studio.navigate(.timeline)
    studio.atlasSelectedID = a.id
    studio.beginLinkRecords()
    #expect(studio.recordLinkDraft?.sourceID.isEmpty == true)
    #expect(studio.mode == .manual && !studio.busy)
  }
}
