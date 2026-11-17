import AppKit
import SwiftUI
import SynthesisCore
import Testing

@testable import SynthesisUI

@MainActor struct DocumentTabTests {
  @Test func tabsPinReopenPersistAndStayInTheirWorld() throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    let path = folder.appendingPathComponent("world.sqlite").path
    let store = try WorkspaceStore(path: path)
    let studio = try Studio(store: store)
    let a = try store.createRecord(worldID: studio.worldID, title: "Mira", kind: "entity")
    let b = try store.createRecord(worldID: studio.worldID, title: "Tidekeepers", kind: "entity")
    try studio.reload()
    studio.setMode(.manual)
    studio.openRecord(a)
    studio.openRecord(b)
    studio.toggleDocumentPin(a.id)
    studio.cycleDocument()
    #expect(studio.selectedRecord?.id == a.id)
    studio.cycleDocument(backward: true)
    #expect(studio.selectedRecord?.id == b.id)
    studio.closeActiveDocument()
    #expect(studio.selectedRecord?.id == a.id)
    #expect(studio.canReopenDocument && studio.documentSession.pinned == [a.id])
    studio.reopenDocument()
    #expect(studio.selectedRecord?.id == b.id && studio.mode == .manual)
    let restart = try Studio(store: WorkspaceStore(path: path))
    #expect(restart.documentSession == studio.documentSession)
    #expect(restart.openDocuments.map(\.id) == [a.id, b.id])
    let foreignWorld = try store.createWorld(name: "Elsewhere")
    let foreign = try store.createRecord(worldID: foreignWorld.id, title: "Other Mira")
    studio.openRecord(foreign)
    #expect(studio.openDocuments.count == 2)
    studio.switchWorld(foreignWorld.id)
    #expect(studio.openDocuments.isEmpty && studio.recentDocuments.isEmpty)
    studio.openRecord(foreign)
    studio.switchWorld(a.worldID)
    #expect(studio.openDocuments.map(\.id) == [a.id, b.id])
    #expect(try store.record(worldID: a.worldID, id: a.id) == a)
  }

  @Test func failedSaveBlocksTabSwitchCloseAndBulkCloseAndArchivePrunesAddresses() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let studio = try Studio(store: store)
    let a = try store.createRecord(worldID: studio.worldID, title: "A")
    let b = try store.createRecord(worldID: studio.worldID, title: "B")
    try studio.reload()
    studio.openRecord(a)
    studio.openRecord(b)
    let before = studio.documentSession
    studio.editorSave = { false }
    studio.openRecord(a)
    studio.closeActiveDocument()
    studio.closeOtherDocuments(keeping: a.id)
    #expect(studio.documentSession == before && studio.selectedRecord?.id == b.id)
    studio.editorSave = nil
    studio.toggleDocumentPin(a.id)
    studio.closeOtherDocuments(keeping: b.id)
    #expect(studio.openDocuments.count == 2, "Pinned documents stay open")
    studio.closeDocument(b.id)
    studio.closeDocument(a.id)
    studio.reopenDocument()
    #expect(studio.selectedRecord?.id == a.id, "Reopen follows closing order, not the last visit")
    studio.reopenDocument()
    studio.closeRecord()  // Returning to the workspace leaves tabs open.
    #expect(studio.openDocuments.count == 2)
    try store.archiveRecord(worldID: a.worldID, id: a.id)
    try studio.reload()
    #expect(studio.openDocuments.map(\.id) == [b.id])
    #expect(!studio.recentDocuments.contains { $0.id == a.id })
  }

  @Test func corruptOrForeignTabDataCannotBlockAccessOrLeakRecords() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let studio = try Studio(store: store)
    let local = try store.createRecord(worldID: studio.worldID, title: "Local")
    let other = try store.createWorld(name: "Other")
    let foreign = try store.createRecord(worldID: other.id, title: "Foreign")
    let key = "open-documents:\(studio.worldID)"
    let invalid = "{broken"
    try store.setPreference(key, value: invalid)
    let reopened = try Studio(store: store)
    #expect(reopened.error != nil && reopened.records.contains { $0.id == local.id })
    #expect(try store.preference(key) == invalid)
    #expect(try store.preference("open-documents-backup:\(studio.worldID)") == invalid)
    let state = OpenDocuments(
      open: [foreign.id, local.id, local.id], pinned: [foreign.id, local.id], recent: [foreign.id])
    try store.setPreference(
      key, value: String(decoding: JSONEncoder().encode(state), as: UTF8.self))
    let restored = try Studio(store: store)
    #expect(restored.documentSession.open == [local.id])
    #expect(restored.documentSession.pinned == [local.id] && restored.recentDocuments.isEmpty)
  }

  @Test func nativeEditorKeepsCaretScrollFormattingAndIndependentUndoAcrossTabs() throws {
    let first = EditorHandle()
    let second = EditorHandle()
    var text = "Mira crosses the sea.\n" + String(repeating: "A remembered shore.\n", count: 60)
    var rich: String?
    let original = text
    func input(_ handle: EditorHandle, _ value: String, _ rtf: String? = nil) -> RichDocumentEditor
    {
      RichDocumentEditor(
        id: "record", body: value, rtf: rtf, t: Theme(dark: true), reloadToken: 0,
        handle: handle
      ) {
        text = $0
        rich = $1
      }
    }
    let a = input(first, text)
    let ac = a.makeCoordinator()
    let scroll = a.makeEditor(coordinator: ac)
    scroll.frame = NSRect(x: 0, y: 0, width: 500, height: 250)
    let view = try #require(first.view)
    view.frame = NSRect(x: 0, y: 0, width: 500, height: 1800)
    first.undoManager.beginUndoGrouping()
    view.insertText("New opening. ", replacementRange: NSRange(location: 0, length: 0))
    first.undoManager.endUndoGrouping()
    view.breakUndoCoalescing()
    view.setSelectedRange(NSRange(location: 20, length: 5))
    scroll.contentView.scroll(to: NSPoint(x: 0, y: 130))
    let offset = scroll.contentView.bounds.origin
    let caret = view.selectedRange()
    #expect(first.undoManager.canUndo && rich != nil && text != original)
    let b = input(second, "Other document")
    let bc = b.makeCoordinator()
    _ = b.makeEditor(coordinator: bc)
    let back = input(first, text, rich)
    let backCoordinator = back.makeCoordinator()
    let returned = back.makeEditor(coordinator: backCoordinator)
    #expect(returned === scroll && first.view === view)
    #expect(view.selectedRange() == caret && returned.contentView.bounds.origin == offset)
    #expect(view.attributedString().attribute(.font, at: 0, effectiveRange: nil) != nil)
    first.undoManager.undo()
    #expect(view.string == original && second.view?.string == "Other document")
    #expect(!second.undoManager.canUndo)
    let changed = input(first, "A freshly reviewed revision")
    let cc = changed.makeCoordinator()
    _ = changed.makeEditor(coordinator: cc)
    #expect(view.string == "A freshly reviewed revision" && !first.undoManager.canUndo)
  }
}
