import Foundation
import SynthesisCore

extension Studio {
  static let entitySchemaCaptureStates = [
    "properties-empty", "properties-fields", "light-properties-fields", "manual-properties-fields",
    "properties-inherited", "properties-conditional", "properties-review",
    "light-properties-review",
    "properties-history", "entity-types", "light-entity-types", "entity-types-edit",
    "properties-edit-text", "properties-edit-number", "properties-edit-boolean",
    "properties-edit-date",
    "properties-edit-range", "properties-edit-duration", "properties-edit-selection",
    "properties-edit-entity",
    "properties-edit-coordinates", "properties-edit-media", "properties-edit-selections",
    "properties-edit-entities", "properties-template",
    "properties-new-entity",
  ]
  /// Uses the same store methods as creator controls, only against the isolated capture database.
  func configureEntitySchemaCapture(_ state: String, board: String, conversation: String) {
    guard ProcessInfo.processInfo.environment["SYNTHESIS_CAPTURE_DIR"] != nil else { return }
    configureConnectedCapture("editor", board: board, conversation: conversation)
    dark = !state.hasPrefix("light-")
    if state.hasPrefix("manual-") { setMode(.manual) }
    inspector = false
    workspaceInspector = false
    companionExpanded = false
    perform {
      let sea =
        try records.first { $0.title == "The Glass Sea" }
        ?? store.createRecord(
          worldID: worldID, title: "The Glass Sea", kind: "entity", category: "Places")
      let mira =
        try records.first { $0.title == "Mira Vale" }
        ?? store.createRecord(
          worldID: worldID, title: "Mira Vale",
          body: "A cartographer following the shifting coast.", kind: "entity",
          category: "Characters")
      if try store.recordArtwork(worldID: worldID, recordID: mira.id) == nil,
        let image = StudioArtwork.cartographer.data
      {
        _ = try store.saveRecordArtwork(
          worldID: worldID, recordID: mira.id, data: image, origin: "ai-generated", expectedID: nil)
      }
      let root: EntityType
      if let saved = try store.entityTypes(worldID: worldID).first(where: { $0.name == "Person" }) {
        root = saved
      } else {
        root = try store.saveEntityType(
          worldID: worldID, name: "Person",
          description: "A reusable character profile. Unknown details can stay open.",
          fields: [
            EntityField(key: "ancestry", label: "Ancestry"),
            EntityField(key: "living", label: "Living", kind: .boolean),
            EntityField(
              key: "cause", label: "Cause of death",
              condition: .init(field: "living", equals: .boolean(false))),
            EntityField(key: "home", label: "Home waters", kind: .entity),
            EntityField(key: "strength", label: "Resolve", kind: .number),
            EntityField(
              key: "rank", label: "Guild standing", kind: .selection,
              options: ["Apprentice", "Navigator", "Keeper"]),
          ],
          defaults: [
            "ancestry": .text("Descendants of the first crossing"), "living": .boolean(true),
            "home": .entity(sea.id), "strength": .number(7), "rank": .selection("Navigator"),
          ])
      }
      let child: EntityType
      if let saved = try store.entityTypes(worldID: worldID).first(where: {
        $0.name == "Tide navigator"
      }) {
        child = saved
      } else {
        child = try store.saveEntityType(
          worldID: worldID, name: "Tide navigator",
          description:
            "The sea is a place and a discipline. This profile inherits the Person fields.",
          parentTypeID: root.id,
          fields: [
            EntityField(
              key: "languages", label: "Languages", kind: .selections,
              options: ["Coastal", "High speech", "Old tide"]),
            EntityField(key: "affiliations", label: "Affiliations", kind: .entities),
            EntityField(key: "born", label: "First voyage", kind: .date),
            EntityField(key: "range", label: "Voyage range", kind: .range),
            EntityField(key: "training", label: "Training", kind: .duration),
            EntityField(key: "position", label: "Current position", kind: .coordinates),
            EntityField(key: "portrait", label: "Visual reference", kind: .media),
            EntityField(
              key: "capacity", label: "Crossing capacity", kind: .formula,
              formula: "strength * 2 + 3"),
          ],
          defaults: [
            "languages": .selections(["Coastal", "Old tide"]), "affiliations": .entities([sea.id]),
            "strength": .number(9), "born": .date("Year 42 · the turning tide"),
            "range": .range(12, 80), "training": .duration(6, "seasons"),
            "position": .coordinates(18, -4, "Glass Sea chart"),
          ])
      }
      if try store.entityTemplates(worldID: worldID).isEmpty {
        _ = try store.saveEntityTemplate(
          worldID: worldID, typeID: child.id, name: "Coastal wayfinder",
          description: "Start a navigator's profile with room for a route and a motive.",
          body: "## Route\n\n## What draws them onward\n",
          values: ["rank": .selection("Apprentice")])
      }
      if state == "properties-empty" {
        let blank =
          try records.first { $0.title == "A name still taking shape" }
          ?? store.createRecord(
            worldID: worldID, title: "A name still taking shape", kind: "entity")
        try reload()
        openRecord(blank)
        recordTabs[blank.id] = .properties
      } else if state == "properties-new-entity" {
        try reload()
        newRecordKind = "entity"
        sheet = .document
      } else {
        let current = try store.entityProfile(worldID: worldID, recordID: mira.id)
        var values: [String: EntityValue] = [
          "living": .boolean(state == "properties-conditional" ? false : true),
          "cause": .text("Lost during the last winter crossing"), "strength": .number(12),
        ]
        if let art = try store.recordArtwork(worldID: worldID, recordID: mira.id) {
          values["portrait"] = .media(
            name: "Mira — coastal study.png", mime: art.mimeType, base64: art.image)
        }
        _ = try store.saveEntityProfile(
          worldID: worldID, recordID: mira.id, typeID: child.id, values: values,
          expectedVersion: current?.version)
        try reload()
        openRecord(mira)
        recordTabs[mira.id] = .properties
      }
    }
    captureHint = state
  }
}
