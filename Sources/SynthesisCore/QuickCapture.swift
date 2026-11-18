import CryptoKit
import Foundation

/// A recoverable scratch note. Capturing it never promotes content into canon.
public struct QuickCaptureDraft: Codable, Equatable, Sendable {
  public let id: String
  public var text: String

  public init(id: String = UUID().uuidString, text: String = "") {
    self.id = id
    self.text = text
  }
}

extension WorkspaceStore {
  public func quickCaptureDraft(worldID: String) throws -> QuickCaptureDraft {
    _ = try world(worldID)
    guard let value = try preference("quick-capture:\(worldID)"), !value.isEmpty else {
      return QuickCaptureDraft()
    }
    return try JSONDecoder().decode(QuickCaptureDraft.self, from: Data(value.utf8))
  }

  public func saveQuickCaptureDraft(worldID: String, draft: QuickCaptureDraft) throws {
    _ = try world(worldID)
    guard draft.text.count <= 200_000 else {
      throw SynthesisError.invalid("An idea can contain up to 200,000 characters.")
    }
    let value = String(decoding: try JSONEncoder().encode(draft), as: UTF8.self)
    try setPreference("quick-capture:\(worldID)", value: value)
  }

  /// The saved idea and scratch removal are one commit. A retry with the same draft identity
  /// returns its record, preventing a double-click or interrupted acknowledgment from duplicating it.
  public func commitQuickCapture(worldID: String, draft: QuickCaptureDraft) throws -> LoreRecord {
    _ = try world(worldID)
    let body = draft.text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !body.isEmpty, body.count <= 200_000, !draft.id.isEmpty else {
      throw SynthesisError.invalid("Write an idea of up to 200,000 characters before saving.")
    }
    return try db.transaction {
      // Two restored windows can share an identity while containing different edits. Include
      // the content so only an identical submission counts as a retry.
      let digest = SHA256.hash(data: Data(body.utf8)).map { String(format: "%02x", $0) }.joined()
      let receiptKey = "quick-capture-receipt:\(worldID):\(draft.id):\(digest)"
      let captured: LoreRecord
      if let recordID = try preference(receiptKey) {
        captured = try record(worldID: worldID, id: recordID)
      } else {
        let firstLine = body.split(whereSeparator: \.isNewline).first.map(String.init) ?? body
        let title = String(firstLine.prefix(70))
        captured = try createRecord(
          worldID: worldID, title: title, body: body, kind: "capture", category: "Ideas")
        try setPreference(receiptKey, value: captured.id)
      }
      // Do not erase a newer scratch draft if this is a delayed retry.
      if try quickCaptureDraft(worldID: worldID) == draft {
        try setPreference("quick-capture:\(worldID)", value: "")
      }
      return captured
    }
  }
}
