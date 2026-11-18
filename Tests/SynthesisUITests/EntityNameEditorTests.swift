import AppKit
import SwiftUI
import SynthesisCore
import Testing

@testable import SynthesisUI

@MainActor struct EntityNameEditorTests {
  @Test func adoptingAndUndoingANamePreservesWritingUndoAndCanon() async throws {
    _ = NSApplication.shared
    let store = try WorkspaceStore(path: ":memory:")
    let studio = try Studio(store: store)
    studio.sheet = nil
    let worldID = studio.worldID
    let record = try store.createRecord(
      worldID: worldID, title: "Tidekeepers", body: "The order guards the coast.", kind: "entity")
    let accepted = try store.promote(
      worldID: worldID, id: record.id, version: record.version, confirmation: record.id)
    let name = try store.createEntityNamePeriod(
      worldID: worldID, recordID: record.id, draft: .init(name: "Keepers of the First Tide"))
    try studio.reload()
    studio.openRecord(accepted)

    let host = NSHostingView(rootView: EditorScreen(studio: studio, record: accepted))
    host.frame = CGRect(x: 0, y: 0, width: 900, height: 700)
    host.layoutSubtreeIfNeeded()
    let handle = studio.editorHandle(for: accepted)
    for _ in 0..<50 where handle.view == nil || studio.editorSave == nil {
      try await Task.sleep(for: .milliseconds(20))
      host.layoutSubtreeIfNeeded()
    }
    let view = try #require(handle.view)
    try #require(studio.editorSave != nil)
    handle.undoManager.beginUndoGrouping()
    view.insertText("The tide turned. ", replacementRange: NSRange(location: 0, length: 0))
    handle.undoManager.endUndoGrouping()
    view.breakUndoCoalescing()
    let selection = NSRange(location: 5, length: 4)
    view.setSelectedRange(selection)
    #expect(studio.flushEditor())
    let before = try store.record(worldID: worldID, id: record.id)
    #expect(before.body == "The tide turned. The order guards the coast.")
    #expect(handle.undoManager.canUndo)

    let renamed = try store.updateEntityWorkingTitle(
      worldID: worldID, expected: before, title: name.name)
    try studio.reload()
    host.layoutSubtreeIfNeeded()
    try await Task.sleep(for: .milliseconds(100))
    #expect(studio.flushEditor())
    #expect(try store.record(worldID: worldID, id: record.id) == renamed)
    #expect(handle.view === view && handle.undoManager.canUndo && view.selectedRange() == selection)
    #expect(renamed.body == before.body && renamed.rtf == before.rtf)
    #expect(renamed.canonical == accepted.canonical)

    let restored = try store.updateEntityWorkingTitle(
      worldID: worldID, expected: renamed, title: before.title)
    try studio.reload()
    host.layoutSubtreeIfNeeded()
    try await Task.sleep(for: .milliseconds(100))
    #expect(studio.flushEditor())
    #expect(try store.record(worldID: worldID, id: record.id) == restored)
    #expect(restored.title == record.title && restored.canonical == accepted.canonical)
    #expect(handle.view === view && handle.undoManager.canUndo)
  }
}
