import Foundation
import SynthesisCore
import Testing

@testable import SynthesisUI

@MainActor struct FavoritesTests {
  @Test func favoritesPersistIndependentlyOfOpenTabsAndTrackRenames() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let path = directory.appendingPathComponent("world.sqlite").path
    let store = try WorkspaceStore(path: path)
    let studio = try Studio(store: store)
    let record = try store.createRecord(
      worldID: studio.worldID, title: "Mira", body: "A cartographer", kind: "entity",
      category: "Characters")
    try studio.reload()
    studio.setFavorite(record, enabled: true)
    studio.pinSidebarCategory("Places", pinned: true)
    studio.openRecord(record)
    studio.closeDocument(record.id)
    #expect(studio.isFavorite(record.id) && studio.selectedRecord == nil)
    #expect(try store.record(worldID: studio.worldID, id: record.id) == record)
    let renamed = try store.saveRecord(
      worldID: studio.worldID, id: record.id, version: record.version,
      title: "Mira Vale", body: record.body, rtf: nil)
    let reopened = try Studio(store: WorkspaceStore(path: path))
    #expect(reopened.favoriteRecords == [renamed])
    #expect(reopened.sidebarConfiguration.pinnedCategories == ["Places"])
    #expect(reopened.documentSession.open.isEmpty)
    reopened.openRecord(reopened.favoriteRecords[0])
    #expect(reopened.selectedRecord == renamed)
    reopened.setFavorite(renamed, enabled: false)
    #expect(reopened.favoriteRecords.isEmpty && reopened.selectedRecord == renamed)
    #expect(try store.record(worldID: studio.worldID, id: record.id) == renamed)
  }

  @Test func archiveAndRestoreKeepFavoritesWithoutLeakingBetweenWorlds() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let studio = try Studio(store: store)
    let home = studio.worldID
    let other = try store.createWorld(name: "Another world")
    let record = try store.createRecord(worldID: home, title: "Crossing the sea", kind: "lore")
    let foreign = try store.createRecord(
      worldID: other.id, title: "Private elsewhere", kind: "entity")
    try studio.reload()
    studio.setFavorite(record, enabled: true)
    studio.setFavorite(foreign, enabled: true)
    #expect(studio.favoriteRecords == [record])
    studio.archive(record)
    #expect(studio.favoriteRecords.isEmpty && studio.isFavorite(record.id))
    studio.setFavorite(record, enabled: true)
    #expect(studio.error != nil && studio.favoriteRecords.isEmpty)
    studio.error = nil
    studio.restore(recordID: record.id)
    #expect(studio.favoriteRecords.map(\.id) == [record.id])
    studio.switchWorld(other.id)
    #expect(studio.favoriteRecords.isEmpty)
    studio.setFavorite(foreign, enabled: true)
    studio.updateSidebarConfiguration { $0.favoriteRecordIDs.append(record.id) }
    #expect(studio.favoriteRecords == [foreign])
    studio.switchWorld(home)
    #expect(studio.favoriteRecords.map(\.id) == [record.id])
  }

  @Test func openingFavoritesUsesFreshLoreAndPreservesFailedWriting() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let studio = try Studio(store: store)
    studio.setMode(.manual)
    let first = try store.createRecord(worldID: studio.worldID, title: "First", kind: "lore")
    let second = try store.createRecord(worldID: studio.worldID, title: "Second", kind: "entity")
    try studio.reload()
    studio.setFavorite(second, enabled: true)
    studio.navigate(.atlas)
    studio.openRecord(first)
    studio.editorSave = { false }
    studio.openRecord(studio.favoriteRecords[0])
    #expect(studio.selectedRecord?.id == first.id)
    studio.editorSave = nil
    let current = try store.saveRecord(
      worldID: studio.worldID, id: second.id, version: second.version,
      title: "Second revised", body: "Current world text", rtf: nil)
    studio.openRecord(studio.favoriteRecords[0])
    #expect(studio.selectedRecord == current && studio.destination == .atlas)
    #expect(studio.mode == .manual)
  }

  @Test func orderingSkipsArchivedItemsAndStalePreferenceWritesCompose() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let studio = try Studio(store: store)
    let records = try (1...3).map {
      try store.createRecord(worldID: studio.worldID, title: "Record \($0)", kind: "lore")
    }
    try studio.reload()
    for record in records { studio.setFavorite(record, enabled: true) }
    let second = try Studio(store: store)
    studio.archive(records[1])
    studio.moveFavorite(records[2], by: -1)
    #expect(studio.favoriteRecords.map(\.id) == [records[2].id, records[0].id])
    second.setSidebarCategory("Characters", visible: false)
    #expect(try studio.readSidebarConfiguration().favoriteRecordIDs.first == records[2].id)
    studio.refreshSidebarConfiguration()
    #expect(studio.sidebarConfiguration.isHidden("Characters"))
    studio.restore(recordID: records[1].id)
    #expect(studio.favoriteRecords.map(\.id) == [records[2].id, records[1].id, records[0].id])
    let snapshot = studio.sidebarConfiguration
    studio.moveFavorite(records[2], by: -1)
    #expect(studio.sidebarConfiguration == snapshot)
    let raw = "{\"version\":1,\"favoriteRecordIDs\":[\"\",\"a\",\"a\"]}"
    let parsed = try JSONDecoder().decode(SidebarConfiguration.self, from: Data(raw.utf8))
    #expect(parsed.validated.favoriteRecordIDs == ["a"])
    try store.setPreference("navigation:\(studio.worldID)", value: "unreadable")
    studio.setFavorite(records[0], enabled: false)
    #expect(try store.preference("navigation:\(studio.worldID)") == "unreadable")
  }
}
