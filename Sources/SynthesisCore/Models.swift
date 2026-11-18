import Foundation

public enum WorkspaceMode: String, Codable, CaseIterable, Sendable { case assisted, manual }
public struct World: Identifiable, Codable, Hashable, Sendable {
  public var id: String
  public var name: String
  public var description: String
  public var demo: Bool
}
public struct LoreRecord: Identifiable, Codable, Equatable, Sendable {
  public var id: String
  public var worldID: String
  public var title: String
  public var body: String
  public var kind: String
  public var category: String
  public var state: String
  public var origin: String
  public var version: Int
  public var canonical: String?
  public var rtf: String?
  public var updatedAt: String
  public var tags: [String]?
  public var aliases: [String]?
}
public struct Conversation: Identifiable, Codable, Hashable, Sendable {
  public var id: String
  public var worldID: String
  public var title: String
  public var updatedAt: String
}
public struct ChatMessage: Identifiable, Codable, Equatable, Sendable {
  public var id: String
  public var worldID: String
  public var conversationID: String
  public var role: String
  public var body: String
  public var state: String
}
public struct RecordRevision: Identifiable, Codable, Sendable {
  public var id: String
  public var version: Int
  public var snapshot: LoreRecord
  public var createdAt: String
}
public struct Relation: Identifiable, Codable, Sendable {
  public var id: String
  public var sourceID: String
  public var targetID: String
  public var label: String
}
public struct WorldEvent: Identifiable, Codable, Sendable {
  public var id: String
  public var title: String
  public var dateLabel: String
  public var sourceID: String
  public var order: Int?
}
public struct Board: Identifiable, Codable, Equatable, Sendable {
  public var id: String
  public var name: String
  public var kind: String
  public var content: String
}
/// A record the assistant was given as context, and why it was chosen.
public struct ContextSource: Identifiable, Equatable, Sendable {
  public var record: LoreRecord
  public var reason: String
  public var id: String { record.id }
  public init(record: LoreRecord, reason: String) {
    self.record = record
    self.reason = reason
  }
}
/// One staged change inside an AI proposal. Nothing happens until the creator resolves it.
public struct ProposedChange: Identifiable, Codable, Equatable, Sendable {
  public var id: String
  /// `create_record`, `revise_record`, `relate` or `add_event`.
  public var action: String
  public var kind: String?
  public var title: String?
  public var category: String?
  public var body: String?
  /// Target of a revision.
  public var recordID: String?
  /// Version of the target when the change was proposed.
  public var baseVersion: Int?
  /// A record ID, or `change:<id>` for something created earlier in the same proposal.
  public var source: String?
  public var target: String?
  public var label: String?
  public var date: String?
  public var reason: String?
  public var evidence: [String]
  /// `pending`, `accepted` or `rejected`.
  public var status: String
  /// ID of the record, relationship or event an accepted change produced.
  public var resultID: String?
  /// Source record of an accepted event when it was created, before any reassignment.
  public var resultSourceID: String? = nil
  public var laneID: String? = nil
  public var endDate: String? = nil
  public var ruleBefore: WorldRule? = nil
  public var parentMapID: String? = nil
  public var componentScope: String? = nil
  public var boardID: String? = nil
  public var x: Double? = nil
  public var y: Double? = nil
  /// Reviewable domain metadata captured before a workspace edit. Never includes image bytes.
  public var workspaceBefore: [String: String]? = nil
}
public struct Proposal: Identifiable, Codable, Equatable, Sendable {
  public var id: String
  public var worldID: String
  public var conversationID: String?
  public var messageID: String?
  public var summary: String
  public var changes: [ProposedChange]
  public var state: String
  public var createdAt: String
  /// `ai-proposed`, or `branch-merge` for changes sent back from a creator's what-if branch.
  public var origin: String?
  public var isBranchMerge: Bool { origin == "branch-merge" }
  public var pending: Int { changes.filter { $0.status == "pending" }.count }
}
public enum SynthesisError: LocalizedError {
  case invalid(String)
  case notFound, stale, manualMode, unavailable
  case database(String)
  public var errorDescription: String? {
    switch self {
    case .invalid(let reason), .database(let reason): return reason
    case .notFound: return "This item could not be found in the selected world."
    case .stale:
      return
        "This document changed elsewhere. Your writing has been kept; reopen the latest version before saving."
    case .manualMode: return "AI is off in Manual mode. No content was sent."
    case .unavailable:
      return "Connect a model in Settings to continue. Your message has been saved."
    }
  }
}
public func timestamp() -> String { ISO8601DateFormatter().string(from: Date()) }
