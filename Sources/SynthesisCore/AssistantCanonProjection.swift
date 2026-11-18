import Foundation

extension WorkspaceStore {
  /// Uses the full accepted snapshot and omits records with missing or inconsistent canon data.
  public static func assistantAcceptedRecords(_ records: [LoreRecord]) -> [LoreRecord] {
    assistantAcceptedRecords(records, preservingRichText: false)
  }

  static func assistantAcceptedRecords(_ records: [LoreRecord], preservingRichText: Bool)
    -> [LoreRecord]
  {
    let decoder = JSONDecoder()
    let accepted: [LoreRecord] = records.compactMap { record in
      guard let json = record.canonical,
        var snapshot = try? decoder.decode(LoreRecord.self, from: Data(json.utf8)),
        snapshot.id == record.id, snapshot.worldID == record.worldID,
        snapshot.kind == record.kind, ["entity", "lore"].contains(snapshot.kind),
        ["idea", "draft", "canon", "hypothetical"].contains(snapshot.state),
        snapshot.version > 0, snapshot.version < record.version
      else { return nil }
      // A snapshot captures the revision before the approval, including its previous state.
      snapshot.state = "canon"
      snapshot.canonical = nil
      if !preservingRichText { snapshot.rtf = nil }
      return snapshot
    }
    return accepted.sorted {
      $0.updatedAt == $1.updatedAt ? $0.id < $1.id : $0.updatedAt > $1.updatedAt
    }
  }

  /// Index only the already-filtered accepted projection, with cited records at the front.
  static func assistantAcceptedContextIndex(
    _ projected: [LoreRecord], prioritizedIDs: [String]
  ) throws -> String {
    let byID = Dictionary(projected.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    var shown = Set<String>()
    let candidates = prioritizedIDs.compactMap { byID[$0] } + projected
    let summaries = candidates.filter { shown.insert($0.id).inserted }.prefix(100).map {
      [
        "id": $0.id, "title": String($0.title.unicodeScalars.prefix(160)), "kind": $0.kind,
        "state": $0.state,
      ]
    }
    let index: [String: Any] = ["records": summaries, "totals": ["records": byID.count]]
    return String(
      decoding: try JSONSerialization.data(withJSONObject: index, options: [.sortedKeys]),
      as: UTF8.self)
  }

  /// Rank against the accepted excerpts. The working document index is outside this scope.
  static func assistantAcceptedSources(
    _ projected: [LoreRecord], prompt: String, limit: Int
  ) -> [ContextSource] {
    guard limit > 0 else { return [] }
    let plain = prompt.replacingOccurrences(
      of: #"synthesis://(?:record|reference)/[^\s\)\]]+"#, with: " ", options: .regularExpression)
    var seen = Set<String>()
    let terms = plain.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted)
      .filter { $0.count >= 3 && !stopwords.contains($0) && seen.insert($0).inserted }.prefix(12)
    let scored = projected.enumerated().map { position, record in
      let text = String(record.body.unicodeScalars.prefix(6000))
      let context =
        ([record.title, record.category, text] + (record.tags ?? []) + (record.aliases ?? []))
        .joined(separator: " ").lowercased()
      let matches = terms.filter { context.contains($0) }.count
      return (position: position, record: record, matches: matches)
    }
    return scored.sorted {
      $0.matches == $1.matches ? $0.position < $1.position : $0.matches > $1.matches
    }.prefix(limit).map {
      let reason = $0.matches > 0 ? "Matches accepted lore" : "Accepted canon"
      return ContextSource(record: $0.record, reason: reason)
    }
  }
}
