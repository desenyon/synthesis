import Foundation

/// Committed editing history, distinct from fictional dates and from each object's latest state.
public struct WorldChange: Identifiable, Equatable, Sendable {
  public enum Action: String, CaseIterable, Sendable {
    case created, updated, approved, rejected, archived, restored, linked, unlinked, moved, recorded
  }
  public let id: String
  public let worldID: String
  public let objectID: String
  public let kind: WorldActivity.Kind
  public let action: Action
  public let title: String
  public let detail: String
  public let createdAt: String
  public let revision: Int?
  public let boardKind: String?
  public let reconstructed: Bool
  public let sourceAvailable: Bool
  public let sequence: Int
  public var cursor: Cursor { Cursor(date: createdAt, sequence: sequence) }
  public struct Cursor: Equatable, Sendable {
    public let date: String
    public let sequence: Int
  }
  public var source: WorldActivity {
    WorldActivity(
      worldID: worldID, objectID: objectID, kind: kind, title: title, detail: detail,
      updatedAt: createdAt, boardKind: boardKind)
  }
}

extension WorkspaceStore {
  func validateActivitySources(worldID: String) throws {
    let sources: [WorldActivity.Kind: String] = [
      .record: "records", .relationship: "relationships", .event: "events", .board: "boards",
      .proposal: "proposals", .lane: "chronology_lanes", .world: "worlds",
      .conversation: "conversations",
    ]
    for (kind, table) in sources {
      let scope = kind == .world ? "s.id=a.world_id" : "s.world_id=a.world_id"
      guard
        try db.rows(
          "SELECT a.id FROM world_activity a WHERE a.world_id=? AND a.kind=? AND NOT EXISTS (SELECT 1 FROM \(table) s WHERE s.id=a.object_id AND \(scope)) LIMIT 1",
          [worldID, kind.rawValue]
        ).isEmpty
      else { throw SynthesisError.invalid("Activity history refers to an unavailable source.") }
    }
  }
  /// Stable keyset pagination: new changes cannot duplicate or skip older pages.
  public func worldChangeHistory(
    worldID: String, query: String = "", kind: WorldActivity.Kind? = nil,
    action: WorldChange.Action? = nil, before: WorldChange.Cursor? = nil, limit: Int = 50
  ) throws -> [WorldChange] {
    _ = try world(worldID)
    guard query.count <= 512 else { throw SynthesisError.invalid("Use a shorter activity search.") }
    let count = max(0, min(100, limit))
    guard count > 0 else { return [] }
    var clauses = ["world_id=?"]
    var values: [String?] = [worldID]
    if let kind {
      clauses.append("kind=?")
      values.append(kind.rawValue)
    }
    if let action {
      clauses.append("action=?")
      values.append(action.rawValue)
    }
    let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
    if !text.isEmpty {
      let pattern =
        "%"
        + text.replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "%", with: "\\%")
        .replacingOccurrences(of: "_", with: "\\_") + "%"
      clauses.append("(title LIKE ? ESCAPE '\\' OR detail LIKE ? ESCAPE '\\')")
      values += [pattern, pattern]
    }
    if let before {
      clauses.append("(created_at<? OR (created_at=? AND rowid<?))")
      values += [before.date, before.date, String(before.sequence)]
    }
    values.append(String(count))
    return try db.rows(
      "SELECT a.*,a.rowid AS sequence,\(Self.activitySourceAvailability) AS available FROM world_activity a WHERE \(clauses.joined(separator: " AND ")) ORDER BY created_at DESC,a.rowid DESC LIMIT ?",
      values
    ).map { row in
      guard let id = row["id"], let objectID = row["object_id"],
        let kind = WorldActivity.Kind(rawValue: row["kind"] ?? ""),
        let action = WorldChange.Action(rawValue: row["action"] ?? ""),
        let date = row["created_at"], let sequence = Int(row["sequence"] ?? "")
      else { throw SynthesisError.invalid("A saved activity entry could not be read.") }
      return WorldChange(
        id: id, worldID: worldID, objectID: objectID, kind: kind, action: action,
        title: row["title"] ?? "", detail: row["detail"] ?? "", createdAt: date,
        revision: row["record_version"].flatMap(Int.init), boardKind: row["board_kind"],
        reconstructed: row["reconstructed"] == "1", sourceAvailable: row["available"] == "1",
        sequence: sequence)
    }
  }
  private static let activitySourceAvailability = """
    CASE a.kind
      WHEN 'record' THEN EXISTS(SELECT 1 FROM records s WHERE s.id=a.object_id AND s.world_id=a.world_id AND s.archived=0)
      WHEN 'relationship' THEN EXISTS(SELECT 1 FROM relationships s JOIN records x ON x.id=s.source_id JOIN records y ON y.id=s.target_id WHERE s.id=a.object_id AND s.world_id=a.world_id AND s.archived=0 AND x.archived=0 AND y.archived=0)
      WHEN 'event' THEN EXISTS(SELECT 1 FROM events s JOIN records x ON x.id=s.source_id WHERE s.id=a.object_id AND s.world_id=a.world_id AND s.archived=0 AND x.archived=0)
      WHEN 'board' THEN EXISTS(SELECT 1 FROM boards s WHERE s.id=a.object_id AND s.world_id=a.world_id AND s.archived=0)
      WHEN 'proposal' THEN EXISTS(SELECT 1 FROM proposals s WHERE s.id=a.object_id AND s.world_id=a.world_id)
      WHEN 'lane' THEN EXISTS(SELECT 1 FROM chronology_lanes s WHERE s.id=a.object_id AND s.world_id=a.world_id AND s.archived=0)
      WHEN 'world' THEN EXISTS(SELECT 1 FROM worlds s WHERE s.id=a.object_id AND s.id=a.world_id)
      WHEN 'conversation' THEN EXISTS(SELECT 1 FROM conversations s WHERE s.id=a.object_id AND s.world_id=a.world_id AND s.archived=0)
      ELSE 0 END
    """
}
