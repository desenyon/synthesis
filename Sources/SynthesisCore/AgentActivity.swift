import Foundation

/// Observed application operations, never a model-authored description of its reasoning.
public struct AgentActivity: Identifiable, Equatable, Sendable {
  public enum State: String, Sendable { case running, complete, failed, cancelled }
  public let id: String
  public var title: String
  public var detail: String
  public var state: State
  public var startedAt: Date
  public var endedAt: Date?

  public init(
    id: String, title: String, detail: String = "", state: State,
    startedAt: Date = Date(), endedAt: Date? = nil
  ) {
    self.id = id
    self.title = title
    self.detail = detail
    self.state = state
    self.startedAt = startedAt
    self.endedAt = endedAt
  }
}
