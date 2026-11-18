import AppKit
import SwiftUI
import Testing

@testable import SynthesisCore
@testable import SynthesisUI

@MainActor struct SplitComposerWorldTests {
  @Test func retainedComposerSendsTheNewWorldsVisibleDraft() async throws {
    let store = try WorkspaceStore(path: ":memory:")
    let transport = RecordingResponse()
    let studio = try Studio(store: store, transport: transport)
    studio.sheet = nil
    let first = studio.worldID
    let second = try store.createWorld(name: "Second universe")
    studio.draft = "First universe writing"
    try store.setPreference("composer:\(second.id)", value: "Second universe writing")

    // Like the split workspace's shared inset, this native editor stays mounted across worlds.
    let host = mount(studio)
    _ = try await composer(in: host, showing: studio.draft)
    studio.switchWorld(second.id)
    let editor = try await composer(in: host, showing: "Second universe writing")
    let submitted = "Explore a different route in the second universe"
    replaceText(in: editor, with: submitted)
    #expect(editor.string == submitted)
    let submit = try #require(editor.onSubmit)
    submit()
    let deadline = ContinuousClock.now + .seconds(3)
    while studio.busy && ContinuousClock.now < deadline {
      try await Task.sleep(for: .milliseconds(15))
    }
    #expect(!studio.busy)
    let request = try #require(await transport.requests.first)
    #expect(request.messages.last?["content"] == submitted)
    #expect(try store.preference("composer:\(first)") == "First universe writing")
  }

  @Test func failedDraftWriteKeepsVisibleInputAndSkipsSubmission() async throws {
    let store = try WorkspaceStore(path: ":memory:")
    let transport = RecordingResponse()
    let studio = try Studio(store: store, transport: transport)
    studio.sheet = nil
    studio.draft = "Previously saved writing"
    studio.persistComposer()
    let host = mount(studio)
    let editor = try await composer(in: host, showing: studio.draft)
    try store.db.execute(
      """
      CREATE TRIGGER reject_composer_write BEFORE INSERT ON preferences
      WHEN NEW.key = 'composer:\(studio.worldID)' AND NEW.value = 'Latest writing'
      BEGIN SELECT RAISE(ABORT, 'simulated draft write failure'); END
      """)
    replaceText(in: editor, with: "Latest writing")
    let submit = try #require(editor.onSubmit)
    submit()
    #expect(!studio.busy)
    #expect(await transport.requests.isEmpty)
    #expect(try store.conversations(worldID: studio.worldID).isEmpty)
    #expect(editor.string == "Latest writing")
    #expect(studio.draft == "Previously saved writing")
    #expect(studio.error?.contains("simulated draft write failure") == true)
    #expect(try store.preference("composer:\(studio.worldID)") == "Previously saved writing")
  }

  private func mount(_ studio: Studio) -> NSHostingView<UnifiedComposer> {
    _ = NSApplication.shared
    let host = NSHostingView(
      rootView: UnifiedComposer(studio: studio, companion: true, collapsed: true))
    host.frame = NSRect(x: 0, y: 0, width: 720, height: 160)
    return host
  }

  private func composer(in host: NSView, showing text: String) async throws -> ComposerTextView {
    let deadline = ContinuousClock.now + .seconds(3)
    var matching: ComposerTextView?
    repeat {
      host.layoutSubtreeIfNeeded()
      if let editor = findComposer(in: host), editor.string == text, editor.onSubmit != nil {
        matching = editor
        break
      }
      try await Task.sleep(for: .milliseconds(15))
    } while ContinuousClock.now < deadline
    return try #require(matching, "The composer should show the active universe's restored draft")
  }

  private func findComposer(in view: NSView) -> ComposerTextView? {
    if let editor = view as? ComposerTextView { return editor }
    for child in view.subviews {
      if let editor = findComposer(in: child) { return editor }
    }
    return nil
  }

  private func replaceText(in editor: ComposerTextView, with text: String) {
    editor.insertText(
      text, replacementRange: NSRange(location: 0, length: editor.string.utf16.count))
  }
}
