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

  @Test func writingPreferencesConfigureNativeEditorWithoutReformattingRichText() throws {
    var preferences = StudioPreferences()
    preferences.bodySize = 20
    preferences.spellCheck = true
    preferences.smartQuotes = false
    preferences.smartDashes = false
    preferences.automaticLinks = false
    var editor = RichDocumentEditor(
      id: "test", body: "A thought", rtf: nil, t: Theme(dark: true), reloadToken: 0,
      preferences: preferences, changed: { _, _ in })
    let view = NSTextView()
    editor.install(view)
    editor.configureWriting(view)
    #expect(view.isContinuousSpellCheckingEnabled)
    #expect(!view.isAutomaticSpellingCorrectionEnabled)
    #expect(!view.isAutomaticQuoteSubstitutionEnabled && !view.isAutomaticDashSubstitutionEnabled)
    #expect(!view.isAutomaticLinkDetectionEnabled)
    #expect(
      (view.textStorage?.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)?.pointSize == 20)
    let original = NSAttributedString(
      string: "A title", attributes: [.font: NSFont.boldSystemFont(ofSize: 28)])
    let data = try original.data(
      from: NSRange(location: 0, length: original.length),
      documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
    editor = RichDocumentEditor(
      id: "rich", body: "A title", rtf: data.base64EncodedString(), t: Theme(dark: true),
      reloadToken: 0, preferences: preferences, changed: { _, _ in })
    editor.install(view)
    #expect(view.string == "A title")
    #expect(
      (view.textStorage?.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)?.pointSize == 28)
    editor.preferences = StudioPreferences()
    editor.configureWriting(view)
    #expect(!view.isContinuousSpellCheckingEnabled && view.isAutomaticQuoteSubstitutionEnabled)
    #expect(view.isAutomaticDashSubstitutionEnabled && view.isAutomaticLinkDetectionEnabled)
    #expect(
      (view.textStorage?.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)?.pointSize == 28)
  }

  @Test func settingsSearchFindsActualControlsAcrossSections() {
    #expect(
      Set(SettingsItem.matching(" EXPORT ", section: .writing))
        == Set([.portable, .markdown, .json, .images]))
    #expect(SettingsItem.matching("spell", section: .general) == [.spelling])
    #expect(SettingsItem.matching("model", section: .data) == [.assistance, .connection])
    #expect(SettingsItem.matching("font", section: .assistant) == [.textSize])
    #expect(SettingsItem.matching("unicorn", section: .general).isEmpty)
    for section in SettingsSection.allCases {
      #expect(SettingsItem.matching("  ", section: section).allSatisfy { $0.section == section })
    }
    for item in SettingsItem.allCases {
      #expect(SettingsItem.matching(item.title, section: .general).contains(item))
    }
  }

  @Test func providerSelectionAndSettingsNavigationDoNotStartChecksOrGeneration() throws {
    let studio = try Studio(store: WorkspaceStore(path: ":memory:"))
    studio.setMode(.manual)
    studio.setProvider(.claudeCode)
    studio.openAssistantSettings()
    #expect(studio.destination == .settings && studio.settingsSection == .assistant)
    #expect(studio.mode == .manual && !studio.checkingProvider && studio.providerStatus == nil)
    #expect(studio.sheet == nil)
  }
}
