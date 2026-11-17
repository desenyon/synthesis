import AppKit
import Foundation
import Testing

@testable import SynthesisCore
@testable import SynthesisUI

@MainActor struct QuickCaptureModelTests {
  @Test func switchingTargetKeepsSeparateScratchAndDoesNotNavigateStudio() throws {
    let studio = try Studio(store: WorkspaceStore(path: ":memory:"))
    studio.setMode(.manual)
    studio.destination = .timeline
    let world = studio.worldID
    let other = try studio.store.createWorld(name: "A different universe")
    let selected = studio.selectedRecord
    let controller = QuickCaptureController(studio: studio)
    let model = controller.model
    #expect(model.prepare(worldID: world))
    model.edit("An idea in the active world")
    #expect(model.selectWorld(other.id))
    model.edit("A private idea in the other world")
    let record = try #require(model.save())
    #expect(record.worldID == other.id && record.state == "idea" && record.canonical == nil)
    #expect(model.save() == nil)
    #expect(studio.worldID == world && studio.destination == .timeline)
    #expect(studio.mode == .manual && !studio.busy && studio.selectedRecord == selected)
    #expect(model.selectWorld(world))
    #expect(model.draft.text == "An idea in the active world")
    let activeRecord = try #require(model.save())
    #expect(studio.records.contains(where: { $0.id == activeRecord.id }))
    #expect(studio.destination == .timeline && studio.selectedRecord == selected)
  }

  @Test func failedSaveAndCloseRetainTextAndWorldForRetry() throws {
    let studio = try Studio(store: WorkspaceStore(path: ":memory:"))
    let model = QuickCaptureModel(store: studio.store)
    #expect(model.prepare(worldID: studio.worldID))
    model.edit("Keep my unsaved words")
    try studio.store.db.execute(
      """
      CREATE TRIGGER reject_capture_draft BEFORE INSERT ON preferences
      WHEN NEW.key LIKE 'quick-capture:%'
      BEGIN SELECT RAISE(ABORT, 'simulated unavailable storage'); END
      """)
    let count = studio.records.count
    #expect(!model.flush() && model.save() == nil)
    #expect(model.error != nil && model.draft.text == "Keep my unsaved words")
    #expect(!model.selectWorld("missing") && model.worldID == studio.worldID)
    #expect(try studio.store.records(worldID: studio.worldID).count == count)
    try studio.store.db.execute("DROP TRIGGER reject_capture_draft")
    #expect(model.flush())
    #expect(model.save() != nil)
    #expect(model.error == nil && model.draft.text.isEmpty)
  }

  @Test func restoredDraftAndMissingTargetAreSafe() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Remember")
    let first = QuickCaptureModel(store: store)
    #expect(first.prepare(worldID: world.id))
    first.edit("Return to these words later")
    #expect(first.flush())
    let reopened = QuickCaptureModel(store: store)
    #expect(reopened.prepare(worldID: world.id))
    #expect(reopened.draft == first.draft)
    #expect(!reopened.selectWorld("missing"))
    #expect(reopened.worldID == world.id && reopened.draft == first.draft)
    #expect(reopened.canSave)
  }

  @Test func nativePanelDoesNotActivateOrBecomeTheMainWorkspace() throws {
    _ = NSApplication.shared
    let studio = try Studio(store: WorkspaceStore(path: ":memory:"))
    let controller = QuickCaptureController(studio: studio)
    let wasActive = NSApp.isActive
    let originalKey = NSApp.keyWindow
    let panel = controller.preparePanel()
    #expect(panel.styleMask.contains(.nonactivatingPanel))
    #expect(panel.styleMask.contains(.titled) && panel.styleMask.contains(.closable))
    #expect(panel.canBecomeKey && !panel.canBecomeMain && !panel.isVisible)
    #expect(panel.standardWindowButton(.closeButton) != nil)
    #expect(panel.minSize.width >= 420 && panel.maxSize.width <= 920)
    #expect(NSApp.isActive == wasActive && NSApp.keyWindow === originalKey)
    #expect(QuickCaptureShortcut.keyCode == 49)
    panel.setContentSize(NSSize(width: 420, height: 330))
    let compact = panel.frame.size
    controller.model.error = "The selected universe is no longer available. Your writing is kept."
    panel.contentView?.layoutSubtreeIfNeeded()
    #expect(panel.frame.size == compact)
    // Do not register or dispatch a global shortcut in background tests.
  }
}
