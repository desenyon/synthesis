import Foundation

extension WorkspaceStore {
  /// Commit a completed answer and its optional local usage receipt together.
  func appendAssistantResponse(
    worldID: String, conversationID: String, body: String, usage: ModelTokenUsage?
  ) throws -> ChatMessage {
    try db.transaction {
      let response = try appendMessage(
        worldID: worldID, conversationID: conversationID, role: "assistant", body: body,
        state: "complete")
      if let usage {
        try db.execute(
          """
          INSERT INTO assistant_response_usage(
            message_id,provider,input_tokens,output_tokens,cache_read_input_tokens,cache_write_input_tokens
          ) VALUES(?,?,?,?,?,?)
          """,
          [
            response.id, usage.provider.rawValue, String(usage.inputTokens),
            String(usage.outputTokens), usage.cacheReadInputTokens.map { String($0) },
            usage.cacheWriteInputTokens.map { String($0) },
          ])
      }
      return response
    }
  }

  /// Local account-operation metadata stays with the original reply, including after archive.
  public func assistantResponseUsage(worldID: String, conversationID: String) throws
    -> [String: ModelTokenUsage]
  {
    let rows = try db.rows(
      """
      SELECT u.* FROM messages m JOIN assistant_response_usage u ON u.message_id=m.id
      WHERE m.world_id=? AND m.conversation_id=? AND m.role='assistant' AND m.state='complete'
      """, [worldID, conversationID])
    var usage: [String: ModelTokenUsage] = [:]
    for row in rows {
      guard let id = row["message_id"],
        let provider = row["provider"].flatMap(ProviderKind.init(rawValue:)),
        let input = row["input_tokens"].flatMap(Int.init),
        let output = row["output_tokens"].flatMap(Int.init)
      else { continue }
      usage[id] = ModelTokenUsage(
        provider: provider, inputTokens: input, outputTokens: output,
        cacheReadInputTokens: row["cache_read_input_tokens"].flatMap(Int.init),
        cacheWriteInputTokens: row["cache_write_input_tokens"].flatMap(Int.init))
    }
    return usage
  }

  /// Authored data for the isolated background capture. No transport or sign-in is used.
  public func assistantUsageCaptureConversation(worldID: String) throws -> Conversation {
    guard ProcessInfo.processInfo.environment["SYNTHESIS_CAPTURE_DIR"] != nil else {
      throw SynthesisError.invalid("Usage history fixtures require isolated capture.")
    }
    return try db.transaction {
      let title = "Usage at the lighthouse"
      if let existing = try conversations(worldID: worldID).first(where: { $0.title == title }) {
        return existing
      }
      let chat = try createConversation(worldID: worldID, title: title)
      _ = try appendMessage(
        worldID: worldID, conversationID: chat.id, role: "user",
        body: "What image could connect the two lighthouse scenes?", state: "complete")
      _ = try appendAssistantResponse(
        worldID: worldID, conversationID: chat.id,
        body: "Try a mirror that still reflects the horizon after the lantern goes dark.",
        usage: .init(
          provider: .codex, inputTokens: 514, outputTokens: 42, cacheReadInputTokens: 300,
          cacheWriteInputTokens: nil))
      return chat
    }
  }
}
