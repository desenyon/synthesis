import Foundation

/// Something in a world that may deserve the creator's attention. Findings are observations
/// computed locally from stored data; they never change anything and involve no model.
public struct WorldFinding: Identifiable, Equatable, Sendable {
  public enum Kind: String, Sendable {
    case duplicateName, unlinkedMention, isolatedEntity, orphanedEvent, emptyRecord
  }
  /// Stable across runs for the same underlying fact, so a dismissal can be remembered.
  public var id: String
  public var kind: Kind
  public var title: String
  public var detail: String
  /// Records involved, most relevant first. For an unlinked mention: [mentioning, mentioned].
  public var recordIDs: [String]
}

extension WorkspaceStore {
  /// Local consistency review of one world: clashing names, mentions that are not linked,
  /// entities connected to nothing, events whose source was archived, and empty records.
  public func worldChecks(worldID: String) throws -> [WorldFinding] {
    let records = try records(worldID: worldID)
    let dismissed = Set(
      (try preference("checks-dismissed:\(worldID)")).flatMap {
        try? JSONDecoder().decode([String].self, from: Data($0.utf8))
      } ?? [])
    var findings: [WorldFinding] = []

    // Names and aliases that point at more than one record.
    var names: [String: [LoreRecord]] = [:]
    for record in records {
      for name in Set(([record.title] + (record.aliases ?? [])).map { $0.lowercased() })
      where !name.isEmpty {
        names[name, default: []].append(record)
      }
    }
    for (name, owners) in names where owners.count > 1 {
      let sorted = owners.sorted { $0.id < $1.id }
      findings.append(
        WorldFinding(
          id: "duplicate:\(name)", kind: .duplicateName,
          title:
            "“\(sorted[0].title.lowercased() == name ? sorted[0].title : name)” names \(sorted.count) records",
          detail: sorted.map { "\($0.title) (\(kindName($0)))" }.joined(separator: " · "),
          recordIDs: sorted.map(\.id)))
    }

    // A record's text names another record without a link or relationship between them.
    let relations = try relations(worldID: worldID)
    var connected = Set<String>()
    for relation in relations {
      connected.insert("\(relation.sourceID)|\(relation.targetID)")
      connected.insert("\(relation.targetID)|\(relation.sourceID)")
    }
    for row in try db.rows("SELECT source_id,target_id FROM links WHERE world_id=?", [worldID]) {
      connected.insert("\(row["source_id"]!)|\(row["target_id"]!)")
    }
    let targets = records.filter { $0.kind == "entity" && $0.title.count >= 4 }
    var mentions = 0
    for record in records where !record.body.isEmpty && mentions < 40 {
      let body = record.body.lowercased()
      for target in targets where target.id != record.id {
        guard !connected.contains("\(record.id)|\(target.id)"),
          containsWord(body, target.title.lowercased())
        else { continue }
        findings.append(
          WorldFinding(
            id: "mention:\(record.id):\(target.id)", kind: .unlinkedMention,
            title: "“\(record.title)” mentions \(target.title)",
            detail: "The text names \(target.title) but the two records are not linked.",
            recordIDs: [record.id, target.id]))
        mentions += 1
      }
    }

    // Entities that nothing points to and that point to nothing.
    var touched = Set<String>()
    for pair in connected {
      for id in pair.split(separator: "|") { touched.insert(String(id)) }
    }
    for record in records where record.kind == "entity" && !touched.contains(record.id) {
      findings.append(
        WorldFinding(
          id: "isolated:\(record.id)", kind: .isolatedEntity,
          title: "\(record.title) is not connected to anything",
          detail: "No relationships or links. It will stand alone in Graph.",
          recordIDs: [record.id]))
    }

    let live = Set(records.map(\.id))
    for event in try events(worldID: worldID) where !live.contains(event.sourceID) {
      findings.append(
        WorldFinding(
          id: "orphan-event:\(event.id)", kind: .orphanedEvent,
          title: "“\(event.title)” cites an archived record",
          detail: "Restore its source from Library, or edit the event to cite another record.",
          recordIDs: []))
    }
    for record in records
    where record.kind != "capture"
      && record.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    {
      findings.append(
        WorldFinding(
          id: "empty:\(record.id)", kind: .emptyRecord, title: "\(record.title) has no text yet",
          detail: "A title without a description.", recordIDs: [record.id]))
    }
    let order: [WorldFinding.Kind] = [
      .duplicateName, .orphanedEvent, .unlinkedMention, .isolatedEntity, .emptyRecord,
    ]
    return findings.filter { !dismissed.contains($0.id) }.sorted {
      let a = order.firstIndex(of: $0.kind)!
      let b = order.firstIndex(of: $1.kind)!
      return a == b ? $0.title < $1.title : a < b
    }
  }
  /// Remembers that the creator considers a finding fine. Reversible with `restoreChecks`.
  public func dismissCheck(worldID: String, id: String) throws {
    _ = try world(worldID)
    let key = "checks-dismissed:\(worldID)"
    var ids =
      (try preference(key)).flatMap {
        try? JSONDecoder().decode([String].self, from: Data($0.utf8))
      }
      ?? []
    guard !ids.contains(id) else { return }
    ids.append(id)
    try setPreference(key, value: String(decoding: try JSONEncoder().encode(ids), as: UTF8.self))
  }
  public func restoreChecks(worldID: String) throws {
    _ = try world(worldID)
    try setPreference("checks-dismissed:\(worldID)", value: "[]")
  }
  public func dismissedCheckCount(worldID: String) throws -> Int {
    (try preference("checks-dismissed:\(worldID)")).flatMap {
      try? JSONDecoder().decode([String].self, from: Data($0.utf8))
    }?.count ?? 0
  }
  /// Records with accepted canon whose working draft has moved on, oldest change first.
  public func canonQueue(worldID: String) throws -> [LoreRecord] {
    try records(worldID: worldID).filter { $0.canonical != nil && $0.state != "canon" }.reversed()
  }
  private func kindName(_ record: LoreRecord) -> String {
    record.category.isEmpty
      ? (record.kind == "entity" ? "entity" : record.kind == "capture" ? "idea" : "document")
      : record.category
  }
  /// Whole-word, case-insensitive containment; both arguments are already lowercased.
  private func containsWord(_ text: String, _ word: String) -> Bool {
    var search = text.startIndex..<text.endIndex
    while let range = text.range(of: word, range: search) {
      let before =
        range.lowerBound == text.startIndex ? nil : text[text.index(before: range.lowerBound)]
      let after = range.upperBound == text.endIndex ? nil : text[range.upperBound]
      if !(before.map { $0.isLetter || $0.isNumber } ?? false),
        !(after.map { $0.isLetter || $0.isNumber } ?? false)
      {
        return true
      }
      search = range.upperBound..<text.endIndex
    }
    return false
  }
}
