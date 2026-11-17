import CoreFoundation
import Foundation

/// Named maps remain ordinary world-scoped boards. Optional links connect a local map to a
/// place and a larger map without inventing geographic geometry or regenerating artwork.
public struct AtlasLinks: Equatable, Sendable {
  public var placeID: String?
  public var parentMapID: String?
  public init(content: String) throws {
    guard let object = try JSONSerialization.jsonObject(with: Data(content.utf8)) as? [String: Any]
    else { throw SynthesisError.invalid("This map cannot be read.") }
    placeID = object["placeID"] as? String
    parentMapID = object["parentMapID"] as? String
  }
}

extension WorkspaceStore {
  /// Atomically saves the exact map that was opened. A stale editor or Undo cannot overwrite
  /// a newer marker placement, image replacement, or rename made in another workspace.
  public func saveAtlasMap(
    worldID: String, id: String? = nil, name: String, content: String, expected: Board? = nil
  ) throws -> Board {
    try db.transaction {
      guard content.utf8.count <= 12_000_000 else {
        throw SynthesisError.invalid("This map is too large to save.")
      }
      if let id {
        let current = try board(worldID: worldID, id: id, kind: "atlas")
        guard let expected, expected.id == id, expected.content == current.content,
          expected.name == current.name
        else { throw SynthesisError.stale }
      }
      try validateAtlasMap(worldID: worldID, id: id, content: content)
      return try saveBoard(
        worldID: worldID, id: id, name: name.trimmingCharacters(in: .whitespacesAndNewlines),
        kind: "atlas", content: content)
    }
  }
  func validateAtlasMap(
    worldID: String, id: String?, content: String, includingArchived: Bool = false
  ) throws {
    guard
      let object = try JSONSerialization.jsonObject(with: Data(content.utf8)) as? [String: Any],
      let markers = object["markers"] as? [[String: Any]], markers.count <= 10_000
    else { throw SynthesisError.invalid("This map has an unreadable marker list.") }
    let known = Set(
      try db.rows("SELECT id FROM records WHERE world_id=?", [worldID]).compactMap { $0["id"] })
    var markerIDs = Set<String>()
    var placed = Set<String>()
    for marker in markers {
      guard let id = marker["id"] as? String, !id.isEmpty, markerIDs.insert(id).inserted,
        let record = marker["recordID"] as? String, known.contains(record),
        placed.insert(record).inserted,
        let x = marker["x"] as? NSNumber, let y = marker["y"] as? NSNumber,
        CFGetTypeID(x) != CFBooleanGetTypeID(), CFGetTypeID(y) != CFBooleanGetTypeID(),
        x.doubleValue.isFinite, y.doubleValue.isFinite, (0...1).contains(x.doubleValue),
        (0...1).contains(y.doubleValue)
      else {
        throw SynthesisError.invalid(
          "Map markers must link to this world and stay within the image.")
      }
    }
    if let place = object["placeID"] {
      guard let place = place as? String, try record(worldID: worldID, id: place).kind == "entity"
      else {
        throw SynthesisError.invalid("A map's place must be an entity in this world.")
      }
    }
    var parent = object["parentMapID"] as? String
    if object["parentMapID"] != nil && parent == nil {
      throw SynthesisError.invalid("Choose a valid parent map.")
    }
    var visited = Set<String>()
    if let id { visited.insert(id) }
    while let ancestor = parent {
      guard visited.insert(ancestor).inserted, visited.count <= 128 else {
        throw SynthesisError.invalid("A map cannot contain itself or create a cycle.")
      }
      guard
        let ancestorContent = try db.rows(
          "SELECT content FROM boards WHERE world_id=? AND id=? AND kind='atlas'"
            + (includingArchived ? "" : " AND archived=0"),
          [worldID, ancestor]
        ).first?["content"]
      else { throw SynthesisError.notFound }
      parent = try AtlasLinks(content: ancestorContent).parentMapID
    }
  }
  public func createAtlasMap(
    worldID: String, name: String, placeID: String? = nil, parentMapID: String? = nil
  ) throws -> Board {
    var object: [String: Any] = ["markers": [[String: Any]]()]
    object["placeID"] = placeID
    object["parentMapID"] = parentMapID
    return try saveAtlasMap(
      worldID: worldID, name: name,
      content: String(
        decoding: JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
        as: UTF8.self))
  }
  public func mapsForRecord(worldID: String, recordID: String) throws -> [Board] {
    _ = try record(worldID: worldID, id: recordID)
    return try boards(worldID: worldID, kind: "atlas").filter { board in
      let object =
        try JSONSerialization.jsonObject(with: Data(board.content.utf8)) as? [String: Any]
      return object?["placeID"] as? String == recordID
        || (object?["markers"] as? [[String: Any]] ?? []).contains {
          $0["recordID"] as? String == recordID
        }
    }
  }
  public func archiveAtlasMap(worldID: String, id: String) throws {
    guard
      try !boards(worldID: worldID, kind: "atlas").contains(where: {
        try AtlasLinks(content: $0.content).parentMapID == id
      })
    else { throw SynthesisError.invalid("Move or remove this map's child maps first.") }
    _ = try board(worldID: worldID, id: id, kind: "atlas")
    try setBoardArchived(worldID: worldID, id: id, archived: true)
  }
}
