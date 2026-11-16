import Foundation

/// World-scoped context selection for a conversation turn. The assistant only ever sees what
/// this returns, and the same list is stored with the answer so the creator can inspect it.
extension WorkspaceStore {
  static let stopwords: Set<String> = [
    "the", "and", "for", "that", "this", "with", "from", "have", "what", "when", "where", "who",
    "why", "how", "are", "was", "were", "will", "would", "could", "should", "about", "into",
    "their", "there", "them", "they", "then", "than", "her", "his", "she", "him", "you", "your",
    "our", "its", "not", "but", "can", "does", "did", "has", "had", "any", "all", "some", "more",
    "want", "make", "tell", "give", "help", "keep", "both", "without", "might", "which",
  ]
  /// IDs referenced as `synthesis://record/<id>` links in a piece of text.
  public static func referencedRecordIDs(in text: String) -> [String] {
    var ids: [String] = []
    var rest = Substring(text)
    while let range = rest.range(of: "synthesis://record/") {
      let tail = rest[range.upperBound...]
      let id = tail.prefix { $0.isLetter || $0.isNumber || $0 == "-" }
      if !id.isEmpty, !ids.contains(String(id)) { ids.append(String(id)) }
      rest = tail.dropFirst(id.count)
    }
    return ids
  }
  /// Records to share with the model for `prompt`, most relevant first:
  /// explicit references, full-text matches, their graph and link neighbours, then recent work.
  public func contextRecords(worldID: String, prompt: String, limit: Int = 16) throws
    -> [ContextSource]
  {
    let all = try records(worldID: worldID)
    guard !all.isEmpty else { return [] }
    let byID = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
    var result: [ContextSource] = []
    func add(_ id: String, _ reason: String) {
      guard result.count < limit, let record = byID[id], !result.contains(where: { $0.id == id })
      else { return }
      result.append(ContextSource(record: record, reason: reason))
    }
    for id in Self.referencedRecordIDs(in: prompt) { add(id, "You referenced it") }
    // Referenced entity sections precede incidental search/recent matches. Each is a cited
    // record with its own draft/canon state, never injected as part of the parent's canon.
    for anchor in result.map(\.record) {
      if anchor.kind == "entity" {
        for section in try recordSections(worldID: worldID, parentID: anchor.id) {
          add(section.record.id, "Section of \(anchor.title)")
        }
      } else if let parent = try sectionParent(worldID: worldID, recordID: anchor.id) {
        add(parent.id, "Parent entity")
      }
    }
    let plain = prompt.replacingOccurrences(
      of: #"\]\(synthesis://record/[^)]*\)"#, with: " ", options: .regularExpression)
    let tokens = plain.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted)
      .filter { $0.count >= 3 && !Self.stopwords.contains($0) }
    var seen = Set<String>()
    let terms = tokens.filter { seen.insert($0).inserted }.prefix(12)
    if !terms.isEmpty {
      let match = terms.map { "\"\($0)\"*" }.joined(separator: " OR ")
      let rows = try db.rows(
        "SELECT id FROM records_fts WHERE records_fts MATCH ? AND world_id=? AND id IN (SELECT id FROM records WHERE world_id=? AND archived=0) ORDER BY rank LIMIT 8",
        [match, worldID, worldID])
      for row in rows { add(row["id"]!, "Matches your message") }
    }
    let anchors = result.map(\.id)
    if !anchors.isEmpty {
      for relation in try relations(worldID: worldID) {
        if anchors.contains(relation.sourceID), let name = byID[relation.sourceID]?.title {
          add(relation.targetID, "Related to \(name)")
        } else if anchors.contains(relation.targetID), let name = byID[relation.targetID]?.title {
          add(relation.sourceID, "Related to \(name)")
        }
      }
      for anchor in anchors.prefix(4) {
        guard let name = byID[anchor]?.title else { continue }
        for linked in try linkedRecords(worldID: worldID, id: anchor) {
          add(linked.id, "Linked from \(name)")
        }
      }
    }
    for record in all { add(record.id, "Recent work") }
    return result
  }
  public func saveMessageContext(worldID: String, messageID: String, sources: [ContextSource])
    throws
  {
    _ = try world(worldID)
    try db.transaction {
      for (position, source) in sources.enumerated() {
        try db.execute(
          "INSERT OR REPLACE INTO message_context VALUES(?,?,?,?,?)",
          [messageID, worldID, source.record.id, source.reason, String(position)])
      }
    }
  }
  /// Context recorded for each assistant message in a conversation, keyed by message ID.
  /// Archived records are omitted; the stored row remains for the audit trail and export.
  public func messageContext(worldID: String, conversationID: String) throws
    -> [String: [ContextSource]]
  {
    let ids = try messages(worldID: worldID, conversationID: conversationID).map(\.id)
    guard !ids.isEmpty else { return [:] }
    let byID = Dictionary(uniqueKeysWithValues: try records(worldID: worldID).map { ($0.id, $0) })
    var result: [String: [ContextSource]] = [:]
    for row in try db.rows(
      "SELECT * FROM message_context WHERE world_id=? ORDER BY message_id,position", [worldID])
    where ids.contains(row["message_id"]!) {
      if let record = byID[row["record_id"]!] {
        result[row["message_id"]!, default: []].append(
          ContextSource(record: record, reason: row["reason"]!))
      }
    }
    return result
  }
}
