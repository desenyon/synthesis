import Foundation

enum SettingsSection: String, CaseIterable, Identifiable {
  case general = "General"
  case writing = "Writing"
  case assistant = "Assistant"
  case world = "This world"
  case data = "Data"
  var id: String { rawValue }
  var icon: String {
    switch self {
    case .general: "gearshape"
    case .writing: "textformat"
    case .assistant: "bubble.left"
    case .world: "globe"
    case .data: "archivebox"
    }
  }
  var detail: String {
    switch self {
    case .general: "Make room for the way you work."
    case .writing: "A comfortable place to put your thoughts."
    case .assistant: "Your creative partner, on your terms."
    case .world: "Identity and starting points for this universe."
    case .data: "Bring your ideas in. Take your world with you."
    }
  }
}

/// One searchable inventory. The same entries label and render the actual controls.
enum SettingsItem: CaseIterable, Identifiable {
  case appearance, sidebar, counts, recents, launch, previews
  case textSize, readingWidth, spelling, quotes, dashes, links, words
  case assistance, connection, sendKey
  case identity, cover, category, chatMode
  case importLore, importWorld, portable, markdown, json, images, sample
  var id: Self { self }
  var section: SettingsSection {
    switch self {
    case .appearance, .sidebar, .counts, .recents, .launch, .previews: .general
    case .textSize, .readingWidth, .spelling, .quotes, .dashes, .links, .words: .writing
    case .assistance, .connection, .sendKey: .assistant
    case .identity, .cover, .category, .chatMode: .world
    default: .data
    }
  }
  var title: String {
    switch self {
    case .appearance: "Appearance"
    case .sidebar: "Expanded navigation"
    case .counts: "Category counts"
    case .recents: "Recent conversations"
    case .launch: "Open at launch"
    case .previews: "Library previews"
    case .textSize: "Body text size"
    case .readingWidth: "Reading width"
    case .spelling: "Check spelling"
    case .quotes: "Smart quotes"
    case .dashes: "Smart dashes"
    case .links: "Detect web links"
    case .words: "Word count"
    case .assistance: "AI assistance"
    case .connection: "Subscription connection"
    case .sendKey: "Send a message"
    case .identity: "Name and description"
    case .cover: "World cover"
    case .category: "New entity type"
    case .chatMode: "New conversation mode"
    case .importLore: "Import writing"
    case .importWorld: "Open a world file"
    case .portable: "Synthesis world"
    case .markdown: "Markdown"
    case .json: "JSON"
    case .images: "Images"
    case .sample: "Explore a sample world"
    }
  }
  var detail: String {
    switch self {
    case .appearance: "Light or dark across the whole studio."
    case .sidebar: "Show labels alongside workspace icons."
    case .counts: "Show record totals beside world categories."
    case .recents: "How many chats appear in navigation."
    case .launch: "Choose your starting workspace on this Mac."
    case .previews: "Show a line of writing beneath each Library title."
    case .textSize: "For unformatted writing and the Body style. Existing formatting is preserved."
    case .readingWidth: "The maximum width of the document column."
    case .spelling: "Underline possible mistakes. Words are never autocorrected."
    case .quotes: "Use curly quotation marks as you type."
    case .dashes: "Turn double hyphens into typographic dashes."
    case .links: "Make typed URLs clickable in documents."
    case .words: "Show a running total in the editor toolbar."
    case .assistance: "Manual stops active generation and blocks model requests."
    case .connection: "Codex or Claude Code. Model choice, sign-in and privacy."
    case .sendKey: "Shift–Return always adds a new line."
    case .identity: "The name and description shown in your world library."
    case .cover: "Saved with this world and included in its portable file."
    case .category: "A starting category, including your own clans, sects or orders."
    case .chatMode: "The starting approach for a new chat in this world."
    case .importLore: "Markdown and text become draft documents in the current world."
    case .importWorld: "Import a .synthesis file as an independent world."
    case .portable: "A complete .synthesis snapshot: lore, boards, images, chats and history."
    case .markdown: "Readable files with links, metadata and entity sections."
    case .json: "Structured world data, revisions, proposals and archived records."
    case .images: "Extract saved board artwork, maps and the world cover."
    case .sample: "Open Aster, a clearly labeled universe you can explore."
    }
  }
  private var keywords: String {
    switch self {
    case .appearance: "theme color colour"
    case .textSize: "font typography"
    case .readingWidth: "margins layout"
    case .sendKey: "keyboard shortcut enter return"
    case .connection: "gpt claude codex model subscription login authentication privacy"
    case .portable: "export backup snapshot"
    case .markdown, .json, .images: "export save"
    default: ""
    }
  }
  static func matching(_ query: String, section: SettingsSection) -> [Self] {
    let terms = query.split(whereSeparator: \.isWhitespace).map(String.init)
    return allCases.filter { item in
      guard !terms.isEmpty else { return item.section == section }
      let searchable = "\(item.title) \(item.detail) \(item.section.rawValue) \(item.keywords)"
      return terms.allSatisfy { searchable.localizedStandardContains($0) }
    }
  }
}
