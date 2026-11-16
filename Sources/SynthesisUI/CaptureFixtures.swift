import AppKit
import Foundation
import SynthesisCore

// Authored sample data for the isolated screenshot runner only. Never used as a provider.
extension Studio {
  public static let captureStates = [
    "conversation-home", "conversation", "sheet-artwork", "canvas", "companion", "manual",
    "collapsed", "light",
    "graph", "graph-selected", "library", "editor", "timeline", "atlas",
    "palette", "light-conversation", "light-library", "light-graph", "light-editor",
    "manual-conversation", "toast", "review", "review-canon", "review-checks", "empty-conversation",
    "empty-canvas", "empty-library",
    "empty-graph", "empty-timeline", "empty-atlas", "sheet-record",
    "worlds", "settings", "onboarding", "library-companion",
    "sheet-canon", "sheet-history", "sheet-relation", "sheet-rule",
    "sections", "light-sections", "manual-sections", "sections-companion", "sections-empty",
    "sheet-section", "section-editor",
    "settings-writing", "settings-assistant", "settings-world", "settings-data",
    "settings-search", "settings-no-results", "light-settings", "light-settings-writing",
    "settings-assistant-details",
    "manual-settings", "settings-collapsed", "settings-model-search", "preferences-editor",
    "preferences-library",
  ]
  public func prepareConnectedCapture() throws -> (board: String, conversation: String) {
    guard ProcessInfo.processInfo.environment["SYNTHESIS_CAPTURE_DIR"] != nil else {
      throw SynthesisError.invalid("Capture fixtures require the isolated runner.")
    }
    // A genuinely empty world, so empty states are captured as a new creator meets them.
    if try !store.worlds().contains(where: { $0.name == "Halcyon" }) {
      _ = try store.createWorld(name: "Halcyon")
    }
    loadSample()
    try reload()
    guard let board = try store.boards(worldID: worldID, kind: "canvas").first,
      let mira = records.first(where: { $0.title == "Mira Vale" }),
      let power = records.first(where: { $0.title == "The art of remembrance" }),
      let order = records.first(where: { $0.title == "Tidekeepers" }),
      let sea = records.first(where: { $0.title == "The Glass Sea" }),
      let city = records.first(where: { $0.title == "The Drowned City" })
    else { throw SynthesisError.notFound }
    if try store.recordSections(worldID: worldID, parentID: mira.id).isEmpty {
      try store.createRecordSection(
        worldID: worldID, parentID: mira.id, title: "What she is searching for",
        body:
          "Mira keeps a map of every place her sister once described. One coastline is missing from all the tide ledgers. She wants to find it before the next crossing."
      )
      try store.createRecordSection(
        worldID: worldID, parentID: mira.id, title: "A borrowed craft",
        body:
          "She learned to map by following the Tidekeepers. Her charts preserve landmarks, but not the memories surrendered to reach them.\n\nThe boundary between a faithful map and a comforting fiction remains an open question."
      )
      try store.createRecordSection(
        worldID: worldID, parentID: mira.id, title: "Unanswered questions",
        body:
          "What would she refuse to forget?\nWho taught her to distrust a finished map?\nWhat happens when two charts disagree?"
      )
    }
    // One accepted record so canon and draft states are both visible in captures.
    _ = try store.promote(
      worldID: worldID, id: sea.id, version: sea.version, confirmation: sea.id)
    // An accepted record with a newer draft, so canon review has a real difference to show.
    let accepted = try store.promote(
      worldID: worldID, id: order.id, version: order.version, confirmation: order.id)
    _ = try store.saveRecord(
      worldID: worldID, id: order.id, version: accepted.version, title: order.title,
      body:
        "A coastal order responsible for safe passage across the Glass Sea.\nThey keep the tide ledgers and decide who may cross.",
      rtf: nil)
    if let artwork = Self.sampleArtwork() {
      let atlas = AtlasDocument(
        image: artwork.base64EncodedString(),
        markers: [
          MapMarker(recordID: sea.id, x: 0.46, y: 0.52),
          MapMarker(recordID: city.id, x: 0.7, y: 0.66),
          MapMarker(recordID: order.id, x: 0.2, y: 0.36),
        ])
      _ = try store.saveBoard(
        worldID: worldID, name: "Atlas", kind: "atlas",
        content: String(decoding: try JSONEncoder().encode(atlas), as: UTF8.self))
    }
    let chat = try store.createConversation(
      worldID: worldID, title: "The price of remembrance · sample")
    try store.appendMessage(
      worldID: worldID, conversationID: chat.id, role: "user",
      body:
        "How might [Mira Vale](synthesis://record/\(mira.id)) cross the sea without losing the memory of her sister?",
      state: "complete")
    try store.appendMessage(
      worldID: worldID, conversationID: chat.id, role: "assistant",
      body:
        "## A choice worth exploring\n\nThe [art of remembrance](synthesis://record/\(power.id)) asks for a memory in return. Mira could borrow a Tidekeeper’s crossing skill — but choose to surrender the memory of her first map instead.\n\n| Possibility | Consequence |\n| --- | --- |\n| Borrow the skill | Lose her first map |\n| Cross without it | Trust an uncertain route |\n\nThree things your drafts leave open:\n\n- Which memories the sea accepts\n- Whether a surrendered memory can be returned\n- Who decides the price\n\n> This is a hypothetical direction. The existing drafts do not establish which memory the sea would accept.",
      state: "imported-example")
    // An authored change set attached to the sample answer, so proposal review can be seen
    // without a provider. It is staged like any model proposal and applies nothing by itself.
    if let example = try store.messages(worldID: worldID, conversationID: chat.id).last {
      try store.saveMessageContext(
        worldID: worldID, messageID: example.id,
        sources: try store.contextRecords(
          worldID: worldID,
          prompt: "memory crossing [Mira Vale](synthesis://record/\(mira.id))", limit: 6))
      try store.stageProposal(
        worldID: worldID, conversationID: chat.id, messageID: example.id,
        payload: [
          "summary": "Record the price of a crossing and who decides it",
          "changes": [
            [
              "action": "create_record", "kind": "entity", "title": "The Tide Ledger",
              "category": "Cosmology",
              "body":
                "A record of every memory surrendered to the sea.\nOnly the eldest keeper may read it.",
              "evidence": [power.id, order.id],
            ],
            [
              "action": "relate", "source": order.id, "target": "The Tide Ledger",
              "label": "keeps",
            ],
            [
              "action": "revise_record", "id": mira.id,
              "body":
                "A cartographer tracing places that do not stay still.\nShe has never paid the sea's price.",
              "reason": "Make her debt explicit before the crossing",
            ],
            ["action": "add_event", "title": "Mira asks to read the ledger", "source": mira.id],
          ],
        ])
    }
    try store.appendMessage(
      worldID: worldID, conversationID: chat.id, role: "user",
      body:
        "Keep both possibilities open. I want the [Tidekeepers](synthesis://record/\(order.id)) to disagree about what the crossing costs.",
      state: "complete")
    try reload()
    return (board.id, chat.id)
  }
  public func configureConnectedCapture(_ state: String, board: String, conversation: String) {
    _ = flushEditor()
    editorSave = nil
    let wanted = worlds.first { state.hasPrefix("empty-") ? $0.name == "Halcyon" : $0.demo }
    if let wanted, wanted.id != worldID { switchWorld(wanted.id) }
    let board = state.hasPrefix("empty-") ? "" : board
    let conversation = state.hasPrefix("empty-") ? nil : Optional(conversation)
    // Each capture represents opening this board at the requested window size.
    // Clear only the isolated fixture viewport; normal workspaces retain theirs.
    perform {
      if let saved = try store.boards(worldID: worldID, kind: "canvas").first(where: {
        $0.id == board
      }),
        var document = try? JSONDecoder().decode(
          CanvasDocument.self, from: Data(saved.content.utf8))
      {
        document.viewport = nil
        _ = try store.saveBoard(
          worldID: worldID, id: saved.id, name: saved.name, kind: "canvas",
          content: String(decoding: try JSONEncoder().encode(document), as: UTF8.self))
      }
    }
    updatePreferences { $0 = StudioPreferences() }
    if state.hasPrefix("preferences-") {
      updatePreferences {
        $0.bodySize = 20
        $0.readingWidth = 640
        $0.wordCount = false
        $0.libraryPreviews = false
        $0.sidebarCounts = false
        $0.recentChats = 0
      }
    }
    settingsSection = .general
    settingsQuery = ""
    assistantSettingsExpanded = state == "settings-assistant-details"
    recordSectionTabs = [:]
    selectedRecord = nil
    palette = false
    sheet = nil
    toast = nil
    stop()
    setMode(state.hasPrefix("manual") ? .manual : .assisted)
    dark = !state.hasPrefix("light")
    collapsed = ["collapsed", "settings-collapsed"].contains(state)
    inspector = true
    libraryCategory = nil
    canvasBoardID = board.isEmpty ? nil : board
    companionExpanded = ["companion", "library-companion", "sections-companion"].contains(state)
    companionWidth = 400
    draft = ""
    preset = "Create"
    conversationID = state == "conversation-home" ? nil : conversation
    perform { try reload() }
    switch state {
    case "conversation-home", "conversation", "light-conversation", "manual-conversation",
      "empty-conversation":
      destination = .chat
    case "library", "light-library", "empty-library", "preferences-library": destination = .library
    case "toast":
      destination = .library
      show("Archived “Oren Ashe”", icon: "archivebox", actionTitle: "Undo") {}
    case "worlds": destination = .worlds
    case "settings", "light-settings", "settings-collapsed": destination = .settings
    case "manual-settings":
      destination = .settings
      settingsSection = .assistant
    case "settings-writing", "light-settings-writing":
      destination = .settings
      settingsSection = .writing
    case "settings-assistant", "settings-assistant-details":
      destination = .settings
      settingsSection = .assistant
    case "settings-world":
      destination = .settings
      settingsSection = .world
    case "settings-data":
      destination = .settings
      settingsSection = .data
    case "settings-search":
      destination = .settings
      settingsQuery = "export"
    case "settings-no-results":
      destination = .settings
      settingsQuery = "unicorn"
    case "settings-model-search":
      destination = .settings
      settingsQuery = "model"
      assistantSettingsExpanded = true
    case "library-companion": destination = .library
    case "onboarding":
      destination = .chat
      sheet = .onboarding
    case "sheet-record":
      destination = .library
      newRecordKind = "entity"
      sheet = .document
    case "sheet-canon", "sheet-history":
      destination = .library
      selectedRecord = records.first { $0.title == "Tidekeepers" }
    case "graph", "graph-selected", "light-graph", "sheet-relation", "empty-graph":
      destination = .knowledge
    case "review", "review-canon", "review-checks": destination = .review
    case "timeline", "empty-timeline": destination = .timeline
    case "atlas", "empty-atlas": destination = .atlas
    case "sections", "light-sections", "manual-sections", "sections-companion", "sheet-section",
      "section-editor":
      destination = .library
      inspector = false
      selectedRecord = records.first { $0.title == "Mira Vale" }
      if let id = selectedRecord?.id { recordSectionTabs[id] = true }
      if state == "section-editor", let parent = selectedRecord {
        selectedRecord = try? store.recordSections(worldID: worldID, parentID: parent.id).first?
          .record
      }
    case "sections-empty":
      destination = .library
      inspector = false
      selectedRecord = records.first { $0.title == "Oren Ashe" }
      if let id = selectedRecord?.id { recordSectionTabs[id] = true }
    case "editor", "light-editor", "sheet-rule", "preferences-editor":
      destination = .library
      if state == "preferences-editor" { inspector = false }
      selectedRecord = records.first {
        $0.title == (state == "sheet-rule" ? "The art of remembrance" : "Mira Vale")
      }
      if state == "sheet-rule" { inspector = true }
    case "palette":
      destination = .chat
      palette = true
    default: destination = .canvas
    }
    captureHint = state
    captureNonce += 1
  }
}
