import AppKit
import Foundation
import SwiftUI
import SynthesisCore
import Testing

@testable import SynthesisUI

@MainActor struct FocusWorkspaceTests {
  @Test func focusRestoresPanelsWithoutChangingTheirSavedConfiguration() async throws {
    let transport = RecordingResponse()
    let studio = try Studio(store: WorkspaceStore(path: ":memory:"), transport: transport)
    studio.sheet = nil
    studio.navigate(.atlas)
    studio.workspaceInspector = true
    studio.companionExpanded = true
    studio.setPanelWidth(.sidebar, to: 264)
    studio.setPanelWidth(.inspector, to: 320)
    studio.draft = "Keep my unsent idea"
    studio.pendingComposer = (studio.worldID, "Keep my newest idea", studio.draft)
    let location = studio.navigationLocation
    let preferences = studio.preferences
    let history = studio.navigationBack
    for collapsed in [false, true] {
      studio.collapsed = collapsed
      let width = studio.visibleSidebarWidth(windowWidth: 1440)
      studio.toggleFocusMode()
      #expect(studio.focusMode && studio.visibleSidebarWidth(windowWidth: 1440) == 0)
      #expect(studio.dockedInspectorWidth(windowWidth: 1920) == 0)
      #expect(studio.workspaceInspector && studio.companionExpanded && studio.inspector)
      #expect(studio.navigationLocation == location && studio.preferences == preferences)
      #expect(studio.navigationBack == history && studio.collapsed == collapsed)
      studio.toggleFocusMode()
      #expect(!studio.focusMode && studio.visibleSidebarWidth(windowWidth: 1440) == width)
    }
    #expect(studio.draft == "Keep my newest idea")
    #expect(try studio.store.preference("composer:\(studio.worldID)") == studio.draft)
    #expect(try Studio(store: studio.store, transport: transport).focusMode == false)
    #expect(await transport.requests.isEmpty)
  }

  @Test func saveFailuresAndOpenFormsPreventFocusAndManualRemainsIndependent() throws {
    let studio = try Studio(store: WorkspaceStore(path: ":memory:"))
    studio.sheet = nil
    studio.setMode(.manual)
    studio.editorSave = { false }
    studio.toggleFocusMode()
    #expect(!studio.focusMode)
    studio.editorSave = nil
    studio.sheet = .document
    studio.toggleFocusMode()
    #expect(!studio.focusMode && studio.sheet == .document)
    studio.sheet = nil
    studio.navigate(.canvas)
    studio.companionExpanded = true
    studio.toggleFocusMode()
    #expect(studio.focusMode && studio.mode == .manual && studio.canvasVisible(windowWidth: 720))
    studio.setMode(.assisted)
    #expect(studio.focusMode && studio.canvasVisible(windowWidth: 720))
    studio.toggleFocusMode()
    #expect(!studio.canvasVisible(windowWidth: 720))
  }

  @Test func explicitNavigationAndInspectionCanLeaveFocusWithoutLosingLayout() throws {
    let studio = try Studio(store: WorkspaceStore(path: ":memory:"))
    studio.sheet = nil
    studio.navigate(.timeline)
    studio.toggleFocusMode()
    studio.toggleSidebar()
    #expect(!studio.focusMode && !studio.collapsed)
    studio.toggleFocusMode()
    studio.inspect(.world)
    #expect(!studio.focusMode && studio.workspaceInspector)
    studio.toggleFocusMode()
    studio.toggleActiveInspector()
    #expect(!studio.focusMode && studio.workspaceInspector)
    studio.toggleFocusMode()
    studio.navigate(.settings)
    #expect(!studio.focusMode && !studio.canFocusWorkspace)
    studio.toggleFocusMode()
    #expect(!studio.focusMode)
  }

  @Test func nativeWritingKeepsItsEditorCaretUndoAndSaveCallbackThroughFocus() async throws {
    _ = NSApplication.shared
    let studio = try Studio(store: WorkspaceStore(path: ":memory:"))
    studio.sheet = nil
    let record = try studio.store.createRecord(
      worldID: studio.worldID, title: "A crossing", body: "The sea remembers.")
    try studio.reload()
    studio.openRecord(record)
    let host = NSHostingView(rootView: EditorScreen(studio: studio, record: record))
    host.frame = CGRect(x: 0, y: 0, width: 900, height: 700)
    host.layoutSubtreeIfNeeded()
    try await Task.sleep(for: .milliseconds(100))
    let handle = studio.editorHandle(for: record)
    let view = try #require(handle.view)
    handle.undoManager.beginUndoGrouping()
    view.insertText("Tonight, ", replacementRange: NSRange(location: 0, length: 0))
    handle.undoManager.endUndoGrouping()
    view.breakUndoCoalescing()
    view.setSelectedRange(NSRange(location: 9, length: 3))
    try await Task.sleep(for: .milliseconds(100))
    studio.toggleFocusMode()
    host.layoutSubtreeIfNeeded()
    try await Task.sleep(for: .milliseconds(100))
    #expect(studio.focusMode && handle.view === view)
    #expect(view.selectedRange() == NSRange(location: 9, length: 3))
    #expect(studio.editorSave != nil && studio.flushEditor())
    #expect(
      try studio.store.record(worldID: studio.worldID, id: record.id).body
        == "Tonight, The sea remembers.")
    studio.toggleFocusMode()
    host.layoutSubtreeIfNeeded()
    try await Task.sleep(for: .milliseconds(100))
    #expect(handle.view === view && handle.undoManager.canUndo)
    handle.undoManager.undo()
    #expect(view.string == record.body)
    #expect(try studio.store.record(worldID: studio.worldID, id: record.id).canonical == nil)
  }
}
