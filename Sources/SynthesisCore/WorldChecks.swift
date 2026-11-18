import Foundation

/// Something in a world that may deserve the creator's attention. Findings are observations
/// computed locally from stored data; they never change anything and involve no model.
public struct WorldFinding: Identifiable, Equatable, Sendable {
  public enum Kind: String, Sendable {
    case duplicateName, unlinkedMention, isolatedEntity, orphanedEvent, emptyRecord
    case conflictingRelationship, timelineOrder, tagVariant
  }
  /// Stable across runs for the same underlying fact, so a dismissal can be remembered.
  public var id: String
  public var kind: Kind
  public var title: String
  public var detail: String
  /// Records involved, most relevant first. For an unlinked mention: [mentioning, mentioned].
  public var recordIDs: [String]
  /// Kind-specific value for an action; for a tag variant, the spelling a merge keeps.
  public var value: String? = nil
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
    findings += relationshipFindings(relations, records: records)
    findings += timelineFindings(
      try events(worldID: worldID), placements: try chronologyPlacements(worldID: worldID),
      lanes: try chronologyLanes(worldID: worldID, includingArchived: true))
    findings += tagFindings(records)
    let order: [WorldFinding.Kind] = [
      .duplicateName, .conflictingRelationship, .timelineOrder, .orphanedEvent, .tagVariant,
      .unlinkedMention, .isolatedEntity, .emptyRecord,
    ]
    return findings.filter { !dismissed.contains($0.id) }.sorted {
      let a = order.firstIndex(of: $0.kind)!
      let b = order.firstIndex(of: $1.kind)!
      return a == b ? $0.title < $1.title : a < b
    }
  }
  /// Relationship labels that read the same in both directions. A mutual pair using any other
  /// label (A leads B and B leads A) is worth a second look; it is never rewritten.
  static let symmetricLabels: Set<String> = [
    "allied with", "allies", "ally of", "married to", "spouse of", "sibling of", "siblings",
    "twin of", "rival of", "rivals", "friend of", "friends with", "knows", "related to",
    "at war with", "enemy of", "enemies", "neighbor of", "neighbour of", "borders",
    "connected to", "linked to", "partner of", "partners with", "cousin of", "trades with",
    "opposes", "loves", "resembles",
  ]
  static func normalizedLabel(_ label: String) -> String {
    label.lowercased().split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
  }
  func relationshipFindings(_ relations: [Relation], records: [LoreRecord]) -> [WorldFinding] {
    let titles = Dictionary(records.map { ($0.id, $0.title) }, uniquingKeysWith: { a, _ in a })
    var findings: [WorldFinding] = []
    var seen: [String: Relation] = [:]
    var byPair: [String: [Relation]] = [:]
    for relation in relations {
      let label = Self.normalizedLabel(relation.label)
      let key = "\(relation.sourceID)|\(relation.targetID)|\(label)"
      if let first = seen[key] {
        let source = titles[relation.sourceID] ?? "A record"
        let target = titles[relation.targetID] ?? "a record"
        findings.append(
          WorldFinding(
            id: "relation-duplicate:\(first.id):\(relation.id)", kind: .conflictingRelationship,
            title: "\(source) “\(relation.label)” \(target) is recorded twice",
            detail: "Two identical relationships. Remove one from the record's Relationships.",
            recordIDs: [relation.sourceID, relation.targetID]))
      } else {
        seen[key] = relation
      }
      byPair["\(relation.sourceID)|\(relation.targetID)", default: []].append(relation)
    }
    var reported = Set<String>()
    for relation in relations {
      let label = Self.normalizedLabel(relation.label)
      guard !label.isEmpty, !Self.symmetricLabels.contains(label),
        relation.sourceID != relation.targetID
      else { continue }
      let reverse = byPair["\(relation.targetID)|\(relation.sourceID)"] ?? []
      guard reverse.contains(where: { Self.normalizedLabel($0.label) == label }) else { continue }
      let ids = [relation.sourceID, relation.targetID].sorted()
      let key = "relation-mutual:\(ids[0]):\(ids[1]):\(label)"
      guard reported.insert(key).inserted else { continue }
      let a = titles[relation.sourceID] ?? "A record"
      let b = titles[relation.targetID] ?? "a record"
      findings.append(
        WorldFinding(
          id: key, kind: .conflictingRelationship,
          title: "\(a) and \(b) each “\(relation.label)” the other",
          detail:
            "“\(relation.label)” usually runs one way. Keep both if that is intended; otherwise remove one direction.",
          recordIDs: [relation.sourceID, relation.targetID]))
    }
    return findings
  }
  /// A free-form date label reduced to a number and its era words, when it has exactly one
  /// number: "Year 120 AE" → (120, "year ae"). Anything else is not compared.
  static func comparableDate(_ label: String) -> (value: Double, era: String)? {
    let lower = label.lowercased()
    let numbers = lower.split(whereSeparator: { !($0.isNumber || $0 == "." || $0 == "-") })
      .filter { $0.contains(where: \.isNumber) }
    guard numbers.count == 1, var value = Double(numbers[0]) else { return nil }
    let words = lower.split(whereSeparator: { !$0.isLetter }).map(String.init)
    if words.contains(where: { ["bce", "bc", "before"].contains($0) }) { value = -value }
    let era = words.filter {
      !["year", "years", "the", "of", "in", "c", "circa", "about"].contains($0)
    }
    .joined(separator: " ")
    return (value, era)
  }
  func timelineFindings(
    _ events: [WorldEvent], placements: [String: String], lanes: [ChronologyLane]
  ) -> [WorldFinding] {
    // A period inherits its nearest branch. Keep archived ancestors in the lookup because
    // archive preserves their placements and children.
    let children = Dictionary(grouping: lanes, by: \.parentID)
    var branchByLane: [String: String] = [:]
    var pending = lanes.filter { $0.kind == "branch" }.map { (laneID: $0.id, branchID: $0.id) }
    while let entry = pending.popLast() {
      guard branchByLane[entry.laneID] == nil else { continue }
      branchByLane[entry.laneID] = entry.branchID
      for child in children[entry.laneID, default: []] where child.kind != "branch" {
        pending.append((laneID: child.id, branchID: entry.branchID))
      }
    }
    let ordered = events.filter { $0.order != nil }.sorted { $0.order! < $1.order! }
    var findings: [WorldFinding] = []
    var previous: [String?: (event: WorldEvent, date: (value: Double, era: String))] = [:]
    for event in ordered {
      guard let date = Self.comparableDate(event.dateLabel) else { continue }
      let branch = placements[event.id].flatMap { branchByLane[$0] }
      if let last = previous[branch], last.date.era == date.era, last.date.value > date.value {
        findings.append(
          WorldFinding(
            id: "timeline-order:\(last.event.id):\(event.id)", kind: .timelineOrder,
            title: "“\(event.title)” is placed after a later date",
            detail:
              "“\(last.event.title)” (\(last.event.dateLabel)) comes before “\(event.title)” (\(event.dateLabel)) in your Timeline order.",
            recordIDs: [last.event.sourceID, event.sourceID].filter { !$0.isEmpty }))
      }
      previous[branch] = (event, date)
    }
    return findings
  }
  /// Tags reduced to letters and digits, without a trailing plural "s".
  static func tagKey(_ tag: String) -> String {
    var key = tag.lowercased().filter { $0.isLetter || $0.isNumber }
    if key.count > 3, key.hasSuffix("s"), !key.hasSuffix("ss") { key.removeLast() }
    return key
  }
  func tagFindings(_ records: [LoreRecord]) -> [WorldFinding] {
    var spellings: [String: [String: Int]] = [:]
    for record in records {
      for tag in Set(record.tags ?? []) where !tag.isEmpty {
        spellings[Self.tagKey(tag), default: [:]][tag, default: 0] += 1
      }
    }
    return spellings.compactMap { key, variants in
      guard variants.count > 1, !key.isEmpty else { return nil }
      let ranked = variants.sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
      let names = ranked.map { "“\($0.key)” (\($0.value))" }.joined(separator: ", ")
      return WorldFinding(
        id: "tags:\(key):\(ranked.map(\.key).sorted().joined(separator: "|"))", kind: .tagVariant,
        title: "\(ranked.count) spellings of one tag",
        detail: "\(names). Merging uses “\(ranked[0].key)”.", recordIDs: [], value: ranked[0].key)
    }
  }
  /// Rewrites every spelling of a tag to `preferred` in one transaction. Each changed record gets a
  /// new revision; accepted canon is untouched and the record returns to draft until reviewed.
  /// Returns the IDs of the records that changed, so the caller can offer Undo.
  @discardableResult public func mergeTagVariants(worldID: String, preferred: String) throws
    -> [(id: String, tags: [String])]
  {
    let key = Self.tagKey(preferred)
    guard !key.isEmpty else { throw SynthesisError.invalid("Choose a tag to keep.") }
    return try db.transaction {
      var previous: [(id: String, tags: [String])] = []
      for record in try records(worldID: worldID) {
        let tags = record.tags ?? []
        guard tags.contains(where: { Self.tagKey($0) == key && $0 != preferred }) else { continue }
        var merged: [String] = []
        for tag in tags {
          let value = Self.tagKey(tag) == key ? preferred : tag
          if !merged.contains(value) { merged.append(value) }
        }
        _ = try saveMetadata(
          worldID: worldID, id: record.id, version: record.version, tags: merged,
          aliases: record.aliases ?? [])
        previous.append((record.id, tags))
      }
      return previous
    }
  }
  /// Puts back the tags `mergeTagVariants` replaced, as further revisions.
  public func restoreTags(worldID: String, previous: [(id: String, tags: [String])]) throws {
    try db.transaction {
      for item in previous {
        let record = try record(worldID: worldID, id: item.id)
        _ = try saveMetadata(
          worldID: worldID, id: record.id, version: record.version, tags: item.tags,
          aliases: record.aliases ?? [])
      }
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
