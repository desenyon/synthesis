import Foundation

public struct WorldSummary: Sendable {
  public var records: Int
  public var conversations: Int
  public var updatedAt: String
}

extension WorkspaceStore {
  /// Active counts and latest saved activity, scoped independently to each local world.
  public func worldSummaries() throws -> [String: WorldSummary] {
    let rows = try db.rows(
      """
      WITH activity AS (
        SELECT id AS world_id,updated_at FROM worlds
        UNION ALL SELECT world_id,updated_at FROM records
        UNION ALL SELECT world_id,updated_at FROM conversations
        UNION ALL SELECT world_id,created_at FROM messages
        UNION ALL SELECT world_id,updated_at FROM boards
        UNION ALL SELECT world_id,updated_at FROM relationships
        UNION ALL SELECT world_id,updated_at FROM links
        UNION ALL SELECT world_id,updated_at FROM events
        UNION ALL SELECT world_id,updated_at FROM rules
        UNION ALL SELECT world_id,updated_at FROM rule_scenarios
        UNION ALL SELECT world_id,updated_at FROM record_sections
        UNION ALL SELECT world_id,updated_at FROM chronology_lanes
        UNION ALL SELECT world_id,updated_at FROM chronology_placements
      )
      SELECT w.id,
        (SELECT COUNT(*) FROM records r WHERE r.world_id=w.id AND r.archived=0) AS record_count,
        (SELECT COUNT(*) FROM conversations c WHERE c.world_id=w.id AND c.archived=0) AS conversation_count,
        (SELECT MAX(a.updated_at) FROM activity a WHERE a.world_id=w.id) AS updated_at
      FROM worlds w WHERE w.owner_id='local'
      """)
    return Dictionary(
      uniqueKeysWithValues: rows.map {
        (
          $0["id"]!,
          WorldSummary(
            records: Int($0["record_count"]!) ?? 0,
            conversations: Int($0["conversation_count"]!) ?? 0, updatedAt: $0["updated_at"]!)
        )
      })
  }

  public func setWorldDescription(worldID: String, description: String) throws {
    _ = try world(worldID)
    let value = description.trimmingCharacters(in: .whitespacesAndNewlines)
    guard value.count <= 4000 else {
      throw SynthesisError.invalid("Keep the world description under 4,000 characters.")
    }
    try db.execute(
      "UPDATE worlds SET description=?,updated_at=? WHERE id=?", [value, timestamp(), worldID])
  }
}
