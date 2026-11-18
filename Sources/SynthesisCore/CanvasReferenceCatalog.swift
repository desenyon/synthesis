import Foundation

public struct CanvasReferenceChoice: Identifiable, Sendable {
  public let reference: WorldReference
  public let title: String
  public let detail: String
  public var id: WorldReference { reference }
}

public struct CanvasReferenceChoicePage: Sendable {
  public let choices: [CanvasReferenceChoice]
  public let hasNextPage: Bool
}

extension WorkspaceStore {
  /// Queries lightweight labels. The active reference is resolved again at drag or placement time.
  public func canvasReferenceChoices(
    worldID: String, kind: WorldReference.Kind, query: String, page: Int = 0
  ) throws -> CanvasReferenceChoicePage {
    let pageSize = 40
    guard page >= 0, page <= Int.max / pageSize else {
      throw SynthesisError.invalid("This page could not be opened.")
    }
    _ = try world(worldID)
    let sql: String
    switch kind {
    case .event:
      sql = """
        SELECT e.id,e.title,e.date_label AS detail
        FROM events e JOIN records r ON r.world_id=e.world_id AND r.id=e.source_id
        WHERE e.world_id=?1 AND e.archived=0 AND r.archived=0
          AND (instr(lower(e.title),lower(?2))>0 OR instr(lower(e.date_label),lower(?2))>0)
        ORDER BY e.sort_order IS NULL,e.sort_order,e.created_at,e.rowid
        LIMIT 41 OFFSET ?3
        """
    case .proposal:
      sql = """
        SELECT p.id,p.reason AS title,p.state AS detail
        FROM proposals p
        WHERE p.world_id=?1 AND instr(lower(p.reason),lower(?2))>0
        ORDER BY p.created_at DESC,p.rowid DESC
        LIMIT 41 OFFSET ?3
        """
    case .atlasImage:
      sql = """
        SELECT b.id,b.name AS title,'' AS detail
        FROM boards b
        WHERE b.world_id=?1 AND b.kind='atlas' AND b.archived=0
          AND instr(lower(b.name),lower(?2))>0
          AND CASE WHEN json_valid(b.content) THEN
            json_type(b.content,'$.image')='text' AND json_extract(b.content,'$.image')<>''
          ELSE 0 END
        ORDER BY b.updated_at DESC,b.rowid DESC
        LIMIT 41 OFFSET ?3
        """
    default:
      throw SynthesisError.invalid("This reference type is unavailable in the Canvas picker.")
    }
    let rows = try db.rows(
      sql,
      [
        worldID, String(query.trimmingCharacters(in: .whitespacesAndNewlines).prefix(300)),
        String(page * pageSize),
      ])
    let choices = rows.prefix(pageSize).compactMap { row -> CanvasReferenceChoice? in
      guard let id = row["id"], let title = row["title"], let detail = row["detail"] else {
        return nil
      }
      return CanvasReferenceChoice(
        reference: WorldReference(worldID: worldID, kind: kind, id: id),
        title: title, detail: kind == .proposal ? detail.capitalized : detail)
    }
    return CanvasReferenceChoicePage(choices: choices, hasNextPage: rows.count > pageSize)
  }
}
