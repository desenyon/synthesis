import Foundation
import SynthesisCore

extension Studio {
  /// These mutations run only through the isolated capture runner, never in a user's world.
  func configureActivityCapture(_ state: String, board: String, conversation: String) {
    if let original = try? store.preference("capture-activity-original") { switchWorld(original) }
    configureConnectedCapture("library", board: board, conversation: conversation)
    dark = !state.hasPrefix("light-")
    if state.hasPrefix("manual-") { setMode(.manual) }
    perform {
      if try store.preference("capture-activity-original") == nil {
        try store.setPreference("capture-activity-original", value: worldID)
      }
      if try store.preference("capture-activity-ready:\(worldID)") != "1" {
        if let mira = records.first(where: { $0.title == "Mira Vale" }),
          let sea = records.first(where: { $0.title == "The Glass Sea" })
        {
          let revised = try store.saveRecord(
            worldID: worldID, id: mira.id, version: mira.version, title: mira.title,
            body: mira.body + "\nHer latest survey follows the northern ice.", rtf: nil)
          _ = try store.promote(
            worldID: worldID, id: mira.id, version: revised.version, confirmation: mira.id)
          let relation = try store.addRelation(
            worldID: worldID, source: mira.id, target: sea.id, label: "surveys")
          try store.updateRelation(
            worldID: worldID, id: relation.id, label: "charts the frozen passages of")
          let period = try store.createChronologyLane(
            worldID: worldID, name: "The Long Winter", kind: "period", start: "Year 60")
          _ = try store.saveChronologyEvent(
            worldID: worldID, id: nil, title: "The first ice crossing", date: "Year 60",
            source: mira.id, order: 60, laneID: period.id)
          let map = try store.createAtlasMap(
            worldID: worldID, name: "Winter coastline", placeID: sea.id)
          _ = try store.saveBoard(
            worldID: worldID, id: map.id, name: "Frozen coastline", kind: "atlas",
            content: map.content)
        }
        let proposal = try store.stageProposal(
          worldID: worldID, conversationID: nil, messageID: nil,
          payload: [
            "summary": "A harbour on the ice",
            "changes": [
              [
                "action": "create_record", "title": "The winter harbour",
                "body": "A draft possibility for the northern coast.", "category": "Places",
              ]
            ],
          ])
        if let proposal, let change = proposal.changes.first {
          _ = try store.resolveChange(
            worldID: worldID, proposalID: proposal.id, changeID: change.id, accept: true,
            confirmation: proposal.id)
        }
        let archived = try store.createRecord(
          worldID: worldID, title: "An abandoned voyage",
          body: "An earlier direction kept for reference.")
        try store.archiveRecord(worldID: worldID, id: archived.id)
        try store.setPreference("capture-activity-ready:\(worldID)", value: "1")
      }
      if state == "changes-reconstructed" {
        if let copy = try store.preference("capture-activity-copy") {
          switchWorld(copy)
        } else {
          var archive =
            try JSONSerialization.jsonObject(with: store.exportWorldArchive(worldID: worldID))
            as! [String: Any]
          archive["version"] = 8
          var tables = archive["tables"] as! [String: Any]
          tables.removeValue(forKey: "world_activity")
          archive["tables"] = tables
          let copy = try store.importWorldArchive(JSONSerialization.data(withJSONObject: archive))
          try store.setPreference("capture-activity-copy", value: copy.id)
          switchWorld(copy.id)
        }
      }
      try reload()
    }
    if state == "changes-dashboard" {
      navigate(.dashboard)
      captureHint = "dashboard-activity"
    } else {
      sheet = .activity
      captureHint = state
    }
  }
}
