import CoreFoundation
import Foundation

/// Counts reported by a completed harness operation. They are not subscription usage units.
public struct ModelTokenUsage: Equatable, Sendable {
  public let provider: ProviderKind
  public let inputTokens: Int
  public let outputTokens: Int
  public let cacheReadInputTokens: Int?
  public let cacheWriteInputTokens: Int?

  public var detail: String {
    var fields = ["\(inputTokens) input", "\(outputTokens) output"]
    if let cacheReadInputTokens { fields.append("\(cacheReadInputTokens) cache read") }
    if let cacheWriteInputTokens { fields.append("\(cacheWriteInputTokens) cache write") }
    return "Reported tokens · " + fields.joined(separator: " · ")
  }

  static func reported(in event: [String: Any]?, provider: ProviderKind) -> ModelTokenUsage? {
    let terminal = provider == .codex ? "turn.completed" : "result"
    guard event?["type"] as? String == terminal,
      let usage = event?["usage"] as? [String: Any]
    else { return nil }
    func count(_ key: String) -> Int? {
      guard let number = usage[key] as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID(),
        let count = number as? Int, count >= 0
      else { return nil }
      return count
    }
    guard let input = count("input_tokens"), let output = count("output_tokens") else { return nil }
    return ModelTokenUsage(
      provider: provider, inputTokens: input, outputTokens: output,
      cacheReadInputTokens: count(
        provider == .codex ? "cached_input_tokens" : "cache_read_input_tokens"),
      cacheWriteInputTokens: count(
        provider == .codex ? "cache_write_input_tokens" : "cache_creation_input_tokens"))
  }
}

public struct ModelGenerationResult: Sendable {
  public let text: String
  public let usage: ModelTokenUsage?
}

public struct AssistantChatBudget: Equatable, Sendable {
  public static let choices = [0, 1, 5, 10, 25, 50, 100, 250, 500]
  /// Zero means unlimited local chat submissions.
  public let limit: Int
  public let submitted: Int

  public func requireAvailableSubmission() throws {
    guard limit == 0 || submitted < limit else {
      throw SynthesisError.invalid(
        "Daily chat limit reached. It resets at midnight UTC. Your message is still in the composer."
      )
    }
  }
}

extension WorkspaceStore {
  public func assistantChatBudget(at date: Date = .now) throws -> AssistantChatBudget {
    let rows = try db.rows(
      """
      SELECT key,value FROM preferences
      WHERE key IN ('assistant-chat-daily-limit','assistant-chat-usage-day','assistant-chat-usage-count')
      """)
    var values: [String: String] = [:]
    for row in rows {
      if let key = row["key"] { values[key] = row["value"] }
    }
    let rawLimit = values["assistant-chat-daily-limit"] ?? "0"
    guard let limit = Int(rawLimit), AssistantChatBudget.choices.contains(limit) else {
      throw SynthesisError.invalid("Open Assistant settings and choose a valid daily chat limit.")
    }
    let storedDay = values["assistant-chat-usage-day"]
    guard storedDay == Self.chatUsageDay(date) else {
      return AssistantChatBudget(limit: limit, submitted: 0)
    }
    guard let rawCount = values["assistant-chat-usage-count"],
      let submitted = Int(rawCount),
      submitted >= 0
    else { throw SynthesisError.invalid("The daily chat count could not be read.") }
    return AssistantChatBudget(limit: limit, submitted: submitted)
  }

  public func setAssistantChatLimit(_ limit: Int) throws {
    guard AssistantChatBudget.choices.contains(limit) else {
      throw SynthesisError.invalid("Choose one of the available daily chat limits.")
    }
    try setPreference("assistant-chat-daily-limit", value: String(limit))
  }

  /// Count locally admitted chat submissions, including attempts that later fail or stop.
  /// Keep the tally and saved user message in the same transaction across app instances.
  func admitAssistantMessage(
    worldID: String, conversationID: String, prompt: String, firstMessage: Bool,
    at date: Date? = nil
  ) throws {
    try db.transaction {
      let date = date ?? .now
      guard try preference("mode") != "manual" else { throw SynthesisError.manualMode }
      guard
        try db.rows(
          "SELECT id FROM conversations WHERE id=? AND world_id=? AND archived=0",
          [conversationID, worldID]
        ).first != nil
      else { throw SynthesisError.notFound }
      let budget = try assistantChatBudget(at: date)
      try budget.requireAvailableSubmission()
      try appendMessage(
        worldID: worldID, conversationID: conversationID, role: "user", body: prompt,
        state: "complete")
      if firstMessage {
        try renameConversation(
          worldID: worldID, id: conversationID, title: String(prompt.prefix(64)))
      }
      try setPreference("assistant-chat-usage-day", value: Self.chatUsageDay(date))
      try setPreference(
        "assistant-chat-usage-count", value: String(min(budget.submitted, Int.max - 1) + 1))
    }
  }

  private static func chatUsageDay(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withFullDate]
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    return formatter.string(from: date)
  }
}
