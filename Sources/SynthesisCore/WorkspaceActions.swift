import Foundation

/// Domain-owned edits to spatial documents. The renderer is never a second lore database.
/// These operations preserve unrelated scene elements, images, viewport and archived history.
extension WorkspaceStore {
  public func board(worldID: String, id: String, kind: String) throws -> Board {
    guard let board = try boards(worldID: worldID, kind: kind).first(where: { $0.id == id }) else {
      throw SynthesisError.notFound
    }
    return board
  }
  public func placeRecord(worldID: String, boardID: String, recordID: String, x: Double, y: Double)
    throws -> Board
  {
    _ = try record(worldID: worldID, id: recordID)
    guard try !isArchived(worldID: worldID, recordID: recordID) else {
      throw SynthesisError.invalid("Restore this archived record before placing it.")
    }
    guard x.isFinite, y.isFinite, abs(x) <= 100_000, abs(y) <= 100_000 else {
      throw SynthesisError.invalid("Board positions must be finite and within 100,000 points.")
    }
    let board = try board(worldID: worldID, id: boardID, kind: "canvas")
    guard
      var object = try JSONSerialization.jsonObject(with: Data(board.content.utf8))
        as? [String: Any]
    else {
      throw SynthesisError.invalid("This board cannot be read; it was left untouched.")
    }
    if object["format"] as? String == "excalidraw" {
      var scene = object["scene"] as? [String: Any] ?? [:]
      var elements = scene["elements"] as? [[String: Any]] ?? []
      if let card = elements.first(where: {
        $0["isDeleted"] as? Bool != true
          && ($0["customData"] as? [String: Any])?["recordID"] as? String == recordID
          && ($0["customData"] as? [String: Any])?["synthesis"] as? String == "card"
      }), let group = (card["groupIds"] as? [String])?.first {
        let dx = x - (card["x"] as? Double ?? 0)
        let dy = y - (card["y"] as? Double ?? 0)
        for i in elements.indices
        where (elements[i]["groupIds"] as? [String])?.contains(group) == true {
          elements[i]["x"] = (elements[i]["x"] as? Double ?? 0) + dx
          elements[i]["y"] = (elements[i]["y"] as? Double ?? 0) + dy
          elements[i]["version"] = (elements[i]["version"] as? Int ?? 0) + 1
        }
      } else {
        let id = UUID().uuidString
        elements.append([
          "id": id, "type": "rectangle", "x": x, "y": y, "width": 300, "height": 180,
          "angle": 0, "version": 1, "isDeleted": false, "groupIds": ["record:\(id)"],
          "customData": ["synthesis": "card", "recordID": recordID],
        ])
      }
      scene["elements"] = elements
      object["scene"] = scene
    } else if object.isEmpty || object["cards"] is [[String: Any]] {
      var cards = object["cards"] as? [[String: Any]] ?? []
      if let i = cards.firstIndex(where: { $0["recordID"] as? String == recordID }) {
        cards[i]["x"] = x
        cards[i]["y"] = y
      } else {
        cards.append([
          "id": UUID().uuidString, "recordID": recordID, "text": "", "x": x, "y": y, "width": 300,
          "height": 180,
        ])
      }
      object["cards"] = cards
      if object["edges"] == nil { object["edges"] = [Any]() }
    } else {
      throw SynthesisError.invalid("Unknown board format; no content was changed.")
    }
    return try saveBoard(
      worldID: worldID, id: boardID, name: board.name, kind: "canvas",
      content: String(
        decoding: JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
        as: UTF8.self))
  }
  public func placeMapMarker(
    worldID: String, boardID: String, recordID: String, x: Double, y: Double
  ) throws -> Board {
    _ = try record(worldID: worldID, id: recordID)
    guard try !isArchived(worldID: worldID, recordID: recordID) else {
      throw SynthesisError.invalid("Restore this archived record before placing it.")
    }
    guard x.isFinite, y.isFinite, (0...1).contains(x), (0...1).contains(y) else {
      throw SynthesisError.invalid("Map coordinates must be between 0 and 1.")
    }
    let board = try board(worldID: worldID, id: boardID, kind: "atlas")
    guard
      var object = try JSONSerialization.jsonObject(with: Data(board.content.utf8))
        as? [String: Any],
      let image = object["image"] as? String, !image.isEmpty
    else {
      throw SynthesisError.invalid("Choose a map image before placing a marker.")
    }
    var markers = object["markers"] as? [[String: Any]] ?? []
    if let i = markers.firstIndex(where: { $0["recordID"] as? String == recordID }) {
      markers[i]["x"] = x
      markers[i]["y"] = y
    } else {
      markers.append(["id": UUID().uuidString, "recordID": recordID, "x": x, "y": y])
    }
    object["markers"] = markers
    return try saveBoard(
      worldID: worldID, id: boardID, name: board.name, kind: "atlas",
      content: String(
        decoding: JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
        as: UTF8.self))
  }

  /// Bounded structured context, without image bytes, credentials or foreign-world content.
  public func workspaceContext(worldID: String, boardID: String? = nil) throws -> String {
    let records = try records(worldID: worldID)
    let known = Set(records.map(\.id))
    let allBoards =
      try boards(worldID: worldID, kind: "canvas") + boards(worldID: worldID, kind: "atlas")
    let boards = allBoards.sorted { ($0.id == boardID ? 0 : 1) < ($1.id == boardID ? 0 : 1) }
      .prefix(24).map { board -> [String: Any] in
        let object =
          (try? JSONSerialization.jsonObject(with: Data(board.content.utf8))) as? [String: Any]
          ?? [:]
        let scene = object["scene"] as? [String: Any] ?? [:]
        let entries =
          (scene["elements"] as? [[String: Any]]) ?? (object["cards"] as? [[String: Any]])
          ?? (object["markers"] as? [[String: Any]]) ?? []
        let placements = entries.compactMap { entry -> [String: Any]? in
          let custom = entry["customData"] as? [String: Any]
          if object["format"] as? String == "excalidraw",
            custom?["synthesis"] as? String != "card"
          {
            return nil
          }
          guard entry["isDeleted"] as? Bool != true,
            let id = (custom?["recordID"] ?? entry["recordID"]) as? String, known.contains(id)
          else { return nil }
          return ["record": id, "x": entry["x"] ?? 0, "y": entry["y"] ?? 0]
        }
        return [
          "id": board.id, "name": board.name, "kind": board.kind, "active": board.id == boardID,
          "placements": Array(placements.prefix(80)), "totalPlacements": placements.count,
        ]
      }
    let relations = try relations(worldID: worldID)
    let events = try events(worldID: worldID)
    let object: [String: Any] = [
      "records": records.prefix(100).map {
        ["id": $0.id, "title": $0.title, "kind": $0.kind, "state": $0.state]
      },
      "relationships": relations.prefix(100).map {
        ["id": $0.id, "source": $0.sourceID, "target": $0.targetID, "label": $0.label]
      },
      "events": events.prefix(60).map {
        ["id": $0.id, "title": $0.title, "date": $0.dateLabel, "source": $0.sourceID]
      },
      "boards": boards,
      "totals": [
        "records": records.count, "relationships": relations.count, "events": events.count,
        "boards": allBoards.count,
      ],
    ]
    return String(
      decoding: try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
      as: UTF8.self)
  }
}
