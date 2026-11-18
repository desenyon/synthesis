import Foundation

/// A world-owned address. References never contain copied lore, image bytes or approval authority.
public struct WorldReference: Codable, Equatable, Hashable, Sendable {
  public enum Kind: String, Codable, CaseIterable, Sendable {
    case record, event, board, artwork, atlasImage, canvasImage, proposal
  }
  public var version = 1
  public let worldID: String
  public let kind: Kind
  public let id: String
  public let containerID: String?

  public init(worldID: String, kind: Kind, id: String, containerID: String? = nil) {
    self.worldID = worldID
    self.kind = kind
    self.id = id
    self.containerID = containerID
  }

  public var url: URL {
    var components = URLComponents()
    components.scheme = "synthesis"
    components.host = "reference"
    components.path = "/\(kind.rawValue)/\(id)"
    components.queryItems = [URLQueryItem(name: "world", value: worldID)]
    if let containerID {
      components.queryItems?.append(.init(name: "container", value: containerID))
    }
    return components.url!
  }

  public static func decode(_ data: Data) throws -> Self {
    guard data.count <= 4096 else { throw SynthesisError.invalid("This reference is too large.") }
    let value = try JSONDecoder().decode(Self.self, from: data)
    try value.validate()
    return value
  }

  public init(url: URL) throws {
    guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
      components.scheme == "synthesis", components.host == "reference",
      components.user == nil, components.password == nil, components.port == nil,
      components.fragment == nil
    else { throw SynthesisError.invalid("This is not a Synthesis reference.") }
    let path = components.path.split(separator: "/", omittingEmptySubsequences: true)
    let query = components.queryItems ?? []
    guard path.count == 2, let kind = Kind(rawValue: String(path[0])),
      query.filter({ $0.name == "world" }).count == 1,
      query.filter({ $0.name == "container" }).count <= 1,
      query.allSatisfy({ ["world", "container"].contains($0.name) }),
      let world = query.first(where: { $0.name == "world" })?.value
    else { throw SynthesisError.invalid("This reference has an invalid address.") }
    self.init(
      worldID: world, kind: kind, id: String(path[1]),
      containerID: query.first(where: { $0.name == "container" })?.value)
    try validate()
  }

  public func validate() throws {
    func valid(_ value: String) -> Bool {
      !value.isEmpty && value.utf8.count <= 128
        && value.unicodeScalars.allSatisfy {
          CharacterSet.alphanumerics.contains($0) || "-_".unicodeScalars.contains($0)
        }
    }
    guard version == 1, valid(worldID), valid(id), containerID.map(valid) ?? true,
      (kind == .canvasImage) == (containerID != nil)
    else { throw SynthesisError.invalid("This reference has an invalid address.") }
  }
}

public struct WorldReferenceSource: Equatable, Sendable {
  public let reference: WorldReference
  public let title: String
  public let detail: String
  public let excerpt: String
  public let state: String
  public let recordIDs: [String]
  public let boardKind: String?
  let originRecordIDs: [String]

  /// Previously shared context can make a proposal sensitive without being a new attachment.
  public var exclusionRecordIDs: [String] { recordIDs + originRecordIDs }

  public var markdown: String { Self.markdown(title: title, url: reference.url) }

  static func markdown(title: String, url: URL) -> String {
    let label = title.replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "[", with: "\\[")
      .replacingOccurrences(of: "]", with: "\\]")
      .replacingOccurrences(of: "\n", with: " ")
      .replacingOccurrences(of: "\r", with: " ")
    return "[\(label)](\(url.absoluteString))"
  }
}

extension WorkspaceStore {
  /// Resolve at delivery/open time, never trusting a drag preview or a prior universe selection.
  public func resolveReference(_ reference: WorldReference, worldID: String) throws
    -> WorldReferenceSource
  {
    try reference.validate()
    guard reference.worldID == worldID else {
      throw SynthesisError.invalid("References can only be used inside their own universe.")
    }
    _ = try world(worldID)
    func result(
      _ title: String, _ detail: String, _ excerpt: String = "", _ state: String = "draft",
      records: [String] = [], boardKind: String? = nil, originRecords: [String] = []
    ) -> WorldReferenceSource {
      WorldReferenceSource(
        reference: reference, title: title, detail: detail, excerpt: String(excerpt.prefix(4000)),
        state: state, recordIDs: records, boardKind: boardKind, originRecordIDs: originRecords)
    }
    func activeRecord(_ id: String) throws -> LoreRecord {
      guard try !isArchived(worldID: worldID, recordID: id) else { throw SynthesisError.notFound }
      return try record(worldID: worldID, id: id)
    }
    switch reference.kind {
    case .record:
      let record = try activeRecord(reference.id)
      return result(
        record.title, record.kind == "entity" ? record.category : "Source", record.body,
        record.state, records: [record.id])
    case .event:
      guard let event = try events(worldID: worldID).first(where: { $0.id == reference.id }) else {
        throw SynthesisError.notFound
      }
      let source = try activeRecord(event.sourceID)
      return result(
        event.title, "Event · \(event.dateLabel)", source.body, "draft", records: [source.id])
    case .artwork:
      guard
        let row = try db.rows(
          "SELECT a.record_id,a.origin FROM record_artwork a JOIN records r ON r.id=a.record_id AND r.world_id=a.world_id WHERE a.world_id=? AND a.id=? AND a.archived=0 AND r.archived=0",
          [worldID, reference.id]
        ).first, let recordID = row["record_id"]
      else { throw SynthesisError.notFound }
      let record = try activeRecord(recordID)
      return result(
        "Artwork · \(record.title)", "Image · \(row["origin"] ?? "imported")",
        "Visual reference for \(record.title).", "reference", records: [record.id])
    case .proposal:
      let proposal = try proposal(worldID: worldID, id: reference.id)
      let pending = proposal.changes.filter { $0.status == "pending" }
      // Keep provenance IDs even for archived records so a saved exclusion still applies.
      let known = Set(
        try db.rows("SELECT id FROM records WHERE world_id=?", [worldID]).compactMap { $0["id"] })
      let eventSources: [String: String] = Dictionary(
        uniqueKeysWithValues:
          try db.rows("SELECT id,source_id FROM events WHERE world_id=?", [worldID]).compactMap {
            row in
            guard let id = row["id"], let source = row["source_id"] else { return nil }
            return (id, source)
          })
      let linked = Set(
        proposal.changes.flatMap { change -> [String] in
          var dependencies =
            change.evidence
            + [
              change.recordID, change.source, change.target, change.resultID, change.resultSourceID,
              change.workspaceBefore?["source"], change.workspaceBefore?["target"],
              change.ruleBefore?.systemID,
            ].compactMap { $0 }
          // Older accepted events have only a result ID. Include the current owner on both
          // old and new proposals, even after event or source archival.
          if change.action == "add_event", let result = change.resultID,
            let source = eventSources[result]
          {
            dependencies.append(source)
          }
          return dependencies
        }
      ).intersection(known)
      let originRecords: [String]
      if let messageID = proposal.messageID {
        originRecords = try db.rows(
          "SELECT record_id FROM message_context WHERE world_id=? AND message_id=? ORDER BY position",
          [worldID, messageID]
        ).compactMap { $0["record_id"] }.filter(known.contains)
      } else {
        originRecords = []
      }
      let descriptions = proposal.changes.map {
        "\($0.status): \($0.action) · \($0.title ?? $0.label ?? "Change"). \($0.reason ?? "") \(String(($0.body ?? "").prefix(1000)))"
      }.joined(separator: "\n")
      return result(
        proposal.summary, "Proposal · \(pending.count) pending",
        "Proposed changes, not established lore.\n\(descriptions)", "proposal",
        records: linked.sorted(), originRecords: originRecords)
    case .board, .atlasImage, .canvasImage:
      let id = reference.containerID ?? reference.id
      let kinds = reference.kind == .atlasImage ? ["atlas"] : ["canvas", "atlas"]
      let available = try kinds.flatMap { try boards(worldID: worldID, kind: $0) }
      guard let board = available.first(where: { $0.id == id }) else {
        throw SynthesisError.notFound
      }
      if reference.kind == .board {
        return result(board.name, board.kind == "atlas" ? "Atlas" : "Canvas", boardKind: board.kind)
      }
      guard
        let object = try JSONSerialization.jsonObject(with: Data(board.content.utf8))
          as? [String: Any]
      else { throw SynthesisError.notFound }
      if reference.kind == .atlasImage {
        guard let image = object["image"] as? String, !image.isEmpty else {
          throw SynthesisError.notFound
        }
        return result(
          "Map · \(board.name)", "Atlas image", "Map image in \(board.name).", "reference",
          boardKind: "atlas")
      }
      guard board.kind == "canvas",
        let scene = object["scene"] as? [String: Any],
        let elements = scene["elements"] as? [[String: Any]],
        let image = elements.first(where: {
          $0["id"] as? String == reference.id && $0["type"] as? String == "image"
            && $0["isDeleted"] as? Bool != true
        }), let fileID = image["fileId"] as? String,
        let files = scene["files"] as? [String: Any], files[fileID] != nil
      else { throw SynthesisError.notFound }
      return result(
        "Image · \(board.name)", "Canvas image", "Image on \(board.name).", "reference",
        boardKind: "canvas")
    }
  }

  /// Extract bounded addresses for local use. Submissions check overflow explicitly.
  public static func worldReferences(in text: String) -> [WorldReference] {
    uniqueWorldReferences(in: text, limit: referenceScanLimit)
  }

  static func requestWorldReferences(in text: String) throws -> [WorldReference] {
    let references = uniqueWorldReferences(in: text, limit: referenceScanLimit + 1)
    guard references.count <= referenceScanLimit else {
      throw SynthesisError.invalid(
        "Use up to \(referenceScanLimit) distinct references per request.")
    }
    return references
  }

  /// App-created inline references include a source label. Filter the entire link when its
  /// source is excluded, retaining the surrounding prose and original local message.
  static func assistantPrompt(
    _ text: String, excluding references: Set<WorldReference>, excludingRecordIDs: Set<String>,
    approvedRecords: [String: LoreRecord]? = nil
  ) -> String {
    guard !references.isEmpty || !excludingRecordIDs.isEmpty || approvedRecords != nil else {
      return text
    }
    let hidden = "[Excluded source]"
    let replacements = referenceLinks(in: text).compactMap { link -> (NSRange, String)? in
      let recordID: String
      if let reference = try? WorldReference(url: link.url) {
        if references.contains(reference) { return (link.range, hidden) }
        guard reference.kind == .record else { return nil }
        recordID = reference.id
      } else if link.url.host == "record" {
        recordID = link.url.lastPathComponent
      } else {
        return approvedRecords == nil ? nil : (link.range, hidden)
      }
      if excludingRecordIDs.contains(recordID) { return (link.range, hidden) }
      guard let approvedRecords else { return nil }
      guard let record = approvedRecords[recordID] else { return (link.range, hidden) }
      return (link.range, WorldReferenceSource.markdown(title: record.title, url: link.url))
    }
    let result = NSMutableString(string: text)
    for (range, replacement) in replacements.reversed() {
      result.replaceCharacters(in: range, with: replacement)
    }
    return result as String
  }

  private static let referenceScanLimit = 64
  private static let referenceAddressPattern =
    #"synthesis://(?:reference/[^\s<>()\[\]]+|record/[\p{L}\p{N}-]+)"#
  private static let referenceLinkPattern = try? NSRegularExpression(
    pattern: #"\[(?:\\[\s\S]|[^\[\]\\])*\]\((\#(referenceAddressPattern))\)"#
      + #"|(\#(referenceAddressPattern))"#)

  private static func referenceLinks(in text: String) -> [(url: URL, range: NSRange)] {
    let source = text as NSString
    let range = NSRange(location: 0, length: source.length)
    return (referenceLinkPattern?.matches(in: text, range: range) ?? []).compactMap { match in
      let inlineAddress = match.range(at: 1)
      let address = inlineAddress.location == NSNotFound ? match.range(at: 2) : inlineAddress
      guard let url = URL(string: source.substring(with: address)) else { return nil }
      return (url, match.range)
    }
  }

  private static func uniqueWorldReferences(in text: String, limit: Int) -> [WorldReference] {
    var seen = Set<WorldReference>()
    var references: [WorldReference] = []
    for (url, _) in referenceLinks(in: text) {
      guard let reference = try? WorldReference(url: url), seen.insert(reference).inserted else {
        continue
      }
      references.append(reference)
      if references.count == limit { break }
    }
    return references
  }
}
