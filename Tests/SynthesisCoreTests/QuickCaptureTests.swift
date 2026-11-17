import Foundation
import Testing

@testable import SynthesisCore

struct QuickCaptureTests {
  @Test func capturePersistsOnceAndKeepsWorldsAndCanonSeparate() throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    let path = folder.appendingPathComponent("capture.sqlite").path
    let store = try WorkspaceStore(path: path)
    let world = try store.createWorld(name: "Aster")
    let other = try store.createWorld(name: "Elsewhere")
    let draft = QuickCaptureDraft(text: "\nThe city wakes at low tide\nIts bells never ring twice.")
    let privateDraft = QuickCaptureDraft(text: "This belongs to Elsewhere")
    try store.saveQuickCaptureDraft(worldID: world.id, draft: draft)
    try store.saveQuickCaptureDraft(worldID: other.id, draft: privateDraft)
    let reopened = try WorkspaceStore(path: path)
    #expect(try reopened.quickCaptureDraft(worldID: world.id) == draft)
    let record = try reopened.commitQuickCapture(worldID: world.id, draft: draft)
    let retry = try reopened.commitQuickCapture(worldID: world.id, draft: draft)
    #expect(retry.id == record.id)
    #expect(record.worldID == world.id && record.kind == "capture")
    #expect(record.category == "Ideas" && record.title == "The city wakes at low tide")
    #expect(record.state == "idea" && record.canonical == nil && record.origin == "user-authored")
    #expect(try reopened.records(worldID: world.id).count == 1)
    #expect(try reopened.records(worldID: other.id).isEmpty)
    #expect(try reopened.quickCaptureDraft(worldID: world.id).text.isEmpty)
    #expect(try reopened.quickCaptureDraft(worldID: other.id) == privateDraft)
    let export = String(decoding: try reopened.exportWorldArchive(worldID: other.id), as: UTF8.self)
    #expect(!export.contains(privateDraft.text))
  }

  @Test func failedScratchRemovalRollsBackTheIdeaAndReceipt() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Failure safety")
    let draft = QuickCaptureDraft(text: "This note must survive a failed commit")
    try store.saveQuickCaptureDraft(worldID: world.id, draft: draft)
    try store.db.execute(
      """
      CREATE TRIGGER reject_capture_clear BEFORE UPDATE ON preferences
      WHEN NEW.key LIKE 'quick-capture:%' AND NEW.value=''
      BEGIN SELECT RAISE(ABORT, 'simulated unavailable storage'); END
      """)
    #expect(throws: (any Error).self) {
      try store.commitQuickCapture(worldID: world.id, draft: draft)
    }
    #expect(try store.records(worldID: world.id).isEmpty)
    #expect(try store.quickCaptureDraft(worldID: world.id) == draft)
    #expect(
      try store.db.rows("SELECT key FROM preferences WHERE key LIKE 'quick-capture-receipt:%'")
        .isEmpty)
    try store.db.execute("DROP TRIGGER reject_capture_clear")
    _ = try store.commitQuickCapture(worldID: world.id, draft: draft)
    #expect(try store.records(worldID: world.id).count == 1)
  }

  @Test func lateRetryDoesNotEraseANewerDraft() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Retry")
    let first = QuickCaptureDraft(text: "First idea")
    try store.saveQuickCaptureDraft(worldID: world.id, draft: first)
    let record = try store.commitQuickCapture(worldID: world.id, draft: first)
    let next = QuickCaptureDraft(text: "Second idea still in progress")
    try store.saveQuickCaptureDraft(worldID: world.id, draft: next)
    #expect(try store.commitQuickCapture(worldID: world.id, draft: first).id == record.id)
    #expect(try store.quickCaptureDraft(worldID: world.id) == next)
    #expect(try store.records(worldID: world.id).count == 1)
  }

  @Test func invalidCaptureNeverCreatesContentOrOverwritesScratch() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Validation")
    let draft = QuickCaptureDraft(text: "A safe scratch note")
    try store.saveQuickCaptureDraft(worldID: world.id, draft: draft)
    for text in [" \n\t", String(repeating: "x", count: 200_001)] {
      #expect(throws: (any Error).self) {
        try store.commitQuickCapture(worldID: world.id, draft: QuickCaptureDraft(text: text))
      }
    }
    #expect(throws: (any Error).self) {
      try store.saveQuickCaptureDraft(
        worldID: world.id, draft: QuickCaptureDraft(text: String(repeating: "x", count: 200_001)))
    }
    #expect(throws: (any Error).self) {
      try store.saveQuickCaptureDraft(worldID: "missing", draft: draft)
    }
    #expect(throws: (any Error).self) {
      try store.commitQuickCapture(worldID: "missing", draft: draft)
    }
    #expect(try store.quickCaptureDraft(worldID: world.id) == draft)
    #expect(try store.records(worldID: world.id).isEmpty)
  }

  @Test func differentEditsFromTheSameRestoredIdentityAreNotDiscarded() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Concurrent scratch")
    let original = QuickCaptureDraft(text: "The first fragment")
    var revised = original
    revised.text = "A second fragment written after restoring the same draft"
    try store.saveQuickCaptureDraft(worldID: world.id, draft: revised)
    let first = try store.commitQuickCapture(worldID: world.id, draft: original)
    #expect(try store.quickCaptureDraft(worldID: world.id) == revised)
    let second = try store.commitQuickCapture(worldID: world.id, draft: revised)
    #expect(first.id != second.id && second.body == revised.text)
    #expect(try store.commitQuickCapture(worldID: world.id, draft: revised).id == second.id)
    #expect(try store.records(worldID: world.id).count == 2)
    #expect(try store.quickCaptureDraft(worldID: world.id).text.isEmpty)
  }
}
