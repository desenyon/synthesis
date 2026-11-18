import Foundation

/// A fork records its exact source message. The original remains independently editable.
public struct ConversationBranch: Identifiable, Codable, Equatable, Sendable {
  public var conversationID: String
  public var worldID: String
  public var title: String
  public var parentConversationID: String
  public var parentTitle: String
  public var forkMessageID: String
  public var forkExcerpt: String
  public var parentArchived: Bool
  public var archived: Bool
  public var createdAt: String
  public var id: String { conversationID }
}

extension WorkspaceStore {
  /// Snapshot the prefix, including the selected message, with new stable IDs. Future writes
  /// cannot alter the source thread. Copied text is historical discussion, not established lore.
  public func branchConversation(
    worldID: String, conversationID: String, at messageID: String, title: String? = nil
  ) throws -> Conversation {
    try db.transaction {
      let history = try messages(worldID: worldID, conversationID: conversationID)
      guard
        let original = try conversations(worldID: worldID).first(where: { $0.id == conversationID }
        ),
        let point = history.firstIndex(where: { $0.id == messageID }),
        ["user", "assistant"].contains(history[point].role)
      else {
        throw SynthesisError.invalid(
          "Choose a user or assistant message in an active conversation.")
      }
      let name =
        title?.trimmingCharacters(in: .whitespacesAndNewlines)
        ?? String(original.title.prefix(109)) + " · Branch"
      guard !name.isEmpty, name.count <= 120 else {
        throw SynthesisError.invalid("Give this branch a name of 1–120 characters.")
      }
      let branch = try createConversation(worldID: worldID, title: name)
      let now = timestamp()
      for message in history[...point] {
        // Avoid appendMessage's repeated full-history load when copying a long conversation.
        let copiedID = UUID().uuidString
        try db.execute(
          "INSERT INTO messages(id,world_id,conversation_id,role,body,state,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?)",
          [copiedID, worldID, branch.id, message.role, message.body, message.state, now, now])
        try db.execute(
          "INSERT INTO conversation_message_origins(message_id,world_id,source_message_id,created_at) VALUES(?,?,?,?)",
          [copiedID, worldID, message.id, now])
        // Keep source pointers, including archived records, without copying stale lore snapshots.
        try db.execute(
          "INSERT INTO message_context(message_id,world_id,record_id,reason,position) SELECT ?,c.world_id,c.record_id,c.reason,c.position FROM message_context c JOIN records r ON r.id=c.record_id AND r.world_id=c.world_id WHERE c.message_id=? AND c.world_id=?",
          [copiedID, message.id, worldID])
      }
      try db.execute(
        "INSERT INTO conversation_branches(conversation_id,world_id,parent_conversation_id,fork_message_id,created_at) VALUES(?,?,?,?,?)",
        [branch.id, worldID, conversationID, messageID, now])
      // Proposals deliberately remain owned by the original response: an alternative discussion
      // must not manufacture a second way to apply the same canon-affecting change.
      return branch
    }
  }

  public func conversationBranch(worldID: String, conversationID: String) throws
    -> ConversationBranch?
  {
    _ = try messages(worldID: worldID, conversationID: conversationID)
    return try branchRows(worldID: worldID, clause: "b.conversation_id=?", value: conversationID)
      .first
  }

  public func conversationBranches(worldID: String, parentConversationID: String) throws
    -> [ConversationBranch]
  {
    _ = try messages(worldID: worldID, conversationID: parentConversationID)
    return try branchRows(
      worldID: worldID, clause: "b.parent_conversation_id=?", value: parentConversationID)
  }

  /// One step of lineage for each inherited message; nested branches remain traceable.
  public func messageOrigins(worldID: String, conversationID: String) throws -> [String: String] {
    _ = try messages(worldID: worldID, conversationID: conversationID)
    let rows = try db.rows(
      "SELECT o.message_id,o.source_message_id FROM conversation_message_origins o JOIN messages m ON m.id=o.message_id AND m.world_id=o.world_id JOIN messages s ON s.id=o.source_message_id AND s.world_id=o.world_id WHERE o.world_id=? AND m.conversation_id=?",
      [worldID, conversationID])
    return Dictionary(
      uniqueKeysWithValues: rows.map { ($0["message_id"]!, $0["source_message_id"]!) })
  }

  private func branchRows(worldID: String, clause: String, value: String) throws
    -> [ConversationBranch]
  {
    try db.rows(
      "SELECT b.*,c.title,c.archived,p.title AS parent_title,p.archived AS parent_archived,m.body AS fork_body FROM conversation_branches b JOIN conversations c ON c.id=b.conversation_id AND c.world_id=b.world_id JOIN conversations p ON p.id=b.parent_conversation_id AND p.world_id=b.world_id JOIN messages m ON m.id=b.fork_message_id AND m.conversation_id=p.id AND m.world_id=b.world_id WHERE b.world_id=? AND \(clause) ORDER BY c.updated_at DESC,c.rowid DESC",
      [worldID, value]
    ).map {
      ConversationBranch(
        conversationID: $0["conversation_id"]!, worldID: worldID, title: $0["title"]!,
        parentConversationID: $0["parent_conversation_id"]!, parentTitle: $0["parent_title"]!,
        forkMessageID: $0["fork_message_id"]!,
        forkExcerpt: branchExcerpt($0["fork_body"] ?? ""),
        parentArchived: $0["parent_archived"] == "1", archived: $0["archived"] == "1",
        createdAt: $0["created_at"]!)
    }
  }

  private func branchExcerpt(_ body: String) -> String {
    let plain: String
    if let markdown = try? AttributedString(markdown: body) {
      var blocks: [String] = []
      var current = ""
      var intent: PresentationIntent?
      for run in markdown.runs {
        if run.presentationIntent != intent {
          if !current.isEmpty { blocks.append(current) }
          current = ""
          intent = run.presentationIntent
        }
        current += String(markdown[run.range].characters)
      }
      blocks.append(current)
      plain = blocks.joined(separator: " ")
    } else {
      plain = body
    }
    return String(plain.split(whereSeparator: \.isWhitespace).joined(separator: " ").prefix(180))
  }
}
