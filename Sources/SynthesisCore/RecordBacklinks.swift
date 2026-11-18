import AppKit
import Foundation

/// Separate saved explicit links and lexical mentions. One record can have both.
public struct RecordBacklinks: Equatable, Sendable {
  public internal(set) var linked: [LoreRecord] = []
  public internal(set) var mentioned: [LoreRecord] = []
}

extension WorkspaceStore {
  /// A consistent local snapshot of incoming links and whole-name text matches in one world.
  public func recordBacklinks(worldID: String, recordID: String) throws -> RecordBacklinks {
    try db.transaction(immediate: false) {
      let target = try record(worldID: worldID, id: recordID)
      guard try !isArchived(worldID: worldID, recordID: recordID) else {
        throw SynthesisError.notFound
      }
      let historicalNames = try db.rows(
        "SELECT name FROM entity_name_periods WHERE world_id=? AND record_id=? AND archived=0",
        [worldID, recordID]
      ).compactMap { $0["name"] }
      let names = Set(
        ([target.title] + (target.aliases ?? []) + historicalNames).map {
          $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }.filter { !$0.isEmpty })
      var result = RecordBacklinks()
      try db.forEachRow(
        """
        SELECT source.id,source.body,d.rtf,link.source_id AS linked
        FROM records source
        LEFT JOIN links link ON link.world_id=source.world_id
          AND link.source_id=source.id AND link.target_id=?
        LEFT JOIN rich_documents d ON d.record_id=source.id
        WHERE source.world_id=? AND source.id<>? AND source.archived=0
          AND (source.body<>'' OR link.source_id IS NOT NULL)
        ORDER BY source.updated_at DESC,source.rowid DESC
        """, [recordID, worldID, recordID]
      ) { row in
        try Task.checkCancellation()
        guard let id = row["id"], let body = row["body"] else { return }
        let text = RecordTextReferences(body, rtf: row["rtf"], worldID: worldID)
        let linked = row["linked"] != nil || text.recordIDs.contains(recordID)
        let mentioned = text.mentions(names)
        guard linked || mentioned else { return }
        let source = try record(worldID: worldID, id: id)
        if linked { result.linked.append(source) }
        if mentioned { result.mentioned.append(source) }
      }
      return result
    }
  }

  /// The Inspector reads from a separate connection, leaving large local scans off the UI thread.
  @MainActor public func loadRecordBacklinks(worldID: String, recordID: String) async throws
    -> RecordBacklinks
  {
    let path = db.path
    if path == ":memory:" { return try recordBacklinks(worldID: worldID, recordID: recordID) }
    let read = Task.detached(priority: .utility) {
      try Task.checkCancellation()
      let reader = WorkspaceStore(database: try Database(path: path, openExisting: true))
      return try reader.recordBacklinks(worldID: worldID, recordID: recordID)
    }
    return try await withTaskCancellationHandler {
      try await read.value
    } onCancel: {
      read.cancel()
    }
  }
}

/// Discard app link labels before matching plain text, including native rich-text links.
struct RecordTextReferences {
  let recordIDs: Set<String>
  private let prose: String

  init(_ text: String, rtf: String? = nil, worldID: String) {
    var records = Set<String>()
    func add(_ url: URL) {
      if let reference = try? WorldReference(url: url) {
        if reference.worldID == worldID && reference.kind == .record {
          records.insert(reference.id)
        }
      } else if url.scheme == "synthesis", url.host == "record",
        url.pathComponents.count == 2
      {
        records.insert(url.lastPathComponent)
      }
    }
    let plain = NSMutableString(string: text)
    if let rich = MarkdownText.richBody(text, rtf: rtf) {
      var nativeLinkRanges: [NSRange] = []
      rich.enumerateAttribute(.link, in: NSRange(location: 0, length: rich.length)) {
        value, range, _ in
        let url = (value as? URL) ?? (value as? String).flatMap { URL(string: $0) }
        guard let url, url.scheme == "synthesis" else { return }
        add(url)
        nativeLinkRanges.append(range)
      }
      for range in nativeLinkRanges.reversed() { plain.replaceCharacters(in: range, with: " ") }
    }
    if plain.contains("synthesis://") {
      for link in WorkspaceStore.referenceLinks(in: plain as String).reversed() {
        add(link.url)
        plain.replaceCharacters(in: link.range, with: " ")
      }
    }
    recordIDs = records
    prose = (plain as String).lowercased()
  }

  func mentions(_ names: Set<String>) -> Bool {
    names.contains { name in
      var search = prose.startIndex..<prose.endIndex
      while let range = prose.range(of: name, range: search) {
        let before =
          range.lowerBound == prose.startIndex ? nil : prose[prose.index(before: range.lowerBound)]
        let after = range.upperBound == prose.endIndex ? nil : prose[range.upperBound]
        if !(before.map { $0.isLetter || $0.isNumber } ?? false),
          !(after.map { $0.isLetter || $0.isNumber } ?? false)
        {
          return true
        }
        // Titles and aliases can overlap with the next occurrence.
        search = prose.index(after: range.lowerBound)..<prose.endIndex
      }
      return false
    }
  }
}
