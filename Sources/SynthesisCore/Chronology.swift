import Foundation

public struct ChronologyLane: Identifiable, Codable, Equatable, Sendable {
  public var id: String
  public var parentID: String?
  public var name: String
  public var kind: String
  public var start: String
  public var end: String
  public var notes: String
}

extension WorkspaceStore {
  @discardableResult public func updateChronologyLane(
    worldID: String, expected: ChronologyLane, name: String, parentID: String?,
    start: String, end: String, notes: String
  ) throws -> ChronologyLane {
    try db.transaction {
      let lanes = try chronologyLanes(worldID: worldID)
      guard lanes.first(where: { $0.id == expected.id }) == expected else {
        throw SynthesisError.stale
      }
      let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !title.isEmpty, title.count <= 160, start.count <= 160, end.count <= 160,
        notes.count <= 30_000
      else { throw SynthesisError.invalid("Use a short name and date labels for this history.") }
      var ancestor = parentID
      var visited: Set<String> = [expected.id]
      while let id = ancestor {
        guard visited.insert(id).inserted, let lane = lanes.first(where: { $0.id == id }) else {
          throw SynthesisError.invalid("A history branch cannot contain itself or form a cycle.")
        }
        ancestor = lane.parentID
      }
      try db.execute(
        "UPDATE chronology_lanes SET name=?,start_label=?,end_label=?,notes=?,parent_id=?,updated_at=? WHERE world_id=? AND id=? AND archived=0",
        [title, start, end, notes, parentID, timestamp(), worldID, expected.id])
      return ChronologyLane(
        id: expected.id, parentID: parentID, name: title, kind: expected.kind,
        start: start, end: end, notes: notes)
    }
  }
  public func chronologyLanes(worldID: String) throws -> [ChronologyLane] {
    _ = try world(worldID)
    return try db.rows(
      "SELECT * FROM chronology_lanes WHERE world_id=? AND archived=0 ORDER BY created_at,rowid",
      [worldID]
    ).map {
      ChronologyLane(
        id: $0["id"]!, parentID: $0["parent_id"], name: $0["name"]!, kind: $0["kind"]!,
        start: $0["start_label"]!, end: $0["end_label"]!, notes: $0["notes"]!)
    }
  }
  public func createChronologyLane(
    worldID: String, name: String, kind: String, parentID: String? = nil, start: String = "",
    end: String = "", notes: String = ""
  ) throws -> ChronologyLane {
    _ = try world(worldID)
    let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !title.isEmpty, title.count <= 160, ["branch", "period"].contains(kind),
      start.count <= 160, end.count <= 160, notes.count <= 30_000
    else {
      throw SynthesisError.invalid("Use a short name and date labels for this branch or period.")
    }
    if let parentID {
      guard try chronologyLanes(worldID: worldID).contains(where: { $0.id == parentID }) else {
        throw SynthesisError.notFound
      }
    }
    let id = UUID().uuidString
    let now = timestamp()
    try db.execute(
      "INSERT INTO chronology_lanes(id,world_id,parent_id,name,kind,start_label,end_label,notes,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?,?,?)",
      [id, worldID, parentID, title, kind, start, end, notes, now, now])
    return ChronologyLane(
      id: id, parentID: parentID, name: title, kind: kind, start: start, end: end, notes: notes)
  }
  public func setChronologyLaneArchived(worldID: String, id: String, archived: Bool) throws {
    _ = try world(worldID)
    guard
      try !db.rows("SELECT id FROM chronology_lanes WHERE world_id=? AND id=?", [worldID, id])
        .isEmpty
    else { throw SynthesisError.notFound }
    try db.execute(
      "UPDATE chronology_lanes SET archived=?,updated_at=? WHERE world_id=? AND id=?",
      [archived ? "1" : "0", timestamp(), worldID, id])
  }
  public func chronologyPlacements(worldID: String) throws -> [String: String] {
    _ = try world(worldID)
    let rows = try db.rows(
      "SELECT event_id,lane_id FROM chronology_placements WHERE world_id=?", [worldID])
    return Dictionary(uniqueKeysWithValues: rows.map { ($0["event_id"]!, $0["lane_id"]!) })
  }
  /// Source edits and chronology assignment share a transaction. A period is descriptive,
  /// never an inferred calendar. Branch membership does not promote an event into canon.
  public func saveChronologyEvent(
    worldID: String, id: String?, title: String, date: String, source: String?, order: Int?,
    laneID: String?, origin: String = "user-authored"
  ) throws -> WorldEvent {
    try db.transaction {
      if let laneID {
        guard try chronologyLanes(worldID: worldID).contains(where: { $0.id == laneID }) else {
          throw SynthesisError.notFound
        }
      }
      // The schema requires a source. A new event can create its draft atomically.
      let source =
        try source
        ?? createRecord(
          worldID: worldID, title: title, kind: "lore", category: "History", origin: origin
        ).id
      let event: WorldEvent
      if let id {
        event = try updateEvent(
          worldID: worldID, id: id, title: title, date: date, source: source, order: order)
      } else {
        event = try addEvent(
          worldID: worldID, title: title, date: date, source: source, order: order, origin: origin)
      }
      if let laneID {
        let now = timestamp()
        try db.execute(
          "INSERT INTO chronology_placements(id,world_id,event_id,lane_id,created_at,updated_at) VALUES(?,?,?,?,?,?) ON CONFLICT(world_id,event_id) DO UPDATE SET lane_id=excluded.lane_id,updated_at=excluded.updated_at",
          [UUID().uuidString, worldID, event.id, laneID, now, now])
      } else {
        // Removing membership does not delete the event or branch.
        try db.execute(
          "DELETE FROM chronology_placements WHERE world_id=? AND event_id=?", [worldID, event.id])
      }
      return event
    }
  }
}
