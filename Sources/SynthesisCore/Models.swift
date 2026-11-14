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
  public var state: String? = nil
}
public struct WorldEvent: Identifiable, Codable, Sendable {
  public var id: String
  public var title: String
  public var dateLabel: String
  public var sourceID: String
  public var order: Int?
}
public struct Board: Identifiable, Codable, Sendable {
  public var id: String
  public var name: String
  public var kind: String
  public var content: String
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
