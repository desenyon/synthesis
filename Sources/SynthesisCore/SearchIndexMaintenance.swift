import Foundation

/// Derived local search data that no longer matches its authored source.
public enum SearchIndexComponent: String, CaseIterable, Sendable {
  case records
  case entityProperties
  case historicalNames
}

extension WorkspaceStore {
  /// Audit a consistent read snapshot. Compare text as well as membership so same-count drift
  /// (such as a renamed entity referenced by another profile) is visible.
  public func staleSearchIndexes(worldID: String) throws -> Set<SearchIndexComponent> {
    try db.transaction(immediate: false) {
      _ = try world(worldID)
      var stale: Set<SearchIndexComponent> = []
      if try db.rows(
        """
        SELECT COUNT(*) != COUNT(DISTINCT r.id) OR COUNT(*) != (
          SELECT COUNT(*) FROM records WHERE world_id=?1
        ) AS stale
        FROM records_fts f LEFT JOIN records r
          ON r.id=f.id AND r.world_id=f.world_id AND r.title IS f.title AND r.body IS f.body
          AND r.tags IS f.tags AND r.aliases IS f.aliases AND r.category IS f.category
        WHERE f.world_id=?1
        """, [worldID]
      ).first?["stale"] == "1" {
        stale.insert(.records)
      }
      if try db.rows(
        """
        SELECT COUNT(*) != COUNT(DISTINCT n.id) OR COUNT(*) != (
          SELECT COUNT(*) FROM entity_name_periods WHERE world_id=?1 AND archived=0
        ) AS stale
        FROM entity_name_search f LEFT JOIN entity_name_periods n
          ON n.id=f.period_id AND n.world_id=f.world_id AND n.record_id=f.record_id
          AND n.name IS f.name AND n.archived=0
        WHERE f.world_id=?1
        """, [worldID]
      ).first?["stale"] == "1" {
        stale.insert(.historicalNames)
      }

      var unmatched = Set(
        try db.rows("SELECT record_id FROM entity_profiles WHERE world_id=?", [worldID])
          .compactMap { $0["record_id"] })
      try db.forEachRow(
        "SELECT record_id,content FROM entity_profile_search WHERE world_id=?", [worldID]
      ) { row in
        guard !stale.contains(.entityProperties) else { return }
        guard let id = row["record_id"], unmatched.remove(id) != nil else {
          stale.insert(.entityProperties)
          return
        }
        let source = try entityPropertyText(worldID: worldID, recordID: id, limit: 8_000_000)
        if row["content"] != source { stale.insert(.entityProperties) }
      }
      if !unmatched.isEmpty { stale.insert(.entityProperties) }
      return stale
    }
  }

  /// Replace only the current world's derived rows. Authored records, canon, history and
  /// other worlds are untouched. All three indexes roll back together on failure.
  public func rebuildSearchIndexes(worldID: String) throws {
    try db.transaction {
      _ = try world(worldID)
      try db.execute("DELETE FROM records_fts WHERE world_id=?", [worldID])
      try db.execute(
        """
        INSERT INTO records_fts(id,world_id,title,body,tags,aliases,category)
        SELECT id,world_id,title,body,tags,aliases,category FROM records WHERE world_id=?
        """, [worldID])
      try db.execute("DELETE FROM entity_name_search WHERE world_id=?", [worldID])
      try db.execute(
        """
        INSERT INTO entity_name_search(name,period_id,record_id,world_id)
        SELECT name,id,record_id,world_id FROM entity_name_periods WHERE world_id=? AND archived=0
        """, [worldID])
      try refreshEntityPropertySearch(worldID: worldID)
    }
  }
}
