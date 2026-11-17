import Foundation
import SynthesisCore
import Testing

@testable import SynthesisUI

@MainActor struct LayoutTests {
  @Test func arrangementsSurviveRestartAndRestoreCurrentRecordsWithoutRestoringAI() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let studio = try Studio(store: store)
    let record = try store.createRecord(
      worldID: studio.worldID, title: "Mira", body: "Earlier draft", kind: "entity")
    try studio.reload()
    studio.navigate(.library)
    studio.openRecord(record)
    studio.recordTabs[record.id] = .mechanics
    studio.collapsed = true
    studio.inspector = false
    studio.companionExpanded = true
    studio.companionWidth = 430
    studio.preferences.density = .immersive
    studio.preferences.readingWidth = 640
    let layout = try studio.saveLayout(name: "Writing")
    _ = try store.saveRecord(
      worldID: studio.worldID, id: record.id, version: record.version, title: "Mira",
      body: "Newer writing must survive", rtf: nil)
    let reopened = try Studio(store: store)
    reopened.setMode(.manual)
    reopened.draft = "Unsent thought"
    #expect(try reopened.savedLayouts().first == layout)
    #expect(reopened.applyLayout(layout.id))
    #expect(reopened.selectedRecord?.body == "Newer writing must survive")
    #expect(reopened.selectedRecord?.canonical == nil)
    #expect(reopened.collapsed && !reopened.inspector)
    #expect(reopened.recordTabs[record.id] == .mechanics)
    #expect(reopened.companionWidth == 430 && !reopened.companionExpanded)
    #expect(reopened.mode == .manual && reopened.draft == "Unsent thought" && !reopened.busy)
    #expect(reopened.preferences.density == .immersive && reopened.preferences.readingWidth == 640)
    #expect(try store.preference("sidebar") == "collapsed")
    #expect(try store.studioPreferences().density == .immersive)
  }

  @Test func invalidNamesArchivesUndoAndWorldIsolationAreExplicit() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let studio = try Studio(store: store)
    let layout = try studio.saveLayout(name: "Research")
    #expect(throws: SynthesisError.self) { try studio.saveLayout(name: " research ") }
    #expect(throws: SynthesisError.self) { try studio.saveLayout(name: " ") }
    #expect(throws: SynthesisError.self) {
      try studio.saveLayout(name: String(repeating: "x", count: 81))
    }
    try studio.renameLayout(layout.id, name: "Coastal research")
    try studio.archiveLayout(layout.id)
    #expect(try studio.savedLayouts().isEmpty)
    #expect(try studio.savedLayouts(includeArchived: true).count == 1)
    #expect(!studio.applyLayout(layout.id))
    studio.toast?.action?()
    #expect(try studio.savedLayouts().first?.name == "Coastal research")
    let ownRaw = try store.preference("workspace-layouts:\(studio.worldID)")
    let other = try store.createWorld(name: "Other")
    studio.switchWorld(other.id)
    #expect(try studio.savedLayouts().isEmpty)
    #expect(!studio.applyLayout(layout.id))
    try store.setPreference("workspace-layouts:\(other.id)", value: try #require(ownRaw))
    #expect(throws: SynthesisError.self) { try studio.savedLayouts() }
    #expect(throws: SynthesisError.self) {
      try studio.saveLayout(name: "Do not replace invalid data")
    }
    #expect(try store.preference("workspace-layouts:\(other.id)") == ownRaw)
  }

  @Test func failedSavesAndMissingTargetsLeaveTheCurrentWorkspaceIntact() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let studio = try Studio(store: store)
    let map = try store.createAtlasMap(worldID: studio.worldID, name: "Coast")
    try studio.reload()
    studio.openBoard(map.id, kind: "atlas")
    studio.workspaceInspector = true
    let layout = try studio.saveLayout(name: "Cartography")
    studio.navigate(.library)
    studio.workspaceInspector = false
    studio.editorSave = { false }
    let before = studio.navigationLocation
    #expect(!studio.applyLayout(layout.id))
    #expect(studio.navigationLocation == before && !studio.workspaceInspector)
    #expect(throws: SynthesisError.self) { try studio.saveLayout(name: "Unsafe") }
    #expect(throws: SynthesisError.self) { try studio.updateLayout(layout.id) }
    studio.editorSave = nil
    try store.archiveAtlasMap(worldID: studio.worldID, id: map.id)
    #expect(!studio.applyLayout(layout.id))
    #expect(studio.navigationLocation == before && !studio.workspaceInspector)
    try store.setPreference("workspace-layouts:\(studio.worldID)", value: "damaged")
    #expect(throws: SynthesisError.self) { try studio.savedLayouts() }
    #expect(try store.preference("workspace-layouts:\(studio.worldID)") == "damaged")
  }

  @Test func updatingALayoutHasGuardedUndoAndApplyingIsReversibleNavigation() throws {
    let studio = try Studio(store: WorkspaceStore(path: ":memory:"))
    studio.navigate(.library)
    let layout = try studio.saveLayout(name: "Research")
    studio.navigate(.knowledge)
    try studio.updateLayout(layout.id)
    #expect(try studio.savedLayouts().first?.arrangement.location.destination == .knowledge)
    studio.toast?.action?()
    #expect(try studio.savedLayouts().first?.arrangement.location.destination == .library)
    #expect(studio.applyLayout(layout.id))
    #expect(studio.destination == .library)
    studio.goBack()
    #expect(studio.destination == .knowledge)
    let items = CommandPalette.results(studio: studio, query: "workspace layouts", indexed: [])
    #expect(items.first?.title == "Workspace layouts")
    items.first?.run()
    #expect(studio.sheet == .layouts)
  }
}
