import SwiftUI
import SynthesisCore

extension CommandPalette {
  @MainActor static func results(
    studio: Studio, query rawQuery: String, indexed: [LoreRecord], activity: [WorldActivity] = []
  ) -> [Item] {
    let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    let terms = query.split(whereSeparator: \.isWhitespace).map(String.init)
    let worldID = studio.worldID
    func matches(_ text: String) -> Bool {
      terms.allSatisfy { text.localizedStandardContains($0) }
    }
    var items: [Item] = []
    // Structured queries are record searches. Title/command fallbacks must not bypass filters.
    if LoreSearchQuery.usesFilters(query) {
      var seen = Set<String>()
      return indexed.filter { $0.worldID == worldID && seen.insert($0.id).inserted }
        .map { recordItem($0, studio: studio, section: "Filtered lore") }
    }
    for (offset, destination) in Destination.allCases.enumerated()
    where matches(
      "\(destination.rawValue) \(destination.summary) \(destination == .knowledge ? "knowledge graph" : "") tool workspace"
    ) {
      items.append(
        Item(
          id: "go-\(destination.rawValue)", section: "Go to", icon: destination.icon,
          title: destination.rawValue, detail: offset < 9 ? "⌘\(offset + 1)" : ""
        ) { studio.navigate(destination) })
    }
    if studio.canReopenDocument && matches("Reopen closed document") {
      items.append(
        Item(
          id: "reopen-document", section: "Documents", icon: "clock.arrow.circlepath",
          title: "Reopen closed document", detail: "⇧⌘T"
        ) { studio.reopenDocument() })
    }
    let create: [(String, String, String, String, () -> Void)] = [
      (
        "New document", "doc.badge.plus", "⌘N", "lore",
        { studio.beginRecordCreation() }
      ),
      (
        "New entity", "circle.hexagongrid", "⌥⌘N", "entity",
        { studio.beginRecordCreation(kind: "entity") }
      ),
      (
        "Capture an idea", "lightbulb", "", "capture",
        { studio.beginRecordCreation(kind: "capture") }
      ),
      ("New conversation", "square.and.pencil", "⇧⌘N", "chat", { studio.newChat() }),
      ("New world…", "globe", "", "world", { studio.sheet = .world }),
    ]
    for entry in create where matches(entry.0) {
      items.append(
        Item(
          id: "new-\(entry.3)", section: "Create", icon: entry.1, title: entry.0, detail: entry.2,
          run: entry.4))
    }
    if studio.canBeginLinking && matches("Link records relationship connect") {
      items.append(
        Item(
          id: "link-records", section: "Create", icon: "link",
          title: "Link records…", detail: "⇧⌘K"
        ) { studio.beginLinkRecords() })
    }
    if !query.isEmpty {
      let categories =
        Vocabulary.categories
        + Set(studio.topLevelRecords.map(\.category))
        .filter { !$0.isEmpty && !Vocabulary.categories.contains($0) }.sorted()
      for category in categories
      where matches("\(Vocabulary.displayCategory(category)) category collection tool") {
        items.append(
          Item(
            id: "category-\(category)", section: "World tools", icon: categoryIcon(category),
            title: Vocabulary.displayCategory(category), detail: "Open collection"
          ) { if studio.worldID == worldID { studio.openLens(category) } })
      }
    }
    let found: [LoreRecord]
    if query.trimmingCharacters(in: .whitespaces).isEmpty {
      found = Array(studio.records.prefix(5))
    } else {
      let titled = studio.records.filter { matches($0.title) }
      let metadata = studio.records.filter {
        matches(
          "\($0.title) \(Vocabulary.displayCategory($0.category)) \(($0.tags ?? []).joined(separator: " ")) \(($0.aliases ?? []).joined(separator: " "))"
        )
      }
      var seen = Set<String>()
      found = Array(
        (titled + metadata + indexed).filter {
          $0.worldID == worldID && seen.insert($0.id).inserted
        }.prefix(50))
    }
    for record in found {
      let scene = ["scene", "scenes"].contains(record.category.lowercased())
      items.append(
        recordItem(
          record, studio: studio,
          section: query.isEmpty ? "Recent lore" : (scene ? "Scenes" : "Lore")))
    }
    // Boards have stable IDs in the same world store. Opening revalidates availability;
    // a stale palette must never recreate an archived map or board.
    let boards = studio.contextBoards.filter {
      matches("\($0.name) \($0.kind == "atlas" ? "map maps atlas" : "board boards canvas")")
    }
    for board in boards.prefix(query.isEmpty ? 3 : 50) {
      items.append(
        Item(
          id: "board-\(board.id)", section: board.kind == "atlas" ? "Maps" : "Canvases",
          icon: board.kind == "atlas" ? "map" : "rectangle.on.rectangle",
          title: board.name, detail: board.kind == "atlas" ? "Atlas" : "Canvas"
        ) {
          guard studio.worldID == worldID else { return }
          studio.openBoard(board.id, kind: board.kind)
        })
    }
    if !query.isEmpty {
      for chat in studio.conversations where matches(chat.title) {
        items.append(
          Item(
            id: "chat-\(chat.id)", section: "Conversations", icon: "bubble.left",
            title: chat.title, detail: relativeDate(chat.updatedAt)
          ) { studio.openChat(chat) })
      }
      for world in studio.worlds where world.id != studio.worldID && matches(world.name) {
        items.append(
          Item(
            id: "world-\(world.id)", section: "Worlds", icon: "globe", title: world.name,
            detail: world.demo ? "Sample" : "Switch world"
          ) { studio.switchWorld(world.id) })
      }
    }
    let assisted = studio.mode == .assisted
    let settings: [(String, String, String, () -> Void)] = [
      (
        assisted ? "Switch to Manual — no model requests" : "Switch to AI Assisted",
        assisted ? "hand.raised" : "sparkles", "⇧⌘M",
        { studio.setMode(assisted ? .manual : .assisted) }
      ),
      (
        studio.dark ? "Use light appearance" : "Use dark appearance",
        studio.dark ? "sun.max" : "moon", "", { studio.toggleTheme() }
      ),
      ("Workspace layouts", "square.stack", "⌥⌘L", { studio.sheet = .layouts }),
      (
        "Open document beside workspace", "rectangle.on.rectangle", "",
        { studio.sheet = .splitRecord }
      ),
      ("World activity history", "clock.arrow.circlepath", "", { studio.sheet = .activity }),
      ("Open settings", "gearshape", "⌘,", { studio.navigate(.settings) }),
      (
        "Import Markdown or text files…", "square.and.arrow.down", "⇧⌘I",
        { studio.importDocuments() }
      ),
      ("Export this world as Markdown…", "folder", "", { studio.exportMarkdown() }),
      ("Export this world as JSON…", "square.and.arrow.up", "", { studio.exportWorld() }),
    ]
    for entry in settings where matches(entry.0) {
      items.append(
        Item(
          id: "set-\(entry.0)", section: "Preferences", icon: entry.1, title: entry.0,
          detail: entry.2, run: entry.3))
    }
    if !query.isEmpty {
      let settingsQuery =
        query.lowercased().hasPrefix("settings ") ? String(query.dropFirst(9)) : query
      let foundSettings =
        query.lowercased() == "settings"
        ? SettingsItem.allCases
        : SettingsItem.matching(settingsQuery, section: .general)
      for setting in foundSettings {
        items.append(
          Item(
            id: "setting-\(setting)", section: "Settings", icon: setting.section.icon,
            title: setting.title, detail: setting.section.rawValue
          ) {
            studio.openSettings(setting.section, query: setting.title)
            if setting == .connection { studio.assistantSettingsExpanded = true }
          })
      }
    }
    // Quick links to current objects; the full editing history has its own searchable view.
    for change in activity.filter({
      $0.worldID == worldID && matches("\($0.title) \($0.detail) recent changes activity")
    }).prefix(query.isEmpty ? 6 : 50) {
      let icon: String =
        switch change.kind {
        case .world: "globe"
        case .conversation: "bubble.left"
        case .record: "doc.text"
        case .board: change.boardKind == "atlas" ? "map" : "rectangle.on.rectangle"
        case .relationship: Destination.knowledge.icon
        case .event, .lane: Destination.timeline.icon
        case .proposal: Destination.review.icon
        }
      items.append(
        Item(
          id: "activity-\(change.id)", section: "Recent changes", icon: icon,
          title: change.title, detail: change.detail
        ) { studio.openActivity(change) })
    }
    // Commands and lore that match come first, so typing a command's name and pressing Return
    // runs it. Keeping typed text as an idea is last, and first only when nothing else matches.
    var keep: [Item] = []
    let typed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    if typed.count >= 3 {
      // Anything typed here can be kept without filling in a form.
      keep.append(
        Item(
          id: "capture-text", section: "Keep this", icon: "lightbulb",
          title: "Capture “\(typed.prefix(48))\(typed.count > 48 ? "…" : "")” as an idea",
          detail: "Saved to Library"
        ) { studio.capture(typed) })
      if studio.mode == .assisted {
        keep.append(
          Item(
            id: "ask-text", section: "Keep this", icon: "bubble.left",
            title: "Start a conversation with this", detail: "Nothing is sent yet"
          ) {
            studio.newChat()
            studio.draft = typed
            studio.persistComposer()
          })
      }
    }
    return items + keep
  }

  @MainActor private static func recordItem(_ record: LoreRecord, studio: Studio, section: String)
    -> Item
  {
    Item(
      id: "record-\(record.id)", section: section, icon: recordIcon(record), title: record.title,
      detail: [Vocabulary.displayCategory(record.category), Vocabulary.stateLabel(record.state)]
        .filter { !$0.isEmpty }.joined(separator: " · "), tint: studio.t.category(record.category),
      record: record
    ) { studio.openRecord(record) }
  }
}
