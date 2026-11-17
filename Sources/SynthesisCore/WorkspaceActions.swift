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
    return try saveAtlasMap(
      worldID: worldID, id: boardID, name: board.name,
      content: String(
        decoding: JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
        as: UTF8.self), expected: board)
  }

  /// Bounded structured context, without image bytes, credentials or foreign-world content.
  public func workspaceContext(
    worldID: String, boardID: String? = nil, chronologyLaneID: String? = nil,
    allowedRecordIDs: Set<String>? = nil, includedBoardIDs: Set<String>? = nil,
    includedLaneIDs: Set<String>? = nil, preferredBoardIDs: Set<String> = [],
    preferredLaneIDs: Set<String> = []
  ) throws -> String {
    let records = try records(worldID: worldID).filter { allowedRecordIDs?.contains($0.id) ?? true }
    let known = Set(records.map(\.id))
    let allBoards =
      try (boards(worldID: worldID, kind: "canvas") + boards(worldID: worldID, kind: "atlas"))
      .filter { includedBoardIDs?.contains($0.id) ?? true }
    func boardPriority(_ board: Board) -> Int {
      board.id == boardID ? 0 : preferredBoardIDs.contains(board.id) ? 1 : 2
    }
    let boards = allBoards.sorted { boardPriority($0) < boardPriority($1) }
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
          "place": object["placeID"] as? String ?? "",
          "parentMap": object["parentMapID"] as? String ?? "",
          "hasImage": object["image"] as? String != nil,
        ]
      }
    let relations = try relations(worldID: worldID).filter {
      known.contains($0.sourceID) && known.contains($0.targetID)
    }
    let events = try events(worldID: worldID).filter { known.contains($0.sourceID) }
    func lanePriority(_ lane: ChronologyLane) -> Int {
      lane.id == chronologyLaneID ? 0 : preferredLaneIDs.contains(lane.id) ? 1 : 2
    }
    let lanes = try chronologyLanes(worldID: worldID).filter {
      includedLaneIDs?.contains($0.id) ?? true
    }.sorted { lanePriority($0) < lanePriority($1) }
    if let chronologyLaneID, !lanes.contains(where: { $0.id == chronologyLaneID }) {
      throw SynthesisError.notFound
    }
    let placements = try chronologyPlacements(worldID: worldID)
    let object: [String: Any] = [
      "activeChronologyLane": chronologyLaneID ?? "",
      "records": records.prefix(100).map {
        ["id": $0.id, "title": $0.title, "kind": $0.kind, "state": $0.state]
      },
      "sections": try db.rows(
        "SELECT s.parent_id AS parent,s.record_id AS record,s.position FROM record_sections s JOIN records p ON p.id=s.parent_id AND p.world_id=s.world_id JOIN records r ON r.id=s.record_id AND r.world_id=s.world_id WHERE s.world_id=? AND s.archived=0 AND p.archived=0 AND r.archived=0 ORDER BY s.parent_id,s.position",
        [worldID]
      ).filter { known.contains($0["parent"] ?? "") && known.contains($0["record"] ?? "") }.prefix(
        100
      ).map { $0 },
      "rules": try db.rows(
        "SELECT r.id,r.system_id AS system,r.kind,r.title,r.body,r.state FROM rules r JOIN records p ON p.id=r.system_id AND p.world_id=r.world_id WHERE r.world_id=? AND r.archived=0 AND p.archived=0 ORDER BY r.position",
        [worldID]
      ).filter { known.contains($0["system"] ?? "") }.prefix(80).map { $0 },
      "scenarios": try db.rows(
        "SELECT s.id,s.system_id AS system,s.title,s.situation,s.expectation,s.verdict FROM rule_scenarios s JOIN records r ON r.id=s.system_id AND r.world_id=s.world_id WHERE s.world_id=? AND s.archived=0 AND r.archived=0 ORDER BY s.created_at",
        [worldID]
      ).filter { known.contains($0["system"] ?? "") }.prefix(60).map { $0 },
      "components": try creativeComponents(worldID: worldID).filter {
        known.contains($0.record.id) && ($0.parentID.map(known.contains) ?? true)
      }.prefix(80).map {
        [
          "id": $0.id, "record": $0.record.id, "parent": $0.parentID ?? "",
          "scope": $0.scope.rawValue, "kind": $0.kind.rawValue,
        ]
      },
      "relationships": relations.prefix(100).map {
        ["id": $0.id, "source": $0.sourceID, "target": $0.targetID, "label": $0.label]
      },
      "chronology": lanes.prefix(60).map {
        [
          "id": $0.id, "name": $0.name, "kind": $0.kind, "parent": $0.parentID ?? "",
          "start": $0.start, "end": $0.end,
        ]
      },
      "eventPlacement": placements.filter { key, _ in events.prefix(60).contains { $0.id == key } },
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
