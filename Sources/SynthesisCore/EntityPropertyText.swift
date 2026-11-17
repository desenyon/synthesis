import Foundation

extension WorkspaceStore {
  /// Plain text only; no media bytes. Linked entities obey the same explicit context exclusions.
  public func entityPropertyText(
    worldID: String, recordID: String, allowedIDs: Set<String>? = nil,
    limit: Int = 6000
  ) throws -> String {
    guard let review = try entityProfileReview(worldID: worldID, recordID: recordID) else {
      return ""
    }
    let budget = max(0, min(limit, 8_000_000))
    func excerpt(_ text: String, budget: Int) -> String {
      guard text.count > budget else { return text }
      let marker = "\n[Truncated: open the entity for the complete value.]"
      return String(text.prefix(max(0, budget - marker.count))) + String(marker.prefix(budget))
    }
    func describe(_ snapshot: EntityPropertySnapshot) throws -> String {
      try snapshot.fields.filter { snapshot.visibleKeys.contains($0.key) }.map { field in
        let value = try entityValueText(
          worldID: worldID, value: snapshot.values[field.key] ?? .unknown, allowedIDs: allowedIDs)
        return "\(field.label): \(excerpt(value, budget: budget >= 100_000 ? 20_000 : 1000))"
      }.joined(separator: "\n")
    }
    let header = "Entity type: \(review.snapshot.typeName)\n"
    let canonLabel = "Accepted property canon (separate frozen snapshot):\n"
    let draftLabel = "\nWorking property draft:\n"
    let available = budget - header.count - canonLabel.count - draftLabel.count
    guard available >= 128 else {
      return String(
        "Property context omitted: increase the context budget to include both accepted canon and drafts."
          .prefix(budget))
    }
    let working = try describe(review.snapshot)
    let accepted = try review.profile.canonical.map(describe) ?? "None accepted."
    // Reserve independent space for each state. A long draft must never erase accepted canon.
    var canonBudget = min(accepted.count, available * 3 / 5)
    let draftBudget = min(working.count, available - canonBudget)
    canonBudget += min(accepted.count - canonBudget, available - canonBudget - draftBudget)
    return header + canonLabel + excerpt(accepted, budget: canonBudget)
      + draftLabel + excerpt(working, budget: draftBudget)
  }
  public func entityValueText(worldID: String, value: EntityValue, allowedIDs: Set<String>? = nil)
    throws -> String
  {
    switch value {
    case .entity(let id):
      guard allowedIDs?.contains(id) ?? true else { return "Excluded entity" }
      let entity = try record(worldID: worldID, id: id)
      return "\(entity.title) [synthesis://record/\(id)]"
    case .entities(let ids):
      return ids.isEmpty
        ? "None"
        : try ids.map {
          try entityValueText(worldID: worldID, value: .entity($0), allowedIDs: allowedIDs)
        }.joined(separator: "; ")
    case .media(let name, _, _): return "Image reference: \(name)"
    default: return value.summary
    }
  }
  func refreshEntityPropertySearch(worldID: String, recordID: String? = nil) throws {
    if let recordID {
      try db.execute(
        "DELETE FROM entity_profile_search WHERE world_id=? AND record_id=?", [worldID, recordID])
    } else {
      try db.execute("DELETE FROM entity_profile_search WHERE world_id=?", [worldID])
    }
    let rows = try db.rows(
      "SELECT record_id FROM entity_profiles WHERE world_id=? \(recordID == nil ? "" : "AND record_id=?")",
      recordID.map { [worldID, $0] } ?? [worldID])
    for row in rows {
      let id = row["record_id"]!
      let text = try entityPropertyText(worldID: worldID, recordID: id, limit: 8_000_000)
      try db.execute(
        "INSERT INTO entity_profile_search(record_id,world_id,content) VALUES(?,?,?)",
        [id, worldID, text])
    }
  }
}
