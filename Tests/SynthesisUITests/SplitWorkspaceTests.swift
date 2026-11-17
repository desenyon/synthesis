import AppKit
import SynthesisCore
import Testing

@testable import SynthesisUI

@MainActor struct SplitWorkspaceTests {
  private func fixture(_ path: String = ":memory:") throws -> (Studio, LoreRecord, LoreRecord) {
    let store = try WorkspaceStore(path: path)
    let studio = try Studio(store: store)
    let a = try store.createRecord(
      worldID: studio.worldID, title: "Mira", body: "A surveyor.", kind: "entity",
      category: "Characters")
    let b = try store.createRecord(
      worldID: studio.worldID, title: "Glass Sea", body: "A frozen coast.", kind: "entity",
      category: "Places")
    try studio.reload()
    return (studio, a, b)
  }

  @Test func splitStaysConnectedAcrossToolsAndResolvesUpdatedLore() throws {
    let (studio, a, b) = try fixture()
    studio.setMode(.manual)
    studio.openRecord(a)
    studio.openBeside(b)
    #expect(studio.selectedRecord?.id == a.id && studio.splitRecord?.id == b.id)
    #expect(Set(studio.contextualRecordIDs) == Set([a.id, b.id]))
    for tool in [Destination.atlas, .timeline, .knowledge, .canvas, .library] {
      studio.navigate(tool)
      #expect(studio.destination == tool && studio.splitRecord?.id == b.id)
      #expect(studio.selectedRecord == nil && studio.mode == .manual && !studio.busy)
    }
    let fresh = try studio.store.saveRecord(
      worldID: b.worldID, id: b.id, version: b.version,
      title: "The Glass Sea", body: "The survey is complete.", rtf: nil)
    try studio.reload()
    #expect(studio.splitRecord == fresh)
    studio.openRecord(a)
    let context = try studio.previewContext(prompt: "Compare the surveyor and the coast")
    #expect(Set(context.sources.map(\.id)).isSuperset(of: [a.id, b.id]))
    #expect(studio.agentWorkspaceName.contains("The Glass Sea"))
    #expect(try studio.store.record(worldID: a.worldID, id: a.id) == a)
    #expect(studio.splitRecord?.canonical == nil)
  }

  @Test func bothSaveGuardsProtectCloseSwapNavigationArchiveAndWorldChanges() throws {
    let (studio, a, b) = try fixture()
    let other = try studio.store.createWorld(name: "Other")
    studio.openRecord(a)
    studio.editorSave = { false }
    studio.openBeside(b)
    #expect(studio.splitRecord == nil)
    studio.editorSave = nil
    studio.openBeside(b)
    let before = studio.navigationLocation
    studio.splitEditorSave = { false }
    studio.closeSplitWorkspace()
    studio.swapSplitWorkspace()
    studio.navigate(.atlas)
    studio.switchWorld(other.id)
    studio.archive(b)
    studio.closeDocument(b.id)
    #expect(studio.navigationLocation == before)
    #expect(try !studio.store.isArchived(worldID: b.worldID, recordID: b.id))
    studio.splitEditorSave = { true }
    studio.openBeside(b)
    #expect(studio.splitEditorSave != nil, "Reopening the same pane must retain its save callback")
    studio.openRecord(b)
    #expect(studio.splitRecord == nil && studio.selectedRecord?.id == b.id)
    #expect(studio.openDocuments.count == 2)
  }

  @Test func diskRestoreAndWorldSwitchNeverDisplayForeignOrArchivedSources() throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    let path = folder.appendingPathComponent("world.sqlite").path
    let (studio, a, b) = try fixture(path)
    studio.openBeside(a)
    studio.setPanelWidth(.split, to: 540)
    let restarted = try Studio(store: WorkspaceStore(path: path))
    #expect(restarted.splitRecord?.id == a.id && restarted.splitWidth == 540)
    let foreign = try studio.store.createWorld(name: "Foreign")
    try studio.store.setPreference("split-record:\(foreign.id)", value: b.id)
    studio.switchWorld(foreign.id)
    #expect(studio.splitRecord == nil && studio.contextualRecordIDs.isEmpty)
    studio.openBeside(a)
    #expect(studio.splitRecord == nil)
    studio.switchWorld(a.worldID)
    #expect(studio.splitRecord?.id == a.id)
    studio.archive(a)
    #expect(studio.splitRecord == nil)
    let afterArchive = try Studio(store: WorkspaceStore(path: path))
    #expect(afterArchive.splitRecord == nil)
  }

  @Test func savedLayoutsAndHistoryRestoreTwoFreshSourcesWithoutApprovingThem() throws {
    let (studio, a, b) = try fixture()
    studio.openRecord(a)
    studio.openBeside(b)
    studio.setPanelWidth(.split, to: 500)
    let layout = try studio.saveLayout(name: "Compare")
    studio.closeSplitWorkspace()
    #expect(
      studio.recordTrailIndices.isEmpty, "Changing the second pane is not a new source breadcrumb")
    studio.goBack()
    #expect(studio.selectedRecord?.id == a.id && studio.splitRecord?.id == b.id)
    studio.swapSplitWorkspace()
    #expect(studio.selectedRecord?.id == b.id && studio.splitRecord?.id == a.id)
    studio.setMode(.manual)
    studio.navigate(.atlas)
    #expect(studio.applyLayout(layout.id))
    #expect(studio.selectedRecord?.id == a.id && studio.splitRecord?.id == b.id)
    #expect(studio.splitWidth == 500 && studio.mode == .manual)
    #expect(studio.selectedRecord?.canonical == nil && studio.splitRecord?.canonical == nil)
    studio.closeOtherDocuments(keeping: a.id)
    #expect(Set(studio.openDocuments.map(\.id)) == Set([a.id, b.id]))
    studio.closeDocument(b.id)
    #expect(studio.splitRecord == nil && studio.selectedRecord?.id == a.id)
  }

  @Test func twoNativeEditorsKeepIndependentContentCaretAndUndoWhenSwapped() throws {
    let (studio, a, b) = try fixture()
    studio.openRecord(a)
    studio.openBeside(b)
    let left = studio.editorHandle(for: a)
    let right = studio.editorHandle(for: b)
    var leftText = a.body
    var rightText = b.body
    let first = RichDocumentEditor(
      id: a.id, body: a.body, rtf: nil, t: studio.t,
      reloadToken: 0, handle: left
    ) {
      leftText = $0
      _ = $1
    }
    let second = RichDocumentEditor(
      id: b.id, body: b.body, rtf: nil, t: studio.t,
      reloadToken: 0, handle: right
    ) {
      rightText = $0
      _ = $1
    }
    let firstDelegate = first.makeCoordinator()
    let secondDelegate = second.makeCoordinator()
    let firstScroll = first.makeEditor(coordinator: firstDelegate)
    let secondScroll = second.makeEditor(coordinator: secondDelegate)
    #expect(firstScroll !== secondScroll && left.view !== right.view)
    let view = try #require(left.view)
    left.undoManager.beginUndoGrouping()
    view.insertText("Young ", replacementRange: NSRange(location: 0, length: 0))
    left.undoManager.endUndoGrouping()
    view.breakUndoCoalescing()
    view.setSelectedRange(NSRange(location: 4, length: 2))
    studio.swapSplitWorkspace()
    #expect(studio.editorHandle(for: a) === left && studio.editorHandle(for: b) === right)
    #expect(left.view?.selectedRange() == NSRange(location: 4, length: 2))
    #expect(leftText != a.body && rightText == b.body && !right.undoManager.canUndo)
    left.undoManager.undo()
    #expect(view.string == a.body && right.view?.string == b.body)
  }

  @Test func splitGeometryKeepsBothWorkspacesUsableAndTheCanvasHiddenDuringTakeover() throws {
    let (studio, a, _) = try fixture()
    studio.openBeside(a)
    studio.setPanelWidth(.split, to: 900)
    #expect(studio.splitWidth == 720)
    #expect(studio.primaryContentWidth(windowWidth: 1440) >= 620)
    #expect(!Studio.splitsHorizontally(available: 900))
    #expect(studio.primaryContentWidth(windowWidth: 1024) == 1024 - studio.sidebarWidth)
    studio.navigate(.canvas)
    studio.setMode(.assisted)
    studio.companionExpanded = true
    #expect(!studio.canvasVisible(windowWidth: 1440))
    studio.companionExpanded = false
    #expect(studio.canvasVisible(windowWidth: 1440))
    let result = CommandPalette.results(studio: studio, query: "Open document beside", indexed: [])
    let command = try #require(result.first { $0.title == "Open document beside workspace" })
    command.run()
    #expect(studio.sheet == .splitRecord)
  }

  @Test func documentCommandsTargetTheSelectedPaneAndKeepFailedWritingOpen() throws {
    let (studio, a, b) = try fixture()
    studio.openRecord(a)
    studio.openBeside(b)
    studio.activeEditorPlacement = .beside
    studio.toggleActiveInspector()
    #expect(studio.splitInspector && !studio.inspector)
    studio.splitEditorSave = { false }
    studio.closeActiveDocument()
    #expect(studio.splitRecord?.id == b.id && studio.selectedRecord?.id == a.id)
    studio.splitEditorSave = nil
    studio.closeActiveDocument()
    #expect(studio.splitRecord == nil && studio.selectedRecord?.id == a.id)
    studio.openBeside(b)
    studio.activeEditorPlacement = .main
    studio.closeActiveDocument()
    #expect(studio.selectedRecord == nil && studio.splitRecord?.id == b.id)
    studio.navigate(.timeline)
    #expect(studio.hasVisibleDocument && studio.selectedRecord == nil)
    studio.closeActiveDocument()
    #expect(!studio.hasVisibleDocument && studio.destination == .timeline)
  }
}
