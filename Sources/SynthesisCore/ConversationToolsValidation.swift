import Foundation

extension WorkspaceStore {
  /// Imported conversation provenance is untrusted. Validate the entire lineage inside the
  /// import transaction, so a corrupt snapshot cannot manufacture source/approval relationships.
  func validateConversationTools(worldID: String) throws {
    _ = try world(worldID)
    let invalid = SynthesisError.invalid(
      "The world file contains inconsistent conversation branch history.")
    let conversationRows = try db.rows("SELECT id FROM conversations WHERE world_id=?", [worldID])
    guard conversationRows.allSatisfy({ UUID(uuidString: $0["id"] ?? "") != nil }) else {
      throw invalid
    }
    let conversations = Set(conversationRows.compactMap { $0["id"] })
    let messages = try db.rows("SELECT * FROM messages WHERE world_id=? ORDER BY rowid", [worldID])
    guard
      messages.allSatisfy({
        UUID(uuidString: $0["id"] ?? "") != nil
          && conversations.contains($0["conversation_id"] ?? "")
      })
    else { throw invalid }
    let messageMap = Dictionary(uniqueKeysWithValues: messages.map { ($0["id"]!, $0) })
    let byConversation = Dictionary(grouping: messages, by: { $0["conversation_id"]! })
    let branches = try db.rows("SELECT * FROM conversation_branches WHERE world_id=?", [worldID])
    guard
      branches.allSatisfy({
        UUID(uuidString: $0["conversation_id"] ?? "") != nil
          && UUID(uuidString: $0["parent_conversation_id"] ?? "") != nil
          && UUID(uuidString: $0["fork_message_id"] ?? "") != nil
      })
    else { throw invalid }
    let branchMap = Dictionary(uniqueKeysWithValues: branches.map { ($0["conversation_id"]!, $0) })
    let origins = try db.rows(
      "SELECT * FROM conversation_message_origins WHERE world_id=?", [worldID])
    guard
      origins.allSatisfy({
        UUID(uuidString: $0["message_id"] ?? "") != nil
          && UUID(uuidString: $0["source_message_id"] ?? "") != nil
      })
    else { throw invalid }
    let originMap = Dictionary(
      uniqueKeysWithValues: origins.map { ($0["message_id"]!, $0["source_message_id"]!) })
    let originCounts = Dictionary(
      grouping: origins, by: { messageMap[$0["message_id"] ?? ""]?["conversation_id"] ?? "" })
    for branch in branches {
      guard let child = branch["conversation_id"], let parent = branch["parent_conversation_id"],
        child != parent, conversations.contains(child), conversations.contains(parent),
        let forkID = branch["fork_message_id"], let fork = messageMap[forkID],
        fork["conversation_id"] == parent, ["user", "assistant"].contains(fork["role"] ?? ""),
        let source = byConversation[parent],
        let index = source.firstIndex(where: { $0["id"] == forkID }),
        let copied = byConversation[child], copied.count > index,
        originCounts[child]?.count == index + 1
      else { throw invalid }
      // A branch owns a complete, immutable snapshot of the prefix. Later messages have no
      // source mappings; nesting adds another trace step rather than rewriting the old one.
      for offset in 0...index {
        guard let copiedID = copied[offset]["id"], originMap[copiedID] == source[offset]["id"],
          copied[offset]["body"] == source[offset]["body"],
          copied[offset]["role"] == source[offset]["role"],
          copied[offset]["state"] == source[offset]["state"]
        else { throw invalid }
      }
    }
    for origin in origins {
      guard let id = origin["message_id"], let sourceID = origin["source_message_id"],
        id != sourceID,
        let message = messageMap[id], let source = messageMap[sourceID],
        let branch = branchMap[message["conversation_id"] ?? ""],
        source["conversation_id"] == branch["parent_conversation_id"]
      else { throw invalid }
    }
    try validateAcyclicConversationLinks(
      Dictionary(
        uniqueKeysWithValues: branches.map {
          ($0["conversation_id"]!, $0["parent_conversation_id"]!)
        }))
    try validateAcyclicConversationLinks(originMap)
    for row in try db.rows("SELECT * FROM prompt_recipes WHERE world_id=?", [worldID]) {
      guard UUID(uuidString: row["id"] ?? "") != nil,
        let title = row["title"], let instructions = row["instructions"],
        let mode = row["mode"],
        let version = Int(row["version"] ?? ""), version >= 1,
        ["0", "1"].contains(row["archived"] ?? "")
      else { throw SynthesisError.invalid("The world file contains an invalid prompt recipe.") }
      _ = try validateRecipe(title: title, instructions: instructions, mode: mode)
    }
  }

  private func validateAcyclicConversationLinks(_ links: [String: String]) throws {
    var checked = Set<String>()
    for start in links.keys where !checked.contains(start) {
      var path = Set<String>()
      var current = start
      while let next = links[current], !checked.contains(current) {
        guard path.insert(current).inserted else {
          throw SynthesisError.invalid("The world file contains a cycle in conversation lineage.")
        }
        current = next
      }
      checked.formUnion(path)
    }
  }
}
