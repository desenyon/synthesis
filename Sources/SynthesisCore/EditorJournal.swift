import Foundation

/// Editor text that was typed but never reached a saved revision, kept on this device so a crash,
/// forced quit or failed save cannot lose it. Restoring it is always the creator's choice.
public struct JournalEntry: Identifiable, Equatable, Sendable {
  public var id: String { recordID }
  public var recordID: String
  public var worldID: String
  public var title: String
  public var body: String
  public var rtf: String?
  public var category: String
  /// The record version the text was typed against.
  public var baseVersion: Int
  public var updatedAt: String
}

extension WorkspaceStore {
  public func writeJournal(
    worldID: String, recordID: String, title: String, body: String, rtf: String?,
    category: String, baseVersion: Int
  ) throws {
    _ = try record(worldID: worldID, id: recordID)
    try db.execute(
      "INSERT INTO editor_journal VALUES(?,?,?,?,?,?,?,?) ON CONFLICT(record_id) DO UPDATE SET title=excluded.title,body=excluded.body,rtf=excluded.rtf,category=excluded.category,base_version=excluded.base_version,updated_at=excluded.updated_at",
      [recordID, worldID, title, body, rtf, category, String(baseVersion), timestamp()])
  }
  public func clearJournal(worldID: String, recordID: String) throws {
    try db.execute(
      "DELETE FROM editor_journal WHERE world_id=? AND record_id=?", [worldID, recordID])
  }
  /// The recovery copy for a record, only when it differs from what is saved.
  public func journal(worldID: String, recordID: String) throws -> JournalEntry? {
    guard
      let row = try db.rows(
        "SELECT * FROM editor_journal WHERE world_id=? AND record_id=?", [worldID, recordID]
      ).first
    else { return nil }
    let entry = decodeJournal(row)
    let saved = try record(worldID: worldID, id: recordID)
    if saved.title == entry.title && saved.body == entry.body
      && (saved.rtf ?? "") == (entry.rtf ?? "") && saved.category == entry.category
    {
      try clearJournal(worldID: worldID, recordID: recordID)
      return nil
    }
    return entry
  }
  /// Every outstanding recovery copy in a world whose record is still active, newest first.
  public func journals(worldID: String) throws -> [JournalEntry] {
    try db.rows(
      "SELECT j.* FROM editor_journal j JOIN records r ON r.id=j.record_id AND r.world_id=j.world_id WHERE j.world_id=? AND r.archived=0 ORDER BY j.updated_at DESC",
      [worldID]
    ).compactMap { try journal(worldID: worldID, recordID: decodeJournal($0).recordID) }
  }
  private func decodeJournal(_ row: [String: String]) -> JournalEntry {
    JournalEntry(
      recordID: row["record_id"]!, worldID: row["world_id"]!, title: row["title"]!,
      body: row["body"]!, rtf: row["rtf"], category: row["category"]!,
      baseVersion: Int(row["base_version"]!) ?? 0, updatedAt: row["updated_at"]!)
  }
}
