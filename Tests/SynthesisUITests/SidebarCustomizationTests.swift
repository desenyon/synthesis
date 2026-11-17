import Foundation
import SynthesisCore
import Testing

@testable import SynthesisUI

@MainActor struct SidebarCustomizationTests {
  @Test func navigationPersistsOnDiskPerWorldAndNeverChangesContentOrMode() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let path = directory.appendingPathComponent("world.sqlite").path
    let store = try WorkspaceStore(path: path)
    let studio = try Studio(store: store)
    studio.setMode(.manual)
    let world = studio.worldID
    let other = try store.createWorld(name: "Other")
    let record = try store.createRecord(
      worldID: world, title: "The coastal order", kind: "entity", category: "Clans")
    try studio.reload()
    studio.pinSidebarCategory("Clans", pinned: true)
    studio.pinSidebarCategory("Characters", pinned: true)
    studio.movePinnedCategory("Characters", by: -1)
    studio.setSidebarCategory("Clans", visible: false)
    studio.moveSidebarSection(.world, by: -1)
    let expected = studio.sidebarConfiguration
    let reopened = try Studio(store: WorkspaceStore(path: path))
    #expect(reopened.sidebarConfiguration == expected && reopened.mode == .manual)
    #expect(reopened.sidebarConfiguration.pinnedCategories == ["Characters", "Clans"])
    #expect(!reopened.visibleSidebarCategories.contains("Clans"))
    #expect(try store.record(worldID: world, id: record.id) == record)
    reopened.switchWorld(other.id)
    #expect(reopened.sidebarConfiguration == SidebarConfiguration())
    reopened.switchWorld(world)
    #expect(reopened.sidebarConfiguration == expected)
    reopened.restoreSidebarDefaults()
    #expect(reopened.sidebarConfiguration == SidebarConfiguration())
    #expect(reopened.visibleSidebarCategories.contains("Clans"))
    #expect(try store.record(worldID: world, id: record.id) == record)
  }

  @Test func hidingAndPinningLeaveCollectionsSearchableAndRespectUnsavedWriting() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let studio = try Studio(store: store)
    let record = try store.createRecord(
      worldID: studio.worldID, title: "Mira", kind: "entity", category: "Characters")
    try studio.reload()
    studio.pinSidebarCategory("Characters", pinned: true)
    studio.setSidebarCategory("Characters", visible: false)
    #expect(
      try store.search(worldID: studio.worldID, query: "type:character").map(\.id) == [record.id])
    studio.openRecord(record)
    studio.libraryQuery = "unrelated"
    studio.editorSave = { false }
    studio.openLens("Characters")
    #expect(studio.selectedRecord?.id == record.id && studio.libraryQuery == "unrelated")
    studio.editorSave = nil
    studio.openLens("Characters")
    #expect(
      studio.selectedRecord == nil && studio.destination == .library && studio.libraryQuery.isEmpty)
    #expect(studio.libraryCategory == "Characters")
    studio.pinSidebarCategory("Characters", pinned: false)
    #expect(studio.sidebarConfiguration.pinnedCategories.isEmpty)
  }

  @Test func corruptSettingsArePreservedUntilExplicitResetAndStaleChangesCompose() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let studio = try Studio(store: store)
    let second = try Studio(store: store)
    studio.pinSidebarCategory("Characters", pinned: true)
    second.setSidebarCategory("Places", visible: false)
    #expect(try studio.readSidebarConfiguration().isPinned("Characters"))
    #expect(try studio.readSidebarConfiguration().isHidden("Places"))
    let key = "navigation:\(studio.worldID)"
    try store.setPreference(key, value: "unreadable")
    studio.refreshSidebarConfiguration()
    #expect(studio.sidebarConfigurationError != nil)
    studio.pinSidebarCategory("Systems", pinned: true)
    #expect(try store.preference(key) == "unreadable")
    studio.restoreSidebarDefaults()
    #expect(
      studio.sidebarConfigurationError == nil
        && studio.sidebarConfiguration == SidebarConfiguration())
    studio.moveSidebarSection(.favorites, by: -1)
    #expect(studio.sidebarConfiguration.sections == SidebarSection.allCases)
  }

  @Test func categoryAliasesAndInvalidOrderingDoNotDuplicateRows() throws {
    var configuration = SidebarConfiguration()
    configuration.sectionOrder = ["world", "world", "unknown"]
    configuration.pinnedCategories = ["Systems", "Factions", "", "Characters"]
    configuration.hiddenCategories = ["Places", "locations"]
    let normalized = configuration.validated
    #expect(normalized.sections.first == .world)
    #expect(Set(normalized.sections).count == SidebarSection.allCases.count)
    #expect(normalized.pinnedCategories == ["Systems", "Characters"])
    #expect(normalized.hiddenCategories == ["Places"] && normalized.isHidden("location"))
    let studio = try Studio(store: WorkspaceStore(path: ":memory:"))
    _ = try studio.store.createRecord(
      worldID: studio.worldID, title: "Old order", kind: "entity", category: "Factions")
    try studio.reload()
    #expect(
      studio.sidebarCategories.filter { Vocabulary.categoryKey($0) == "systems" } == ["Systems"])
    let longCategory = String(repeating: "Long category ", count: 10)
    _ = try studio.store.createRecord(
      worldID: studio.worldID, title: "A custom order", kind: "entity", category: longCategory)
    try studio.reload()
    studio.pinSidebarCategory(longCategory, pinned: true)
    #expect(studio.sidebarConfiguration.isPinned(longCategory))
    let partial = try JSONDecoder().decode(
      SidebarConfiguration.self,
      from: Data("{\"version\":1,\"hiddenCategories\":[\"Places\"]}".utf8))
    #expect(partial.isHidden("Places") && partial.sections == SidebarSection.allCases)
  }
}
