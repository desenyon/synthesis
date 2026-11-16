import Foundation

/// An ordered section is a real lore record, with its own history and canon snapshot.
/// Membership organizes the page; it never changes or promotes the parent's accepted text.
public struct RecordSection: Identifiable, Sendable {
  public var id: String
  public var parentID: String
  public var record: LoreRecord
  public var position: Int
  public var archived: Bool
}

extension WorkspaceStore {
  public func recordSections(worldID: String, parentID: String, archived: Bool = false) throws
    -> [RecordSection]
  {
    _ = try record(worldID: worldID, id: parentID)
    return try db.rows(
      "SELECT r.*,d.rtf,s.id AS section_id,s.position FROM record_sections s JOIN records r ON r.id=s.record_id AND r.world_id=s.world_id LEFT JOIN rich_documents d ON d.record_id=r.id WHERE s.world_id=? AND s.parent_id=? AND s.archived=? AND r.archived=0 ORDER BY s.position,s.id",
      [worldID, parentID, archived ? "1" : "0"]
    ).map {
      RecordSection(
        id: $0["section_id"]!, parentID: parentID,
        record: decodeRecord($0),
        position: Int($0["position"]!) ?? 0, archived: archived)
    }
  }

  public func sectionParent(worldID: String, recordID: String) throws -> LoreRecord? {
    _ = try record(worldID: worldID, id: recordID)
    guard
      let row = try db.rows(
        "SELECT s.parent_id FROM record_sections s JOIN records r ON r.id=s.parent_id AND r.world_id=s.world_id WHERE s.world_id=? AND s.record_id=? AND s.archived=0 AND r.archived=0",
        [worldID, recordID]
      ).first
    else { return nil }
    return try record(worldID: worldID, id: row["parent_id"]!)
  }

  @discardableResult public func createRecordSection(
    worldID: String, parentID: String, title: String, body: String = "",
    origin: String = "user-authored"
  ) throws -> RecordSection {
    try db.transaction {
      let parent = try record(worldID: worldID, id: parentID)
      guard parent.kind == "entity", try !isArchived(worldID: worldID, recordID: parentID) else {
        throw SynthesisError.invalid(
          "Sections belong to an active entity. Restore it before adding a section.")
      }
      let child = try createRecord(
        worldID: worldID, title: title, body: body, kind: "lore",
        category: parent.category, origin: origin)
      let next =
        try db.rows(
          "SELECT COALESCE(MAX(position),-1)+1 AS next FROM record_sections WHERE world_id=? AND parent_id=?",
          [worldID, parentID]
        ).first?["next"] ?? "0"
      let id = UUID().uuidString
      let now = timestamp()
      try db.execute(
        "INSERT INTO record_sections VALUES(?,?,?,?,?,0,?,?)",
        [id, worldID, parentID, child.id, next, now, now])
      return RecordSection(
        id: id, parentID: parentID, record: child,
        position: Int(next) ?? 0, archived: false)
    }
  }

  public func reorderRecordSections(worldID: String, parentID: String, orderedIDs: [String]) throws
  {
    try db.transaction {
      let current = try recordSections(worldID: worldID, parentID: parentID)
      guard orderedIDs.count == current.count, Set(orderedIDs) == Set(current.map(\.id)) else {
        throw SynthesisError.invalid("Sections changed. Reopen the page before rearranging them.")
      }
      for (position, id) in orderedIDs.enumerated() {
        try db.execute(
          "UPDATE record_sections SET position=?,updated_at=? WHERE id=? AND world_id=? AND parent_id=?",
          [String(position), timestamp(), id, worldID, parentID])
      }
    }
  }

  public func setRecordSectionArchived(worldID: String, id: String, archived: Bool) throws {
    guard
      let row = try db.rows(
        "SELECT parent_id FROM record_sections WHERE id=? AND world_id=?",
        [id, worldID]
      ).first
    else { throw SynthesisError.notFound }
    _ = try record(worldID: worldID, id: row["parent_id"]!)
    try db.execute(
      "UPDATE record_sections SET archived=?,updated_at=? WHERE id=? AND world_id=?",
      [archived ? "1" : "0", timestamp(), id, worldID])
  }
}
