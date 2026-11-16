import AppKit
import SynthesisCore
import Testing

@testable import SynthesisUI

@MainActor struct PreferenceBehaviorTests {
  @Test func worldSwitchAndNewChatUseTheirOwnDefaults() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let studio = try Studio(store: store)
    let original = studio.worldID
    studio.updateWorldDefaults {
      $0.chatMode = "Critique"
      $0.entityCategory = "Clans"
    }
    studio.newChat()
    #expect(studio.preset == "Critique")
    let other = try store.createWorld(name: "Other")
    studio.switchWorld(other.id)
    #expect(studio.worldDefaults.entityCategory.isEmpty && studio.preset == "Create")
    studio.switchWorld(original)
    #expect(studio.worldDefaults.entityCategory == "Clans" && studio.preset == "Critique")
    studio.updatePreferences {
      $0.launchWorkspace = "Library"
      $0.sidebarCounts = false
    }
    let reopened = try Studio(store: store)
    #expect(reopened.destination == .library && !reopened.preferences.sidebarCounts)
  }

  @Test func manualLaunchDoesNotLandOnConversation() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let studio = try Studio(store: store)
    studio.updatePreferences { $0.launchWorkspace = "Conversation" }
    studio.setMode(.manual)
    #expect(try Studio(store: store).destination == .library)
  }

  @Test func composerSendShortcutHonorsModifiersAndMentions() throws {
    let view = ComposerTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 100))
    var sent = 0
    view.onSubmit = { sent += 1 }
    func enter(_ modifiers: NSEvent.ModifierFlags = []) throws {
      let event = try #require(
        NSEvent.keyEvent(
          with: .keyDown, location: .zero, modifierFlags: modifiers, timestamp: 0,
          windowNumber: 0, context: nil, characters: "\r", charactersIgnoringModifiers: "\r",
          isARepeat: false, keyCode: 36))
      view.keyDown(with: event)
    }
    try enter()
    #expect(sent == 1)
    view.sendShortcut = .commandEnter
    view.string = "A thought"
    view.setSelectedRange(NSRange(location: view.string.utf16.count, length: 0))
    try enter()
    #expect(sent == 1 && view.string.hasSuffix("\n"))
    try enter(.command)
    #expect(sent == 2)
    try enter([.command, .shift])
    #expect(sent == 2)
    view.onMentionKey = { _ in true }
    try enter(.command)
    #expect(sent == 2)
  }
}
