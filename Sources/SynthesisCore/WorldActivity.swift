import Foundation

/// Latest saved activity for each object, not a fabricated chronological narrative.
public struct WorldActivity: Identifiable, Equatable, Sendable {
  public enum Kind: String, Sendable { case record, relationship, event, board, proposal, lane }
  public var worldID: String
  public var objectID: String
  public var kind: Kind
  public var title: String
  public var detail: String
  public var updatedAt: String
  public var boardKind: String?
  public var id: String { "\(kind.rawValue):\(objectID)" }
}

extension LoreRecord {
  /// Project outlines are ordinary revisioned entities, so links, sections and exports all work.
  public var isProject: Bool {
    kind == "entity" && category.localizedCaseInsensitiveCompare("Projects") == .orderedSame
  }
}

extension WorkspaceStore {
  public func createProject(worldID: String, title: String) throws -> LoreRecord {
    try createRecord(
      worldID: worldID, title: title.trimmingCharacters(in: .whitespacesAndNewlines),
      kind: "entity", category: "Projects")
  }

  public func recentWorldActivity(worldID: String, limit: Int = 12) throws -> [WorldActivity] {
    _ = try world(worldID)
    let count = max(0, min(100, limit))
    guard count > 0 else { return [] }
    let rows = try db.rows(
      """
      WITH activity AS (
        SELECT r.id,'record' AS kind,r.title,
          CASE WHEN r.state='canon' THEN 'Canon accepted'
               WHEN r.kind='capture' THEN 'Idea captured'
               WHEN r.version=1 THEN 'Created' ELSE 'Draft saved' END AS detail,
          r.updated_at,'' AS board_kind
        FROM records r WHERE r.world_id=? AND r.archived=0
          AND NOT EXISTS (SELECT 1 FROM record_sections s JOIN records p ON p.id=s.parent_id
            WHERE s.record_id=r.id AND (s.archived=1 OR p.archived=1))
        UNION ALL
        SELECT e.id,'event',e.title,'History updated',e.updated_at,''
        FROM events e JOIN records r ON r.id=e.source_id AND r.world_id=e.world_id
        WHERE e.world_id=? AND e.archived=0 AND r.archived=0
        UNION ALL
        SELECT r.id,'relationship',s.title || ' → ' || t.title,r.label,r.updated_at,''
        FROM relationships r JOIN records s ON s.id=r.source_id AND s.world_id=r.world_id
          JOIN records t ON t.id=r.target_id AND t.world_id=r.world_id
        WHERE r.world_id=? AND r.archived=0 AND s.archived=0 AND t.archived=0
        UNION ALL
        SELECT id,'board',name,CASE kind WHEN 'atlas' THEN 'Map saved' ELSE 'Canvas saved' END,
          updated_at,kind FROM boards WHERE world_id=? AND archived=0 AND kind IN ('atlas','canvas')
        UNION ALL
        SELECT id,'proposal',reason,
          CASE state WHEN 'pending' THEN 'Awaiting review' WHEN 'accepted' THEN 'Review completed'
            ELSE 'Proposal dismissed' END,updated_at,'' FROM proposals WHERE world_id=?
        UNION ALL
        SELECT id,'lane',name,'History ' || kind || ' updated',updated_at,''
        FROM chronology_lanes WHERE world_id=? AND archived=0
      )
      SELECT * FROM activity ORDER BY updated_at DESC,kind,id LIMIT ?
      """, Array(repeating: worldID, count: 6) + [String(count)])
    return rows.compactMap { row in
      guard let kind = WorldActivity.Kind(rawValue: row["kind"] ?? ""),
        let id = row["id"], let title = row["title"], let date = row["updated_at"]
      else { return nil }
      return WorldActivity(
        worldID: worldID, objectID: id, kind: kind, title: title,
        detail: row["detail"] ?? "", updatedAt: date,
        boardKind: kind == .board ? row["board_kind"] : nil)
    }
  }
}
