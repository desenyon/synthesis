import Foundation

/// Values saved immediately before a relationship edit or archive.
public struct RelationshipRevision: Identifiable, Equatable, Sendable {
  public struct Cursor: Equatable, Sendable {
    let date: String
    let sequence: Int
  }

  public let id: String
  public let label: String
  public let attributes: RelationshipAttributes
  public let revision: Int?
  public let action: String
  public let supersededAt: String
  public let cursor: Cursor
}

extension WorkspaceStore {
  public func relationshipHistory(
    worldID: String, relationshipID: String, before: RelationshipRevision.Cursor? = nil,
    limit: Int = 25
  ) throws -> [RelationshipRevision] {
    let count = min(100, max(1, limit))
    // A left join distinguishes an available edge with no history from an unavailable edge.
    // Scope both the history and its original endpoints, including old imported snapshots.
    var historyScope = """
      h.relationship_id=r.id AND h.world_id=r.world_id
      AND h.source_id=r.source_id AND h.target_id=r.target_id
      """
    var parameters: [String?] = []
    if let before {
      historyScope += " AND (h.created_at<? OR (h.created_at=? AND h.rowid<?))"
      parameters += [before.date, before.date, String(before.sequence)]
    }
    let rows = try db.rows(
      """
      SELECT h.*, h.rowid AS sequence
      FROM relationships r
      JOIN records a ON a.id=r.source_id AND a.world_id=r.world_id
      JOIN records b ON b.id=r.target_id AND b.world_id=r.world_id
      LEFT JOIN relationship_history h ON \(historyScope)
      WHERE r.world_id=? AND r.id=? AND r.archived=0 AND a.archived=0 AND b.archived=0
      ORDER BY h.created_at DESC,h.rowid DESC LIMIT ?
      """, parameters + [worldID, relationshipID, String(count)])
    guard !rows.isEmpty else { throw SynthesisError.notFound }
    return try rows.compactMap { row in
      guard let id = row["id"] else { return nil }
      guard let label = row["label"], let action = row["action"], let date = row["created_at"],
        let stored = row["attributes"], let sequence = row["sequence"].flatMap(Int.init)
      else { throw SynthesisError.invalid("The saved relationship history could not be read.") }
      return RelationshipRevision(
        id: id, label: label, attributes: try RelationshipAttributes.decodeStored(stored),
        revision: row["revision"].flatMap(Int.init), action: action, supersededAt: date,
        cursor: .init(date: date, sequence: sequence))
    }
  }
}
