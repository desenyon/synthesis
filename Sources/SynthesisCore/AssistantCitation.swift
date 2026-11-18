import Foundation

/// A passage of the accepted prose at a specific approval revision. The address is local and
/// portable with the message. A cited passage supplies evidence for review, not canon authority.
public struct AssistantCitation: Hashable, Identifiable, Sendable {
  public let worldID: String
  public let recordID: String
  public let approvalVersion: Int
  public let passage: Int
  private static let prefix = "synthesis://citation/"
  private static let markerPrefix = "[[accepted-passage:"
  private static let markerPattern = try! NSRegularExpression(
    pattern: #"\[\[accepted-passage:([^\]\r\n]{1,160})\]\]"#)
  private static let requestPattern = try! NSRegularExpression(
    pattern: #"\[\[cite:([0-9]{1,8})\]\]"#)
  private static let passageLimit = 24
  static let excerptLimit = 6000

  public var id: String { "\(Self.prefix)\(worldID)/\(recordID)/\(approvalVersion)/\(passage)" }
  var marker: String { "\(Self.markerPrefix)\(id)]]" }

  init(worldID: String, recordID: String, approvalVersion: Int, passage: Int) {
    self.worldID = worldID
    self.recordID = recordID
    self.approvalVersion = approvalVersion
    self.passage = passage
  }

  public init?(url: URL) {
    let value = url.absoluteString
    guard value.hasPrefix(Self.prefix), value.utf8.count <= 160 else { return nil }
    let components = value.dropFirst(Self.prefix.count).split(separator: "/")
    guard components.count == 4, UUID(uuidString: String(components[0])) != nil,
      UUID(uuidString: String(components[1])) != nil,
      let version = Int(components[2]), version > 1,
      let passage = Int(components[3]), (0..<Self.passageLimit).contains(passage)
    else { return nil }
    self.init(
      worldID: String(components[0]), recordID: String(components[1]), approvalVersion: version,
      passage: passage)
    guard id == value else { return nil }
  }

  /// Resolve only storage markers, never a raw model-supplied Markdown URL.
  public static func addresses(in body: String) -> [Self] {
    let text = body as NSString
    return markerPattern.matches(in: body, range: NSRange(location: 0, length: text.length))
      .compactMap { match in
        URL(string: text.substring(with: match.range(at: 1))).flatMap(Self.init(url:))
      }
  }

  public static func markdown(_ body: String, forDraft: Bool = false) -> String {
    replacing(body, with: markerPattern) { match in
      guard let url = URL(string: match), let address = Self(url: url) else {
        return "(Source unavailable)"
      }
      // Drafts keep an ordinary navigable record reference in the existing rich-text codec.
      return forDraft
        ? "[Source record](synthesis://record/\(address.recordID))"
        : "[Accepted passage](\(address.id))"
    }
  }

  static func passages(in body: String) -> [String] {
    let bounded = String(body.prefix(excerptLimit))
    let paragraphs = bounded.components(separatedBy: "\n\n")
    guard paragraphs.count > passageLimit else { return paragraphs }
    return Array(paragraphs.prefix(passageLimit - 1))
      + [paragraphs.dropFirst(passageLimit - 1).joined(separator: "\n\n")]
  }

  /// Remove older or fabricated storage markers before handling the current request's numbers.
  static func response(_ text: String, addresses: [Self], isStreaming: Bool = false) -> String {
    let untrusted = replacing(text, with: markerPattern) { _ in "(Source unavailable)" }
      .replacingOccurrences(
        of: prefix, with: "synthesis://unavailable-citation/", options: .caseInsensitive)
    return replacing(untrusted, with: requestPattern) { number in
      guard let index = Int(number), index > 0, addresses.indices.contains(index - 1) else {
        return "(Source unavailable)"
      }
      return isStreaming ? "(Accepted passage)" : addresses[index - 1].marker
    }
  }

  private static func replacing(
    _ text: String, with pattern: NSRegularExpression, transform: (String) -> String
  ) -> String {
    let value = NSMutableString(string: text)
    let matches = pattern.matches(in: text, range: NSRange(location: 0, length: value.length))
    for match in matches.reversed() {
      let argument = value.substring(with: match.range(at: 1))
      value.replaceCharacters(in: match.range, with: transform(argument))
    }
    return value as String
  }
}

public struct AssistantCitationPassage: Identifiable, Sendable {
  public let address: AssistantCitation
  public let title: String
  public let text: String
  public var id: String { address.id }
}

extension WorkspaceStore {
  func acceptedCitationExcerpt(_ accepted: LoreRecord, addresses: inout [AssistantCitation])
    -> String
  {
    let fallback = String(accepted.body.prefix(AssistantCitation.excerptLimit))
    guard !fallback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      UUID(uuidString: accepted.id) != nil, UUID(uuidString: accepted.worldID) != nil,
      accepted.version < Int.max,
      let stored = try? assistantCitationSnapshot(
        worldID: accepted.worldID, recordID: accepted.id, version: accepted.version + 1),
      stored.body.utf8.elementsEqual(accepted.body.utf8), stored.title == accepted.title,
      stored.rtf == accepted.rtf
    else { return fallback }
    return AssistantCitation.passages(in: stored.body).enumerated().map { index, text in
      guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return text }
      addresses.append(
        AssistantCitation(
          worldID: accepted.worldID, recordID: accepted.id, approvalVersion: accepted.version + 1,
          passage: index))
      return "[[cite:\(addresses.count)]] \(text)"
    }.joined(separator: "\n\n")
  }

  public func resolveAssistantCitation(_ address: AssistantCitation, worldID: String) throws
    -> AssistantCitationPassage
  {
    guard address.worldID == worldID,
      try !isArchived(worldID: worldID, recordID: address.recordID)
    else { throw SynthesisError.notFound }
    let snapshot = try assistantCitationSnapshot(
      worldID: worldID, recordID: address.recordID, version: address.approvalVersion)
    let passages = AssistantCitation.passages(in: snapshot.body)
    guard passages.indices.contains(address.passage),
      !passages[address.passage].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else { throw SynthesisError.notFound }
    return AssistantCitationPassage(
      address: address, title: snapshot.title, text: passages[address.passage])
  }

  private func assistantCitationSnapshot(worldID: String, recordID: String, version: Int) throws
    -> LoreRecord
  {
    let payload = try db.rows(
      """
      SELECT h.snapshot FROM native_revisions h
      JOIN records r ON r.id=h.record_id AND r.world_id=h.world_id
      WHERE h.world_id=? AND h.record_id=? AND h.version=? AND r.archived=0
      """, [worldID, recordID, String(version)]
    ).first?["snapshot"]
    guard let payload, version > 1,
      let approval = try? JSONDecoder().decode(LoreRecord.self, from: Data(payload.utf8)),
      approval.id == recordID, approval.worldID == worldID, approval.version == version,
      approval.state == "canon",
      let accepted = Self.assistantAcceptedRecords([approval], preservingRichText: true).first,
      accepted.version == version - 1
    else { throw SynthesisError.notFound }
    return accepted
  }
}
