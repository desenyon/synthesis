import Foundation
import SynthesisCore
import Testing

@testable import SynthesisUI

@MainActor struct EntitySchemaScopeTests {
  @Test func unfinishedTypeTemplateAndEntityFormsCannotRetargetAfterWorldSwitch() async throws {
    let transport = RecordingResponse()
    let studio = try Studio(store: WorkspaceStore(path: ":memory:"), transport: transport)
    studio.setMode(.manual)
    let original = studio.worldID
    let scope = EntitySchemaScope(worldID: original)
    let draftName = "Unfinished private species"
    let draftFields = [EntityField(key: "ancestry", label: "Ancestry")]
    let existing = try studio.store.saveEntityType(
      worldID: original, name: "Original species", fields: draftFields)
    let other = try studio.store.createWorld(name: "Unrelated world")
    studio.switchWorld(other.id)
    #expect(scope.mismatchMessage(activeWorldID: studio.worldID) != nil)
    #expect(throws: SynthesisError.self) {
      try scope.perform(in: studio) { store, worldID in
        try store.saveEntityType(worldID: worldID, name: draftName, fields: draftFields)
      }
    }
    #expect(throws: SynthesisError.self) {
      try scope.perform(in: studio) { store, worldID in
        try store.saveEntityTemplate(
          worldID: worldID, typeID: existing.id, name: "Private template", body: "Unfinished prose")
      }
    }
    #expect(throws: SynthesisError.self) {
      try scope.perform(in: studio) { store, worldID in
        try store.createTypedEntity(
          worldID: worldID, typeID: existing.id, title: "Private character")
      }
    }
    #expect(try studio.store.entityTypes(worldID: other.id).isEmpty)
    #expect(try studio.store.entityTemplates(worldID: other.id).isEmpty)
    #expect(try studio.store.records(worldID: other.id).isEmpty)
    #expect(try studio.store.entityTypes(worldID: original).map(\.name) == [existing.name])
    studio.switchWorld(original)
    #expect(scope.mismatchMessage(activeWorldID: studio.worldID) == nil)
    let saved = try scope.perform(in: studio) { store, worldID in
      try store.saveEntityType(worldID: worldID, name: draftName, fields: draftFields)
    }
    #expect(saved.worldID == original && saved.name == draftName && saved.fields == draftFields)
    #expect(try studio.store.entityTypes(worldID: other.id).isEmpty)
    #expect(await transport.requests.isEmpty)
  }
  @Test func existingImageExportCollectsPropertyImagesWithoutOpeningADialogOrCallingModels()
    async throws
  {
    let transport = RecordingResponse()
    let studio = try Studio(store: WorkspaceStore(path: ":memory:"), transport: transport)
    let world = try studio.store.createWorld(name: "Images only")
    let other = try studio.store.createWorld(name: "No images")
    studio.switchWorld(world.id)
    let png = Data(
      base64Encoded:
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aAfkAAAAASUVORK5CYII="
    )!
    let type = try studio.store.saveEntityType(
      worldID: world.id, name: "Character",
      fields: [EntityField(key: "portrait", label: "Portrait", kind: .media)])
    let record = try studio.store.createTypedEntity(
      worldID: world.id, typeID: type.id, title: "Mira")
    _ = try studio.store.saveEntityProfile(
      worldID: world.id, recordID: record.id, typeID: type.id,
      values: [
        "portrait": .media(name: "study.png", mime: "image/png", base64: png.base64EncodedString())
      ], expectedVersion: 1)
    let images = try studio.worldImageExportData(worldID: world.id)
    #expect(images.count == 1 && images[0].starts(with: [137, 80, 78, 71]))
    #expect(try studio.worldImageExportData(worldID: other.id).isEmpty)
    _ = try studio.store.saveRecordArtwork(
      worldID: world.id, recordID: record.id, data: png, expectedID: nil)
    #expect(try studio.worldImageExportData(worldID: world.id).count == 1)
    #expect(await transport.requests.isEmpty)
  }

}
