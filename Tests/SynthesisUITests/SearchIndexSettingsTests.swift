import Foundation
import SynthesisCore
import Testing

@testable import SynthesisUI

@MainActor struct SearchIndexSettingsTests {
  @Test func rebuildsTheWorldShownInSettingsAndPreservesAnotherWorld() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
      UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = try WorkspaceStore(path: directory.appendingPathComponent("workspace.sqlite").path)
    let world = try store.createWorld(name: "Aster")
    let other = try store.createWorld(name: "Halcyon")
    let record = try Self.staleFixture(store: store, worldID: world.id)
    let foreignRecord = try Self.staleFixture(store: store, worldID: other.id)
    let model = SearchIndexSettingsModel(store: store, worldID: world.id)
    #expect(SettingsItem.matching("search indexes", section: .general).map(\.id) == [.searchIndex])

    await model.run(rebuild: false)
    #expect(model.state == .checked([.entityProperties], rebuilt: false))
    await model.run(rebuild: true)
    #expect(model.state == .checked([], rebuilt: true))
    #expect(
      try store.search(worldID: world.id, query: "Ultramarine").map(\.id)
        .contains(record.id))
    #expect(try store.staleSearchIndexes(worldID: other.id) == [.entityProperties])
    #expect(
      !((try store.search(worldID: other.id, query: "Ultramarine")).map(\.id)
        .contains(foreignRecord.id)))
  }

  @Test func missingWorldReportsAnErrorAndCanRetry() async throws {
    let store = try WorkspaceStore(path: ":memory:")
    let model = SearchIndexSettingsModel(store: store, worldID: "missing")
    await model.run(rebuild: false)
    guard case .failed = model.state else {
      Issue.record("A missing maintenance world must fail.")
      return
    }
    #expect(!model.state.isWorking)
    await model.run(rebuild: true)
    guard case .failed = model.state else {
      Issue.record("A missing maintenance world must fail during rebuild.")
      return
    }
  }

  private static func staleFixture(store: WorkspaceStore, worldID: String) throws -> LoreRecord {
    let place = try store.createRecord(worldID: worldID, title: "Old Harbour", kind: "entity")
    let type = try store.saveEntityType(
      worldID: worldID, name: "Navigator",
      fields: [.init(key: "home", label: "Home", kind: .entity)],
      defaults: ["home": .entity(place.id)])
    let record = try store.createTypedEntity(
      worldID: worldID, typeID: type.id, title: "Cartographer")
    _ = try store.saveRecord(
      worldID: worldID, id: place.id, version: place.version, title: "Ultramarine Harbour",
      body: place.body, rtf: place.rtf)
    return record
  }
}
