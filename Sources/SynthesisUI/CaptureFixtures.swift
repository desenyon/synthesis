import AppKit
import Foundation
import SynthesisCore

// Authored sample data for the isolated screenshot runner only. Never used as a provider.
extension Studio {
  public static let captureStates =
    QuickCaptureController.captureStates + conversationToolsCaptureStates
    + entitySchemaCaptureStates + bidirectionalRelationshipCaptureStates
    + relationshipMetadataCaptureStates + entityNamesCaptureStates
    + chronologyHierarchyCaptureStates + CanvasReferencePicker.captureStates + [
      "session-writing", "light-session-writing", "manual-session-writing", "session-sections",
      "session-split", "session-graph", "session-timeline", "session-atlas", "session-canvas",
      "session-conversation", "session-library",
      "focus-writing", "light-focus-writing", "manual-focus-writing", "focus-restored",
      "focus-from-properties", "focus-from-properties-restored",
      "focus-collapsed", "focus-split", "focus-blank", "focus-atlas", "focus-graph",
      "focus-canvas", "focus-conversation",
      "startup-settings", "light-startup-settings", "startup-atlas", "light-startup-atlas",
      "manual-startup-atlas", "startup-conversation", "manual-startup-conversation",
      "startup-canvas", "startup-dashboard", "startup-last", "startup-empty-atlas",
      "keyboard-entity", "light-keyboard-entity", "manual-keyboard-entity", "keyboard-created",
      "keyboard-link", "light-keyboard-link", "manual-keyboard-link", "keyboard-reference",
      "keyboard-inspector", "keyboard-mode", "keyboard-empty",
      "global-history-settings", "light-global-history-settings", "global-history-timeline",
      "global-history-record", "manual-global-history-record", "global-history-review",
      "global-history-map", "global-history-canvas", "global-history-graph",
      "global-history-library",
      "atlas-context-before", "atlas-context-return", "light-atlas-context-return",
      "manual-atlas-context-return", "atlas-context-map-switch", "atlas-context-tools",
      "atlas-context-layers", "atlas-context-split", "atlas-context-fit",
      "selection-graph", "light-selection-graph", "manual-selection-graph",
      "selection-canvas", "light-selection-canvas", "selection-atlas", "light-selection-atlas",
      "selection-regions", "selection-library", "selection-timeline",
      "panels-default", "panels-narrow", "panels-wide", "light-panels-wide", "manual-panels-wide",
      "panels-collapsed", "panels-inspector-wide", "panels-companion-wide",
      "panels-canvas-companion",
      "panels-settings",
      "status-save-waiting", "status-save-running", "status-save-failed",
      "light-status-save-failed",
      "status-review-running", "status-review-failed", "light-status-review-complete",
      "status-simulate", "light-status-simulate", "status-agent-failed",
      "scroll-regions", "scroll-regions-document", "scroll-regions-inspector",
      "scroll-regions-sidebar",
      "light-scroll-regions-inspector", "manual-scroll-regions-document",
      "document-tabs", "light-document-tabs", "manual-document-tabs", "document-tabs-many",
      "document-tabs-reopened", "document-tabs-sections",
      "graph-zoom-overview", "graph-zoom-summary", "graph-zoom-detail",
      "light-graph-zoom-overview", "light-graph-zoom-detail", "manual-graph-zoom-detail",
      "dashboard-activity", "light-dashboard-activity", "dashboard", "light-dashboard",
      "manual-dashboard", "dashboard-empty",
      "dashboard-project", "dashboard-new-project", "dashboard-review", "dashboard-long",
      "layouts", "light-layouts", "manual-layouts", "layouts-empty", "layouts-many",
      "layouts-archived", "layouts-applied", "light-layouts-applied",
      "history-trail", "history-back", "history-map", "manual-history-trail",
      "light-history-trail", "collapsed-history-trail",
      "inspector-library", "light-inspector-library", "manual-inspector-library",
      "inspector-graph", "inspector-canvas", "inspector-atlas", "light-inspector-atlas",
      "inspector-event", "inspector-lane", "inspector-conversation", "inspector-review",
      "inspector-worlds", "inspector-settings", "inspector-empty", "inspector-hidden",
      "inspector-mechanics",
      "composer-attached", "light-composer-attached", "composer-context", "light-composer-context",
      "composer-browser", "composer-overflow", "composer-expanded",
      "composer-companion", "light-composer-companion", "composer-command-return",
      "composer-unavailable", "oled-conversation", "oled-canvas", "oled-settings",
      "opaque-conversation", "opaque-graph", "light-opaque-graph",
      "editor-long", "light-editor-long",
      "profile-empty", "light-profile-empty", "profile-artwork", "light-profile-artwork",
      "profile-connected", "profile-writing", "profile-event", "manual-profile-empty",
      "profile-artwork-place", "profile-artwork-banner",
      "compact-library", "immersive-library", "light-compact-library", "light-immersive-library",
      "compact-worlds", "immersive-worlds", "compact-mechanics", "immersive-mechanics",
      "compact-sections", "immersive-sections",
      "sidebar-long", "light-sidebar-long", "sidebar-history", "sidebar-folded",
      "sidebar-opaque", "light-sidebar-opaque", "empty-sidebar", "light-collapsed",
      "atlas-linked", "light-atlas-linked", "manual-atlas-linked", "atlas-details", "atlas-new",
      "atlas-local", "atlas-hierarchy-selected", "atlas-hierarchy-empty-parent",
      "mechanics", "light-mechanics", "manual-mechanics", "mechanics-empty", "mechanics-scenario",
      "mechanics-review", "mechanics-history",
      "components", "light-components", "manual-components", "components-empty",
      "entity-components",
      "component-new",
      "conversation-home", "light-conversation-home", "conversation-loading", "conversation",
      "sheet-artwork", "canvas", "companion", "manual",
      "collapsed", "light",
      "graph", "graph-selected", "graph-neighbourhood-one", "graph-neighbourhood-two",
      "library", "editor", "timeline", "atlas",
      "palette", "palette-body", "palette-search", "palette-maps", "palette-scenes",
      "palette-settings",
      "palette-tools", "palette-recent", "light-palette-search", "manual-palette-search",
      "palette-long", "palette-unmatched", "light-conversation", "light-library", "light-graph",
      "search-faction", "search-canon", "search-quoted", "search-invalid", "search-no-results",
      "light-search-faction", "manual-search-faction", "search-library", "search-library-error",
      "navigation-customized", "light-navigation-customized", "manual-navigation-customized",
      "navigation-options", "light-navigation-options", "navigation-empty", "navigation-rail",
      "navigation-default", "navigation-error", "navigation-long",
      "navigation-categories", "light-navigation-categories", "navigation-settings",
      "favorites-library", "light-favorites-library", "favorites-editor", "manual-favorites-editor",
      "favorites-inspector", "favorites-rail", "favorites-options", "light-favorites-options",
      "favorites-empty", "favorites-long",
      "favorites-collection",
      "split-atlas", "light-split-atlas", "manual-split-atlas", "split-timeline", "split-graph",
      "split-editor", "light-split-editor", "split-picker", "split-inspector", "split-closed",
      "split-swapped", "split-long", "split-canvas",
      "drag-search", "light-drag-search", "drag-favorites", "drag-targets", "light-drag-targets",
      "manual-drag-targets", "drag-second-pane", "drag-opened", "light-drag-opened", "drag-canvas",
      "reference-editor", "reference-composer", "proposal-faction-batch",
      "request-pins", "request-pins-browser", "context-exclusions", "context-submitted",
      "changes-history", "light-changes-history", "manual-changes-history", "changes-approvals",
      "changes-relations", "changes-search", "changes-empty", "changes-archived",
      "changes-dashboard", "changes-reconstructed",
      "light-editor",
      "manual-conversation", "toast", "review", "review-canon", "review-checks",
      "empty-conversation",
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
      "conversation-interrupted", "review-edits", "timeline-edit", "timeline-companion",
      "graph-companion", "atlas-companion", "light-atlas-companion", "editor-recovered",
      "what-if-new", "what-if-send",
      "review-what-if", "worlds-what-if", "mechanics-tree", "mechanics-requires", "atlas-regions",
      "atlas-drawing", "atlas-placing", "light-atlas-drawing", "timeline-compact",
      "timeline-overview", "sheet-generate",
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
    // Review fixtures: a tag spelt two ways and a one-way relationship recorded in both
    // directions, so Checks shows the newer observations.
    if let oren = records.first(where: { $0.title == "Oren Ashe" }), (oren.tags ?? []).isEmpty {
      _ = try store.saveMetadata(
        worldID: worldID, id: oren.id, version: oren.version, tags: ["Cartography"], aliases: [])
      _ = try store.addRelation(
        worldID: worldID, source: mira.id, target: oren.id, label: "mentors")
    }
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
        ],
        regions: [
          MapRegion(
            recordID: sea.id,
            points: [
              [0.36, 0.38], [0.52, 0.34], [0.6, 0.46], [0.55, 0.62], [0.41, 0.64], [0.33, 0.52],
            ])
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
    if ProcessInfo.processInfo.environment["SYNTHESIS_CAPTURE_STATES"]?.contains("sidebar") ?? true
    {
      let stress = try store.createWorld(
        name: "Aster — chronicles of the wandering archipelago beyond the remembered sea")
      if let cover = try store.preference("world-cover:\(worldID)") {
        try store.setPreference("world-cover:\(stress.id)", value: cover)
      }
      for index in 1...1024 {
        _ = try store.createRecord(
          worldID: stress.id, title: "Archive character \(index)", kind: "entity",
          category: "Characters")
      }
      for title in [
        "Who remembers the first crossing?",
        "The maps beneath the city",
        "A treaty between the coastal orders",
        "The story we have not written yet",
        "How the Tidekeepers lost their names — a conversation about memory, inheritance and the sea",
        "Northern kingdoms",
        "The limits of remembrance",
        "Two possible histories of the same island",
      ] {
        let history = try store.createConversation(worldID: stress.id, title: title)
        try store.appendMessage(
          worldID: stress.id, conversationID: history.id, role: "user",
          body: "A saved idea for later: \(title)", state: "complete")
      }
      try reload()
    }
    return (board.id, chat.id)
  }
  /// A what-if of the sample world with a rewrite, a new entity, a relationship, an event and
  /// one edit made in both worlds, so the send preview shows every kind of row.
  private func captureWhatIf() -> String? {
    let name = "What if the sea never froze?"
    if let existing = worlds.first(where: { $0.name == name }) { return existing.id }
    var result: String?
    perform {
      let parentID = worldID
      let branch = try store.createWhatIfBranch(parentID: parentID, name: name)
      let copies = Dictionary(
        try store.records(worldID: branch.id).map { ($0.title, $0) },
        uniquingKeysWith: { a, _ in a })
      if let sea = copies["The Glass Sea"] {
        _ = try store.saveRecord(
          worldID: branch.id, id: sea.id, version: sea.version, title: sea.title,
          body:
            "The sea never hardens. Crossings are made by boat, and the drowned city stays hidden.",
          rtf: nil)
      }
      let ferry = try store.createRecord(
        worldID: branch.id, title: "The Ferrymen's Guild",
        body: "Rowers who replaced the Tidekeepers once the glass stopped forming.", kind: "entity",
        category: "Factions")
      if let order = copies["Tidekeepers"] {
        _ = try store.addRelation(
          worldID: branch.id, source: ferry.id, target: order.id, label: "replaces")
        if let parentOrder = try store.records(worldID: parentID).first(where: {
          $0.title == "Tidekeepers"
        }) {
          _ = try store.saveRecord(
            worldID: parentID, id: parentOrder.id, version: parentOrder.version,
            title: parentOrder.title, body: parentOrder.body + " They never sail.", rtf: nil)
          _ = try store.saveRecord(
            worldID: branch.id, id: order.id, version: order.version, title: order.title,
            body: order.body + " They lost their purpose.", rtf: nil)
        }
      }
      _ = try store.addEvent(
        worldID: branch.id, title: "The last frozen dawn", date: "Year 1 of open water",
        source: ferry.id)
      try reload()
      result = branch.id
    }
    return result
  }
  public func configureConnectedCapture(_ state: String, board: String, conversation: String) {
    endRecordDrag()
    clearRequestPins()
    submittedAssistantContext = nil
    if Self.conversationToolsCaptureStates.contains(state) {
      configureConversationToolsCapture(state, board: board, conversation: conversation)
      return
    }
    if Self.entitySchemaCaptureStates.contains(state) {
      configureEntitySchemaCapture(state, board: board, conversation: conversation)
      return
    }
    if QuickCaptureController.captureStates.contains(state) {
      configureConnectedCapture("conversation", board: board, conversation: conversation)
      dark = !state.hasPrefix("light-")
      captureHint = state
      return
    }
    if state.contains("focus-") {
      configureFocusCapture(state, board: board, conversation: conversation)
      return
    }
    focusMode = false
    if state.contains("keyboard-") {
      configureKeyboardCreationCapture(state, board: board, conversation: conversation)
      return
    }
    if state.contains("global-history-") {
      configureGlobalNavigationCapture(state, board: board, conversation: conversation)
      return
    }
    if state.contains("atlas-context-") {
      configureAtlasContextCapture(state, board: board, conversation: conversation)
      return
    }
    if state.contains("drag-") {
      configureRecordDragCapture(state, board: board, conversation: conversation)
      return
    }
    if state.hasPrefix("reference-") {
      configureWorldReferenceCapture(state, board: board, conversation: conversation)
      return
    }
    if state == "proposal-faction-batch" {
      configureFactionBatchCapture(board: board, conversation: conversation)
      return
    }
    if ["request-pins", "request-pins-browser"].contains(state) {
      configureRequestPinsCapture(state, board: board, conversation: conversation)
      return
    }
    if state == "context-exclusions" {
      configureContextExclusionCapture(board: board, conversation: conversation)
      return
    }
    if state == "context-submitted" {
      configureSubmittedContextCapture(board: board, conversation: conversation)
      return
    }
    if Self.bidirectionalRelationshipCaptureStates.contains(state) {
      configureBidirectionalRelationshipCapture(state, board: board, conversation: conversation)
      return
    }
    if Self.relationshipMetadataCaptureStates.contains(state) {
      configureRelationshipMetadataCapture(state, board: board, conversation: conversation)
      return
    }
    if Self.chronologyHierarchyCaptureStates.contains(state) {
      configureChronologyHierarchyCapture(state, board: board, conversation: conversation)
      return
    }
    if Self.entityNamesCaptureStates.contains(state) {
      configureEntityNamesCapture(state, board: board, conversation: conversation)
      return
    }
    if state.contains("split-") {
      configureSplitCapture(state, board: board, conversation: conversation)
      return
    }
    if splitRecord != nil { closeSplitWorkspace() }
    if state.contains("changes-") {
      configureActivityCapture(state, board: board, conversation: conversation)
      return
    }
    if state.contains("favorites-") {
      configureConnectedCapture("library", board: board, conversation: conversation)
      dark = !state.hasPrefix("light-")
      if state.hasPrefix("manual-") { setMode(.manual) }
      restoreSidebarDefaults()
      if state != "favorites-empty" {
        for title in ["Mira Vale", "The Glass Sea", "Crossing the Glass Sea"] {
          if let record = records.first(where: { $0.title == title }) {
            setFavorite(record, enabled: true)
          }
        }
        pinSidebarCategory("Places", pinned: true)
      }
      if state.hasSuffix("editor"), let record = favoriteRecords.first { openRecord(record) }
      if state == "favorites-inspector", let record = favoriteRecords.first {
        inspect(.record(record.id))
      }
      if state.hasSuffix("options") || state == "favorites-empty" { sheet = .navigation }
      if state == "favorites-rail" { collapsed = true }
      if state == "favorites-collection" { openLens("Places") }
      if state == "favorites-long" {
        perform {
          let title = "A traveller's guide to the vanished settlements of the western archipelago"
          let record =
            try records.first(where: { $0.title == title })
            ?? store.createRecord(worldID: worldID, title: title, kind: "lore")
          try reload()
          setFavorite(record, enabled: true)
          moveFavorite(record, by: -3)
          openRecord(record)
        }
      }
      captureHint = state
      return
    }
    if state.contains("navigation-") {
      configureConnectedCapture("library", board: board, conversation: conversation)
      dark = !state.hasPrefix("light-")
      if state.hasPrefix("manual-") { setMode(.manual) }
      restoreSidebarDefaults()
      if state != "navigation-default" {
        updateSidebarConfiguration {
          $0.sectionOrder = ["favorites", "world", "workspace", "explore", "conversations"]
          $0.pinnedCategories = ["Characters", "Places"]
          $0.hiddenCategories = ["Cosmology", "Power systems"]
        }
      }
      if state == "navigation-long" {
        perform {
          let category = "Orders of the Uncharted Western Archipelago and the Outer Reaches"
          if !records.contains(where: { $0.category == category }) {
            _ = try store.createRecord(
              worldID: worldID, title: "The Last Cartographers", kind: "entity", category: category)
            try reload()
          }
          pinSidebarCategory(category, pinned: true)
        }
      }
      if state == "navigation-empty" {
        updateSidebarConfiguration {
          $0.hiddenCategories = sidebarCategories
          $0.pinnedCategories = []
        }
      }
      if state.hasSuffix("options") { sheet = .navigation }
      if state.hasSuffix("categories") { sheet = .navigation }
      if state == "navigation-settings" {
        navigate(.settings)
        settingsQuery = "navigation content"
      }
      if state == "navigation-error" {
        perform { try store.setPreference("navigation:\(worldID)", value: "unreadable fixture") }
        refreshSidebarConfiguration()
        sheet = .navigation
      }
      if state == "navigation-rail" { collapsed = true }
      captureHint = state
      return
    }
    if state.contains("search-") {
      let library = state.contains("library")
      configureConnectedCapture(
        library ? "library" : "palette", board: board, conversation: conversation)
      dark = !state.hasPrefix("light-")
      if state.hasPrefix("manual-") { setMode(.manual) }
      var query = "type:character faction:Tidekeepers"
      if state == "search-canon" {
        perform {
          if let record = records.first(where: { $0.title == "Mira Vale" }), record.state != "canon"
          {
            _ = try store.promote(
              worldID: worldID, id: record.id, version: record.version, confirmation: record.id)
            try reload()
          }
        }
        query = "status:canon updated:7d"
      } else if state == "search-quoted" {
        query = "type:character related:\"The Glass Sea\""
      } else if state == "search-invalid" || state == "search-library-error" {
        query = "status:approved updated:7d"
      } else if state == "search-no-results" {
        query = "type:character faction:Unknown"
      }
      if library { libraryQuery = query } else { paletteQuery = query }
      captureHint = state
      return
    }
    if state.contains("palette-") {
      configureConnectedCapture("palette", board: board, conversation: conversation)
      dark = !state.hasPrefix("light-")
      if state.hasPrefix("manual-") { setMode(.manual) }
      let kind = state.components(separatedBy: "-").last ?? ""
      let queries = [
        "search": "Mira", "body": "coastline", "maps": "maps", "scenes": "scenes",
        "settings": "spelling",
        "tools": "power systems", "recent": "recent changes", "long": "Unfinished Charts",
        "unmatched": "the sea remembers names",
      ]
      if kind == "scenes" || kind == "long" {
        perform {
          let title =
            kind == "scenes"
            ? "The ferryman's bargain"
            : "Mira Vale, Keeper of the Unfinished Charts of the Western Glass Sea"
          if !records.contains(where: { $0.title == title }) {
            _ = try store.createRecord(
              worldID: worldID, title: title,
              body: "A quiet negotiation at the edge of the crossing.", kind: "lore",
              category: "Scenes")
            try reload()
          }
        }
      }
      paletteQuery = queries[kind] ?? ""
      captureHint = state
      return
    }
    if state.contains("selection-") {
      let bases = [
        "graph": "graph-selected", "canvas": "canvas", "atlas": "atlas",
        "regions": "atlas-regions", "library": "inspector-library", "timeline": "inspector-event",
      ]
      let kind = state.components(separatedBy: "-").last ?? ""
      if let base = bases[kind] {
        configureConnectedCapture(base, board: board, conversation: conversation)
        dark = !state.hasPrefix("light-")
        if state.hasPrefix("manual-") { setMode(.manual) }
        if kind == "atlas" { atlasSelectedID = records.first { $0.title == "The Glass Sea" }?.id }
      }
      return
    }
    if state.contains("panels-") {
      let base =
        state == "panels-inspector-wide"
        ? "inspector-graph"
        : state == "panels-companion-wide"
          ? "graph-companion"
          : state == "panels-canvas-companion"
            ? "companion"
            : state == "panels-settings" ? "settings" : "editor"
      configureConnectedCapture(base, board: board, conversation: conversation)
      sidebarWidth =
        state == "panels-narrow" || state == "panels-canvas-companion"
        ? 240 : (state.contains("wide") ? 360 : Double(Metric.sidebar))
      inspectorWidth = state == "panels-narrow" ? 260 : (state.contains("wide") ? 480 : 300)
      companionWidth = state.contains("companion") ? 600 : 400
      collapsed = state == "panels-collapsed"
      if state.hasPrefix("manual-") { setMode(.manual) }
      dark = !state.hasPrefix("light-")
      captureHint = state
      return
    }
    if state.contains("status-save") {
      configureConnectedCapture("editor", board: board, conversation: conversation)
      dark = !state.hasPrefix("light-")
      captureHint = state
      return
    }
    if state.contains("status-review") {
      configureConnectedCapture("review", board: board, conversation: conversation)
      perform {
        for old in try store.proposals(worldID: worldID) where old.summary == "Coastal expedition" {
          for change in old.changes where change.status == "pending" {
            _ = try store.resolveChange(
              worldID: worldID, proposalID: old.id, changeID: change.id,
              accept: false, confirmation: old.id)
          }
        }
        let source = try store.createRecord(
          worldID: worldID, title: "Expedition route", body: "Along the coast")
        guard
          let proposal = try store.stageProposal(
            worldID: worldID, conversationID: nil, messageID: nil,
            payload: [
              "summary": "Coastal expedition",
              "changes": [
                [
                  "action": "create_record", "title": "Expedition supplies",
                  "body": "Charts and dry stores",
                ],
                [
                  "action": "revise_record", "id": source.id, "body": "Following the eastern coast",
                ],
                ["action": "add_event", "title": "Expedition departure", "source": source.id],
              ],
            ])
        else { return }
        var progress = ReviewProgress(
          worldID: worldID, proposalID: proposal.id, accept: true,
          total: proposal.changes.count, summary: proposal.summary)
        _ = try store.resolveChange(
          worldID: worldID, proposalID: proposal.id,
          changeID: proposal.changes[0].id, accept: true, confirmation: proposal.id)
        progress.completed = 1
        progress.phase = .running
        progress.detail = "Canon is unchanged."
        if state.hasSuffix("complete") {
          for change in proposal.changes.dropFirst() {
            _ = try store.resolveChange(
              worldID: worldID, proposalID: proposal.id, changeID: change.id,
              accept: true, confirmation: proposal.id)
            progress.completed += 1
          }
          progress.phase = .complete
        } else if state.hasSuffix("failed") {
          _ = try store.saveRecord(
            worldID: worldID, id: source.id, version: source.version,
            title: source.title, body: "A newly discovered route", rtf: nil)
          do {
            _ = try store.resolveChange(
              worldID: worldID, proposalID: proposal.id,
              changeID: proposal.changes[1].id, accept: true, confirmation: proposal.id)
          } catch {
            progress.phase = .failed
            progress.detail = error.localizedDescription
          }
        }
        try reload()
        reviewProgress = progress
        reviewingProposal = progress.phase == .running
      }
      dark = !state.hasPrefix("light-")
      captureHint = state
      return
    }
    if state.contains("status-simulate") || state == "status-agent-failed" {
      configureConnectedCapture("conversation-loading", board: board, conversation: conversation)
      if state.contains("simulate") { preset = "Simulate" }
      activity[1].title =
        state == "status-agent-failed" ? "Assistant unavailable" : "Exploring hypothetical outcomes"
      activity[1].detail =
        state == "status-agent-failed"
        ? "The subscription connection ended. Your message is saved."
        : "AI exploration with assumptions, not a deterministic simulation. Nothing becomes canon."
      activity[1].state = state == "status-agent-failed" ? .failed : .running
      activity[1].startedAt = Date().addingTimeInterval(-25)
      if state == "status-agent-failed" {
        activity[1].endedAt = Date()
        busy = false
      }
      dark = !state.hasPrefix("light-")
      captureHint = state
      return
    }
    if state.contains("scroll-regions") {
      configureConnectedCapture("library", board: board, conversation: conversation)
      perform {
        guard var mira = records.first(where: { $0.title == "Mira Vale" }) else { return }
        let body = (1...80).map {
          "Crossing \($0). Mira follows the shoreline, comparing the new chart with the accounts in the tide ledgers. What changed since her last visit remains an open question."
        }.joined(separator: "\n\n")
        if mira.body != body {
          mira = try store.saveRecord(
            worldID: worldID, id: mira.id, version: mira.version,
            title: mira.title, body: body, rtf: nil)
        }
        for index in 1...24 {
          let name = "Crossing witness \(index)"
          if !records.contains(where: { $0.title == name }) {
            let record = try store.createRecord(
              worldID: worldID, title: name, kind: "entity", category: "Characters")
            _ = try store.addRelation(
              worldID: worldID, source: mira.id, target: record.id, label: "interviewed")
          }
          if !conversations.contains(where: { $0.title == name }) {
            _ = try store.createConversation(worldID: worldID, title: name)
          }
        }
        preferences.recentChats = 30
        try reload()
        openRecord(mira)
      }
      inspector = true
      dark = !state.hasPrefix("light-")
      if state.hasPrefix("manual-") { setMode(.manual) }
      toast = nil
      captureHint = state
      return
    }
    if state.contains("document-tabs") {
      configureConnectedCapture("library", board: board, conversation: conversation)
      for id in documentSession.open { closeDocument(id) }
      for title in ["Mira Vale", "Tidekeepers", "The Glass Sea"] {
        if let record = records.first(where: { $0.title == title }) { openRecord(record) }
      }
      if let mira = records.first(where: { $0.title == "Mira Vale" }) {
        toggleDocumentPin(mira.id)
        if state == "document-tabs-many" {
          for record in topLevelRecords { openRecord(record) }
          perform {
            let long = try store.createRecord(
              worldID: worldID,
              title: "The annotated accounts of every crossing before the final remembering tide",
              body: "Comparing the maps and crossing accounts.")
            try reload()
            openRecord(long)
          }
        } else {
          openRecord(mira)
        }
        if state == "document-tabs-sections" { recordTabs[mira.id] = .sections }
      }
      if state == "document-tabs-reopened" {
        closeActiveDocument()
        reopenDocument()
      }
      inspector = false
      dark = !state.hasPrefix("light-")
      if state.hasPrefix("manual-") { setMode(.manual) }
      toast = nil
      captureHint = state
      return
    }
    if state.contains("graph-zoom-") {
      configureConnectedCapture("graph", board: board, conversation: conversation)
      perform {
        if let mira = records.first(where: { $0.title == "Mira Vale" }),
          try store.recordArtwork(worldID: worldID, recordID: mira.id) == nil,
          let image = StudioArtwork.cartographer.data
        {
          _ = try store.saveRecordArtwork(
            worldID: worldID, recordID: mira.id, data: image,
            origin: "ai-generated", expectedID: nil)
        }
        try reload()
      }
      dark = !state.hasPrefix("light-")
      if state.hasPrefix("manual-") { setMode(.manual) }
      captureHint = state
      return
    }
    if state.contains("dashboard") {
      configureConnectedCapture(
        state == "dashboard-empty" ? "empty-library" : "library", board: board,
        conversation: conversation)
      navigate(.dashboard)
      if state != "dashboard-empty" {
        perform {
          _ = try store.renameWorld(worldID, name: "Aster")
          if dashboardProjects.isEmpty {
            let project = try store.createProject(worldID: worldID, title: "The first crossing")
            _ = try store.saveRecord(
              worldID: worldID, id: project.id, version: project.version, title: project.title,
              body: "A story about the coast that remembers, and the mapmaker who cannot.", rtf: nil
            )
            _ = try store.createRecordSection(
              worldID: worldID, parentID: project.id,
              title: "Opening scene", body: "Mira reaches the shore before the next crossing.")
          }
          try reload()
        }
      }
      if state == "dashboard-project", let project = dashboardProjects.first { openRecord(project) }
      if state == "dashboard-review", let proposal = pendingProposals.last {
        openProposalReview(proposal.id)
      }
      if state == "dashboard-long" {
        perform {
          _ = try store.renameWorld(
            worldID,
            name: "Aster and the remembered kingdoms beyond the farthest eastern coast")
          try reload()
        }
      }
      dark = !state.hasPrefix("light-")
      if state.hasPrefix("manual-") { setMode(.manual) }
      sheet = state == "dashboard-new-project" ? .project : nil
      toast = nil
      captureHint = state
      return
    }
    if state.contains("layouts") {
      configureConnectedCapture(
        state == "layouts-empty" ? "empty-library" : "library", board: board,
        conversation: conversation)
      perform {
        try store.setPreference(
          "workspace-layouts:\(worldID)", value: "{\"version\":1,\"layouts\":[]}")
        if state != "layouts-empty" {
          navigate(.knowledge)
          graphSelectedID = records.first { $0.title == "Mira Vale" }?.id
          workspaceInspector = true
          let research = try saveLayout(name: "Research")
          if let mira = records.first(where: { $0.title == "Mira Vale" }) {
            openRecord(mira)
            collapsed = true
            inspector = false
            preferences.density = .immersive
            preferences.readingWidth = 640
            recordTabs[mira.id] = .sections
          }
          let writing = try saveLayout(name: "Writing")
          collapsed = false
          preferences.density = .comfortable
          preferences.readingWidth = 780
          if let map = contextBoards.first(where: { $0.kind == "atlas" }) {
            openBoard(map.id, kind: "atlas")
          }
          try saveLayout(name: "Cartography")
          if let power = records.first(where: { $0.title == "The art of remembrance" }) {
            openRecord(power)
            recordTabs[power.id] = .mechanics
            inspector = true
          }
          try saveLayout(name: "Simulation")
          if state == "layouts-archived" { try archiveLayout(research.id) }
          if state == "layouts-many" {
            for i in 1...16 {
              try saveLayout(
                name: "\(i). Eastern Crossing — research into the years before the tide returned")
            }
          }
          navigate(.library)
          workspaceInspector = false
          if state.hasSuffix("-applied") { _ = applyLayout(writing.id) }
        }
      }
      if state.hasPrefix("manual-") { setMode(.manual) }
      dark = !state.hasPrefix("light-")
      sheet = state.hasSuffix("-applied") ? nil : .layouts
      toast = nil
      captureHint = state
      return
    }
    if state.contains("history-trail") || state.contains("history-back")
      || state.contains("history-map")
    {
      configureConnectedCapture("library", board: board, conversation: conversation)
      navigationBack = []
      navigationForward = []
      inspector = false
      dark = !state.hasPrefix("light-")
      if state.hasPrefix("manual-") { setMode(.manual) }
      if state.hasPrefix("collapsed-") { collapsed = true }
      for title in ["Mira Vale", "Tidekeepers", "The Glass Sea"] {
        if let record = records.first(where: { $0.title == title }) { openRecord(record) }
      }
      if state.contains("history-back") { goBack() }
      if state.contains("history-map"), let map = contextBoards.first(where: { $0.kind == "atlas" })
      {
        openBoard(map.id, kind: "atlas")
      }
      captureHint = state
      return
    }
    let inspectorStates = [
      "inspector-library": "library", "light-inspector-library": "light-library",
      "manual-inspector-library": "library", "inspector-graph": "graph",
      "inspector-canvas": "canvas", "inspector-atlas": "atlas",
      "light-inspector-atlas": "atlas", "inspector-event": "timeline",
      "inspector-lane": "timeline", "inspector-conversation": "conversation",
      "inspector-review": "review", "inspector-worlds": "worlds",
      "inspector-settings": "settings", "inspector-empty": "empty-library",
      "inspector-hidden": "library", "inspector-mechanics": "mechanics",
    ]
    if let base = inspectorStates[state] {
      configureConnectedCapture(base, board: board, conversation: conversation)
      workspaceInspector = state != "inspector-hidden"
      if state == "inspector-mechanics" { inspector = true }
      dark = !state.hasPrefix("light-")
      if state.hasPrefix("manual-") { setMode(.manual) }
      if state.hasSuffix("-library"), let record = records.first(where: { $0.title == "Mira Vale" })
      {
        inspectionTarget = .record(record.id)
      }
      if state == "inspector-graph" {
        graphSelectedID = records.first { $0.title == "Mira Vale" }?.id
      }
      if state == "inspector-event", let event = try? store.events(worldID: worldID).first {
        inspectionTarget = .event(event.id)
      }
      if state == "inspector-lane", let lane = try? store.chronologyLanes(worldID: worldID).first {
        inspectionTarget = .lane(lane.id)
      }
      // Preserve Mechanics' existing on-appear fixture selection.
      if state != "inspector-mechanics" { captureHint = state }
      return
    }
    _ = flushEditor()
    editorSave = nil
    let stress = state.contains("sidebar-long") || state == "sidebar-history"
    let wanted = worlds.first {
      if stress { return $0.name.hasPrefix("Aster — chronicles") }
      return state.hasPrefix("empty-") ? $0.name == "Halcyon" : $0.demo
    }
    if let wanted, wanted.id != worldID { switchWorld(wanted.id) }
    let board = state.hasPrefix("empty-") || stress ? "" : board
    let conversation = state.hasPrefix("empty-") || stress ? nil : Optional(conversation)
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
    if state.hasPrefix("oled-") { updatePreferences { $0.darkPalette = .oled } }
    refreshProviderAvailability()
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
    recordTabs = [:]
    selectedRecord = nil
    graphSelectedID = nil
    graphView = GraphViewState()
    timelineView = TimelineViewState()
    atlasSelectedID = nil
    timelineLaneID = nil
    palette = false
    sheet = nil
    toast = nil
    reviewProgress = nil
    reviewSection = nil
    reviewFocusID = nil
    reviewingProposal = false
    stop()
    setMode(state.hasPrefix("manual") ? .manual : .assisted)
    dark = !state.hasPrefix("light")
    updatePreferences {
      $0.density =
        state.contains("compact-")
        ? .compact
        : state.contains("immersive-") ? .immersive : .comfortable
    }
    collapsed = ["collapsed", "light-collapsed", "settings-collapsed"].contains(state)
    inspector = true
    workspaceInspector = false
    inspectionTarget = nil
    navigationBack = []
    navigationForward = []
    libraryCategory = nil
    libraryQuery = ""
    libraryFilter = .all
    libraryOrder = .recent
    restoreSidebarDefaults()
    canvasBoardID = board.isEmpty ? nil : board
    companionExpanded = state.hasSuffix("-companion") || state == "companion"
    companionWidth = 400
    sidebarWidth = Double(Metric.sidebar)
    inspectorWidth = 300
    draft = ""
    preset = "Create"
    updateContext { $0 = AssistantContextOptions() }
    conversationID = state.hasSuffix("conversation-home") ? nil : conversation
    perform { try reload() }
    let viewState = state.replacingOccurrences(of: "oled-", with: "")
      .replacingOccurrences(of: "opaque-", with: "")
      .replacingOccurrences(of: "compact-", with: "")
      .replacingOccurrences(of: "immersive-", with: "")
    switch viewState {
    case let state where CanvasReferencePicker.captureStates.contains(state):
      destination = .canvas
    case "composer-attached", "light-composer-attached", "composer-context",
      "light-composer-context",
      "composer-browser", "composer-overflow", "composer-expanded",
      "composer-companion", "light-composer-companion", "composer-command-return",
      "composer-unavailable":
      destination = state.hasSuffix("-companion") ? .library : .chat
      conversationID = nil
      draft = "What changes if the Glass Sea begins freezing?"
      if state == "composer-command-return" {
        updatePreferences { $0.sendShortcut = .commandEnter }
        draft +=
          "\n\nExplore what this means for the Tidekeepers and Mira. Keep the cause open; we have not established it yet."
      }
      perform {
        var lane = try store.chronologyLanes(worldID: worldID).first { $0.name == "Year 60" }
        if lane == nil {
          lane = try store.createChronologyLane(
            worldID: worldID, name: "Year 60", kind: "period", start: "Year 60")
        }
        updateContext {
          $0.intent = .explore
          $0.recordIDs = records.filter { ["The Glass Sea", "Tidekeepers"].contains($0.title) }.map(
            \.id)
          $0.laneIDs = lane.map { [$0.id] } ?? []
          if state.hasSuffix("composer-context") { $0.scope = .attachments }
          if state == "composer-overflow" {
            $0.recordIDs = Array(records.prefix(12).map(\.id))
            $0.boardIDs = contextBoards.map(\.id)
          }
        }
        try reload()
      }
    case "conversation-interrupted":
      destination = .chat
      perform {
        let chat = try store.createConversation(worldID: worldID, title: "An interrupted crossing")
        conversationID = chat.id
        _ = try store.appendMessage(
          worldID: worldID, conversationID: chat.id, role: "user",
          body: "Explore a different route across the Glass Sea.", state: "complete")
        _ = try store.appendMessage(
          worldID: worldID, conversationID: chat.id, role: "assistant",
          body:
            "A northern passage could let Mira avoid the tide ledgers. The cost of that route is still an open question.",
          state: "interrupted")
        _ = try store.appendMessage(
          worldID: worldID, conversationID: chat.id, role: "system",
          body:
            "The connection ended before the reply was complete. Your conversation has been saved.",
          state: "error")
        try reload()
      }
    case "review-edits":
      destination = .review
      perform {
        let lane = try store.createChronologyLane(
          worldID: worldID, name: "Early crossings", kind: "period")
        let event = try store.saveChronologyEvent(
          worldID: worldID, id: nil,
          title: "The first crossing", date: "Before the ledgers", source: nil, order: nil,
          laneID: nil)
        guard let map = try store.boards(worldID: worldID, kind: "atlas").first else { return }
        _ = try store.stageProposal(
          worldID: worldID, conversationID: nil, messageID: nil,
          payload: [
            "summary": "Refine the crossing history and its map · authored capture example",
            "changes": [
              [
                "action": "revise_event", "id": event.id, "title": "The first remembered crossing",
                "lane": lane.id,
              ],
              [
                "action": "revise_lane", "id": lane.id, "title": "The Age of Glass",
                "date": "Year 12", "body": "The tide ledgers begin here.",
              ],
              ["action": "revise_map", "id": map.id, "title": "Crossings of the Glass Sea"],
            ],
          ])
        try reload()
      }
    case "sidebar-long", "light-sidebar-long", "sidebar-history", "empty-sidebar":
      destination = .chat
      conversationID = nil
      if state == "sidebar-history", let recent = conversations.first {
        openChat(recent)
      }
    case "sidebar-folded", "sidebar-opaque", "light-sidebar-opaque":
      destination = .knowledge
    case "mechanics", "light-mechanics", "manual-mechanics", "mechanics-empty",
      "mechanics-scenario", "mechanics-review", "mechanics-history", "mechanics-tree",
      "mechanics-requires":
      destination = .library
      inspector = false
      selectedRecord = records.first {
        $0.title == (state == "mechanics-empty" ? "Oren Ashe" : "The art of remembrance")
      }
      if let record = selectedRecord, state != "mechanics-empty",
        (try? store.rules(worldID: worldID, systemID: record.id).isEmpty) == true
      {
        let examples: [(WorldRule.Kind, String, String)] = [
          (
            .source, "A memory freely offered",
            "Remembrance begins with an echo willingly entrusted to the tide."
          ),
          (
            .cost, "The price of a crossing",
            "One memory of your own is surrendered for each borrowed skill."
          ),
          (
            .limit, "The past remains",
            "A borrowed life can be witnessed. Its events cannot be changed."
          ),
          (
            .technique, "A cartographer’s recall",
            "Trace a coastline as its original witness saw it, for the span of one tide."
          ),
        ]
        for example in examples {
          _ = try? store.addRule(
            worldID: worldID, systemID: record.id, kind: example.0, title: example.1,
            body: example.2)
        }
        // A small tree: one step, two techniques built on the recall, one built on both.
        let tree: [(WorldRule.Kind, String, String)] = [
          (.progression, "First surrender", "Give up one memory and feel its absence settle."),
          (.technique, "Borrowed hands", "Use a stranger's practised skill for a single task."),
          (.technique, "Tide sight", "See a place as it stood on the day it was remembered."),
          (
            .technique, "The drowned chart",
            "Map a coastline that no longer exists, from every witness at once."
          ),
        ]
        let created = tree.compactMap {
          try? store.addRule(
            worldID: worldID, systemID: record.id, kind: $0.0, title: $0.1, body: $0.2)
        }
        if created.count == 4,
          let recall = try? store.rules(worldID: worldID, systemID: record.id).first(where: {
            $0.title == "A cartographer’s recall"
          })
        {
          try? store.setPrerequisites(
            worldID: worldID, ruleID: recall.id, requires: [created[0].id])
          try? store.setPrerequisites(
            worldID: worldID, ruleID: created[1].id, requires: [created[0].id])
          try? store.setPrerequisites(
            worldID: worldID, ruleID: created[2].id, requires: [recall.id])
          try? store.setPrerequisites(
            worldID: worldID, ruleID: created[3].id, requires: [recall.id, created[2].id])
        }
        _ = try? store.saveScenario(
          worldID: worldID, systemID: record.id, title: "Cross without forgetting her sister",
          situation:
            "Mira offers the memory of her first map instead. Does the tide accept a memory chosen by the traveller?",
          expectation: "unclear")
      }
      if ["mechanics-review", "mechanics-history"].contains(state), let record = selectedRecord,
        let cost = try? store.rules(worldID: worldID, systemID: record.id).first(where: {
          $0.kind == .cost
        }), cost.accepted == nil
      {
        _ = try? store.promoteRule(worldID: worldID, id: cost.id, confirmation: cost.id)
        _ = try? store.updateRule(
          worldID: worldID, id: cost.id, kind: .cost, title: cost.title,
          body:
            "One memory of your own is surrendered for each borrowed skill. The traveller chooses which memory to offer."
        )
      }
    case "components", "component-new", "light-components", "manual-components", "components-empty",
      "entity-components":
      destination = state == "entity-components" ? .library : .timeline
      inspector = false
      if state == "entity-components" {
        selectedRecord = records.first { $0.title == "The art of remembrance" }
        if let id = selectedRecord?.id { recordTabs[id] = .sections }
      }
      let scope: CreativeScope = state == "entity-components" ? .entity : .timeline
      let parent = state == "entity-components" ? selectedRecord?.id : nil
      if state != "components-empty" {
        let examples: [(CreativeKind, String, String)] = [
          (
            .facts, "The price of remembrance",
            "Source: A memory freely offered\nCost: One memory of your own\nLimit: A borrowed life cannot be changed"
          ),
          (
            .checklist, "Questions for the next crossing",
            "- [x] Locate the drowned observatory\n- [ ] Decide what Mira refuses to forget\n- [ ] Trace the Tidekeepers’ disputed account"
          ),
          (
            .progression, "Paths of practice",
            "Listener — recognize the echo of a borrowed memory\nKeeper — carry a skill through one tide\nWitness — retain the cost without changing the past"
          ),
          (
            .notes, "Keep the contradiction open",
            "Two charts place the observatory on opposite shores. Both are drafts; the next scene can explore what each cartographer chose to remember."
          ),
        ]
        if (try? store.creativeComponents(worldID: worldID).contains {
          $0.scope == scope && $0.parentID == parent
        }) != true {
          for example in examples {
            _ = try? store.createCreativeComponent(
              worldID: worldID, scope: scope, kind: example.0, parentID: parent, title: example.1,
              body: example.2)
          }
          try? reload()
        }
      } else {
        destination = .atlas
      }
      if state != "entity-components" { sheet = .components }
    case "conversation-loading":
      destination = .chat
      busy = true
      activity = [
        AgentActivity(
          id: "lore", title: "World context ready",
          detail: "3 sample records · isolated capture data", state: .complete,
          startedAt: Date(timeIntervalSince1970: 0), endedAt: Date(timeIntervalSince1970: 0.1)),
        AgentActivity(
          id: "response", title: "Waiting for your assistant",
          detail: "Loading-state fixture · no provider request", state: .running),
      ]
    case "conversation-home", "light-conversation-home", "conversation", "light-conversation",
      "manual-conversation",
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
    case "graph", "graph-selected", "light-graph", "sheet-relation", "empty-graph",
      "graph-companion":
      destination = .knowledge
    case "graph-neighbourhood-one", "graph-neighbourhood-two":
      destination = .knowledge
      if let root = records.first(where: { $0.title == "Mira Vale" }) {
        graphSelectedID = root.id
        graphView.neighborhood = GraphNeighborhood(
          rootID: root.id, depth: state.hasSuffix("one") ? 1 : 2)
      }
    case "review", "review-canon", "review-checks": destination = .review
    case "timeline", "empty-timeline", "timeline-edit", "timeline-companion", "timeline-compact",
      "timeline-overview":
      destination = .timeline
      if state != "empty-timeline" {
        perform {
          if try store.chronologyLanes(worldID: worldID).isEmpty {
            let branch = try store.createChronologyLane(
              worldID: worldID, name: "The Eastern Crossing", kind: "branch")
            let period = try store.createChronologyLane(
              worldID: worldID, name: "Age of Glass", kind: "period", parentID: branch.id)
            _ = try store.saveChronologyEvent(
              worldID: worldID, id: nil, title: "The first charts", date: "Year 12", source: nil,
              order: nil, laneID: period.id)
            let tides = try store.createChronologyLane(
              worldID: worldID, name: "The Long Tide", kind: "period")
            for (title, date) in [
              ("The ledger is sealed", "Year 40"), ("Oren's crossing", "Year 52"),
              ("The lamps go dark", "Year 61"),
            ] {
              _ = try store.saveChronologyEvent(
                worldID: worldID, id: nil, title: title, date: date, source: nil, order: nil,
                laneID: tides.id)
            }
            try reload()
          }
        }
      }
    case "atlas-linked", "light-atlas-linked", "manual-atlas-linked", "atlas-details", "atlas-new",
      "atlas-local", "atlas-companion", "light-atlas-companion", "atlas-hierarchy-selected",
      "atlas-hierarchy-empty-parent":
      destination = .atlas
      perform {
        guard let original = try store.boards(worldID: worldID, kind: "atlas").first,
          let sea = records.first(where: { $0.title == "The Glass Sea" }),
          let city = records.first(where: { $0.title == "The Drowned City" })
        else { return }
        if !(try store.boards(worldID: worldID, kind: "atlas").contains {
          $0.name == "The drowned harbour"
        }) {
          var document = try JSONDecoder().decode(
            AtlasDocument.self, from: Data(original.content.utf8))
          document.placeID = sea.id
          let root = try store.saveAtlasMap(
            worldID: worldID, id: original.id, name: "The Glass Sea",
            content: String(decoding: JSONEncoder().encode(document), as: UTF8.self),
            expected: original)
          _ = try store.createAtlasMap(
            worldID: worldID, name: "The drowned harbour", placeID: city.id, parentMapID: root.id)
        }
        let maps = try store.boards(worldID: worldID, kind: "atlas")
        let harbour = maps.first { $0.name == "The drowned harbour" }
        if state == "atlas-hierarchy-empty-parent", let harbour,
          !maps.contains(where: { $0.name == "The old quays" })
        {
          _ = try store.createAtlasMap(
            worldID: worldID, name: "The old quays", parentMapID: harbour.id)
        }
        let opensChild = ["atlas-local", "atlas-hierarchy-empty-parent"].contains(state)
        mapBoardID = opensChild ? harbour?.id : original.id
      }
    case "atlas", "empty-atlas", "atlas-regions", "atlas-drawing", "atlas-placing",
      "light-atlas-drawing", "sheet-generate":
      destination = .atlas
    case "sections", "light-sections", "manual-sections", "sections-companion", "sheet-section",
      "section-editor":
      destination = .library
      inspector = false
      selectedRecord = records.first { $0.title == "Mira Vale" }
      if let id = selectedRecord?.id { recordTabs[id] = .sections }
      if state == "section-editor", let parent = selectedRecord {
        selectedRecord = try? store.recordSections(worldID: worldID, parentID: parent.id).first?
          .record
      }
    case "sections-empty":
      destination = .library
      inspector = false
      selectedRecord = records.first { $0.title == "Oren Ashe" }
      if let id = selectedRecord?.id { recordTabs[id] = .sections }
    case "what-if-new":
      destination = .library
      sheet = .whatIf
    case "what-if-send", "review-what-if", "worlds-what-if":
      if let branchID = captureWhatIf() {
        if state == "what-if-send" {
          switchWorld(branchID)
          perform { try reload() }
          destination = .library
          sheet = .sendWhatIf
        } else if state == "worlds-what-if" {
          destination = .worlds
        } else {
          perform {
            if try !store.proposals(worldID: worldID).contains(where: {
              $0.isBranchMerge && $0.pending > 0
            }) {
              try store.proposeBranchMerge(worldID: branchID)
            }
            try reload()
          }
          destination = .review
        }
      }
    case "editor-recovered":
      destination = .library
      if let record = records.first(where: { $0.title == "The Glass Sea" }) {
        // A recovery copy as a crash would leave it: typed against the saved version.
        try? store.writeJournal(
          worldID: worldID, recordID: record.id, title: record.title,
          body: record.body
            + "\n\nWhen the glass holds, the drowned lamps can be counted. Mira never counts the same number twice.",
          rtf: nil, category: record.category, baseVersion: record.version)
        selectedRecord = record
      }
    case "profile-empty", "light-profile-empty", "profile-artwork", "light-profile-artwork",
      "profile-connected", "profile-writing", "profile-event", "manual-profile-empty",
      "profile-artwork-place", "profile-artwork-banner":
      destination = .library
      inspector = false
      perform {
        let example: (name: String, category: String, art: StudioArtwork) =
          switch viewState {
          case "profile-artwork-place": ("Glasswatch Harbor", "Places", .atlas)
          case "profile-artwork-banner": ("Glasswatch Mariners", "Factions", .atlas)
          case "profile-writing": ("Rowan Vale", "Characters", .cartographer)
          case _ where viewState.hasSuffix("empty"): ("Neris Vale", "Characters", .cartographer)
          default: ("Elian Sable", "Characters", .cartographer)
          }
        var record = records.first { $0.title == example.name }
        if record == nil {
          record = try store.createRecord(
            worldID: worldID, title: example.name, kind: "entity", category: example.category)
        }
        guard var record else { return }
        if !viewState.hasSuffix("empty"),
          try store.recordArtwork(worldID: worldID, recordID: record.id) == nil,
          let image = example.art.data
        {
          _ = try store.saveRecordArtwork(
            worldID: worldID, recordID: record.id, data: image, origin: "ai-generated",
            expectedID: nil)
        }
        if viewState == "profile-connected",
          let other = records.first(where: { $0.title == "Tidekeepers" })
        {
          _ = try? store.addRelation(
            worldID: worldID, source: record.id, target: other.id, label: "learned from")
          if try store.events(worldID: worldID).allSatisfy({ $0.sourceID != record.id }) {
            _ = try store.addEvent(
              worldID: worldID, title: "The last chart returned", date: "Year 60", source: record.id
            )
          }
        }
        if viewState == "profile-writing" {
          record = try store.saveRecord(
            worldID: worldID, id: record.id, version: record.version, title: record.title,
            body:
              "Elian keeps the charts nobody else can read. On clear mornings, he takes one down to the shore and waits for its coastline to return.",
            rtf: nil)
        }
        try reload()
        selectedRecord = record
        if viewState == "profile-event" { beginEvent(for: record) }
      }
    case "editor-long", "light-editor-long":
      destination = .library
      let title = "Mira Vale, Keeper of the Unfinished Charts of the Western Glass Sea"
      if let existing = records.first(where: { $0.title == title }) {
        selectedRecord = existing
      } else {
        selectedRecord = try? store.createRecord(
          worldID: worldID, title: title,
          body: "A cartographer tracing places that do not stay still.",
          kind: "entity", category: "Characters")
        try? reload()
      }
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
    if state == "composer-unavailable" { providerConfigured = false }
    // Each ordinary fixture starts at a deterministic view. Context-restoration fixtures set
    // their framing afterward, then exercise real navigation on the mounted workspace.
    if destination == .atlas, selectedRecord == nil {
      perform {
        let maps = try store.boards(worldID: worldID, kind: "atlas")
        if let id = mapBoardID ?? maps.first?.id {
          let selected =
            state == "atlas-hierarchy-selected"
            ? records.first(where: { $0.title == "The Drowned City" })?.id : nil
          try restoreAtlasView(boardID: id, view: AtlasViewState(selectedRecordID: selected))
        }
      }
    }
    captureHint = state
    captureNonce += 1
  }

  public func captureCanvasSelection(animate: Bool = true) {
    guard ProcessInfo.processInfo.environment["SYNTHESIS_CAPTURE_DIR"] != nil,
      let record = records.first(where: { $0.title == "Mira Vale" })
    else { return }
    canvas().reveal(record, animate: animate)
  }
}
