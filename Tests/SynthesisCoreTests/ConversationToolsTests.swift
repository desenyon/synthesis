import Foundation
import Testing

@testable import SynthesisCore

struct ConversationToolsTests {
  @Test func branchExcerptPreservesBlockBoundariesAndTrimsRenderedText() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Excerpt study")
    let original = try store.createConversation(worldID: world.id)
    let passage = String(repeating: "north ", count: 28)
    let reply = try store.appendMessage(
      worldID: world.id, conversationID: original.id, role: "assistant",
      body: "### Crossing\n\nFirst passage.\n\n**\(passage)wind**", state: "complete")
    let branch = try store.branchConversation(
      worldID: world.id, conversationID: original.id, at: reply.id)
    let lineage = try #require(
      try store.conversationBranch(worldID: world.id, conversationID: branch.id))
    #expect(lineage.forkExcerpt.hasPrefix("Crossing First passage. north"))
    #expect(!lineage.forkExcerpt.contains("**"))
    #expect(lineage.forkExcerpt.count <= 180)
  }

  @Test func branchCopiesOnlyTheSelectedPrefixAndKeepsSourceReferences() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Branch study")
    var lore = try store.createRecord(worldID: world.id, title: "One moon", body: "A single moon")
    lore = try store.promote(
      worldID: world.id, id: lore.id, version: lore.version, confirmation: lore.id)
    let original = try store.createConversation(worldID: world.id, title: "Moon alternatives")
    let user = try store.appendMessage(
      worldID: world.id, conversationID: original.id,
      role: "user", body: "What if the moon vanished?", state: "complete")
    let answer = try store.appendMessage(
      worldID: world.id, conversationID: original.id,
      role: "assistant", body: "An authored alternative.", state: "imported-example")
    try store.saveMessageContext(
      worldID: world.id, messageID: answer.id,
      sources: [ContextSource(record: lore, reason: "Selected lore")])
    let proposal = try #require(
      try store.stageProposal(
        worldID: world.id,
        conversationID: original.id, messageID: answer.id,
        payload: ["changes": [["action": "revise_record", "id": lore.id, "body": "No moon"]]]))
    try store.appendMessage(
      worldID: world.id, conversationID: original.id,
      role: "user", body: "A later direction", state: "complete")
    let branch = try store.branchConversation(
      worldID: world.id,
      conversationID: original.id, at: answer.id)
    let copied = try store.messages(worldID: world.id, conversationID: branch.id)
    #expect(copied.map(\.body) == [user.body, answer.body])
    #expect(copied.map(\.state) == ["complete", "imported-example"])
    #expect(!copied.contains { $0.id == user.id || $0.id == answer.id })
    #expect(try store.messages(worldID: world.id, conversationID: original.id).count == 3)
    let lineage = try #require(
      try store.conversationBranch(worldID: world.id, conversationID: branch.id))
    #expect(lineage.parentConversationID == original.id && lineage.forkMessageID == answer.id)
    #expect(
      try store.messageOrigins(worldID: world.id, conversationID: branch.id)[copied[1].id]
        == answer.id)
    #expect(
      try store.messageContext(worldID: world.id, conversationID: branch.id)[copied[1].id]?.first?
        .record.id == lore.id)
    #expect(try store.record(worldID: world.id, id: lore.id) == lore)
    #expect(
      try store.db.rows("SELECT id FROM proposals WHERE conversation_id=?", [branch.id]).isEmpty)
    #expect(try store.proposal(worldID: world.id, id: proposal.id).pending == 1)
    let revised = try store.saveRecord(
      worldID: world.id, id: lore.id, version: lore.version,
      title: lore.title, body: "A single silver moon", rtf: nil)
    #expect(
      try store.messageContext(worldID: world.id, conversationID: branch.id)[copied[1].id]?.first?
        .record == revised)
    #expect(revised.canonical == lore.canonical)
    let nested = try store.branchConversation(
      worldID: world.id, conversationID: branch.id, at: copied[0].id)
    #expect(try store.messages(worldID: world.id, conversationID: nested.id).count == 1)
    #expect(
      try store.conversationBranches(worldID: world.id, parentConversationID: original.id).map(
        \.conversationID) == [branch.id])
    try store.validateConversationTools(worldID: world.id)
  }

  @Test func branchRejectsForeignSystemAndArchivedForksWithoutPartialWrites() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let a = try store.createWorld(name: "A")
    let b = try store.createWorld(name: "B")
    let first = try store.createConversation(worldID: a.id)
    let other = try store.createConversation(worldID: a.id)
    let message = try store.appendMessage(
      worldID: a.id, conversationID: first.id,
      role: "user", body: "Original", state: "complete")
    let system = try store.appendMessage(
      worldID: a.id, conversationID: first.id,
      role: "system", body: "Connection failed", state: "error")
    #expect(throws: Error.self) {
      try store.branchConversation(worldID: b.id, conversationID: first.id, at: message.id)
    }
    #expect(throws: Error.self) {
      try store.branchConversation(worldID: a.id, conversationID: other.id, at: message.id)
    }
    #expect(throws: Error.self) {
      try store.branchConversation(worldID: a.id, conversationID: first.id, at: system.id)
    }
    try store.setConversationArchived(worldID: a.id, id: first.id, archived: true)
    #expect(throws: Error.self) {
      try store.branchConversation(worldID: a.id, conversationID: first.id, at: message.id)
    }
    try store.setConversationArchived(worldID: a.id, id: first.id, archived: false)
    #expect(try store.conversations(worldID: a.id).count == 2)
    #expect(try store.conversations(worldID: b.id).isEmpty)
  }

  @Test func recipesPersistValidateAndArchiveWithOptimisticUndo() throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    let path = folder.appendingPathComponent("study.sqlite").path
    let store = try WorkspaceStore(path: path)
    let a = try store.createWorld(name: "A")
    let b = try store.createWorld(name: "B")
    let recipe = try store.createPromptRecipe(
      worldID: a.id, title: " Political tension ",
      instructions: "Compare the competing organizations. Cite established lore.", mode: "Critique")
    #expect(recipe.title == "Political tension" && recipe.version == 1)
    #expect(throws: Error.self) { try store.promptRecipe(worldID: b.id, id: recipe.id) }
    #expect(try store.promptRecipes(worldID: b.id).isEmpty)
    #expect(throws: Error.self) {
      try store.createPromptRecipe(
        worldID: a.id, title: "Empty", instructions: " \n", mode: "Create")
    }
    #expect(throws: Error.self) {
      try store.createPromptRecipe(
        worldID: a.id, title: "Bad mode", instructions: "Test", mode: "Approve canon")
    }
    let updated = try store.updatePromptRecipe(
      worldID: a.id, id: recipe.id, version: recipe.version,
      title: recipe.title, instructions: "Explore motives without rewriting canon.", mode: "Develop"
    )
    #expect(throws: Error.self) {
      try store.updatePromptRecipe(
        worldID: a.id, id: recipe.id, version: 1,
        title: "Stale", instructions: "Lost update", mode: "Create")
    }
    let archived = try store.setPromptRecipeArchived(
      worldID: a.id, id: recipe.id, version: updated.version, archived: true)
    #expect(try store.promptRecipes(worldID: a.id).isEmpty)
    #expect(try store.promptRecipes(worldID: a.id, archived: true).first == archived)
    let restored = try store.setPromptRecipeArchived(
      worldID: a.id, id: recipe.id, version: archived.version, archived: false)
    let reopened = try WorkspaceStore(path: path)
    #expect(try reopened.promptRecipe(worldID: a.id, id: recipe.id) == restored)
    #expect(try reopened.promptRecipes(worldID: a.id, query: "motives").map(\.id) == [recipe.id])
    #expect(try reopened.promptRecipes(worldID: a.id, query: "unrelated").isEmpty)
  }

  @Test func branchesAndRecipesRoundTripWithRemappedLineageAndRejectCorruptArchives() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Portable writing")
    let original = try store.createConversation(worldID: world.id, title: "Original")
    let message = try store.appendMessage(
      worldID: world.id, conversationID: original.id,
      role: "user", body: "A different history", state: "complete")
    let child = try store.branchConversation(
      worldID: world.id, conversationID: original.id, at: message.id, title: "Alternative")
    let unreferenced = try store.appendMessage(
      worldID: world.id, conversationID: original.id,
      role: "user", body: "A later message with no incoming source pointers", state: "complete")
    let recipe = try store.createPromptRecipe(
      worldID: world.id, title: "Historical analysis",
      instructions: "Compare established accounts and identify uncertainties.", mode: "Critique")
    try store.setConversationArchived(worldID: world.id, id: original.id, archived: true)
    let bytes = try store.exportWorldArchive(worldID: world.id)
    let imported = try store.importWorldArchive(bytes)
    let importedChild = try #require(
      try store.conversations(worldID: imported.id).first { $0.title == "Alternative" })
    let lineage = try #require(
      try store.conversationBranch(worldID: imported.id, conversationID: importedChild.id))
    #expect(
      lineage.parentArchived && lineage.parentConversationID != original.id
        && lineage.forkMessageID != message.id)
    #expect(importedChild.id != child.id)
    #expect(
      try store.promptRecipes(worldID: imported.id).first?.instructions == recipe.instructions)
    #expect(try store.promptRecipes(worldID: imported.id).first?.id != recipe.id)
    try store.validateConversationTools(worldID: imported.id)
    var malformed = try JSONDecoder().decode(WorldArchive.self, from: bytes)
    malformed.tables["conversation_branches"]?[0]["parent_conversation_id"] = child.id
    #expect(throws: Error.self) { try store.importWorldArchive(JSONEncoder().encode(malformed)) }
    malformed = try JSONDecoder().decode(WorldArchive.self, from: bytes)
    malformed.tables["prompt_recipes"]?[0]["instructions"] = "  \n"
    #expect(throws: Error.self) { try store.importWorldArchive(JSONEncoder().encode(malformed)) }
    malformed = try JSONDecoder().decode(WorldArchive.self, from: bytes)
    let copiedMessageID = malformed.tables["conversation_message_origins"]?[0]["message_id"]
    malformed.tables["conversation_message_origins"]?[0]["source_message_id"] = copiedMessageID
    #expect(throws: Error.self) { try store.importWorldArchive(JSONEncoder().encode(malformed)) }
    malformed = try JSONDecoder().decode(WorldArchive.self, from: bytes)
    let index = try #require(
      malformed.tables["messages"]?.firstIndex { $0["id"] == unreferenced.id })
    malformed.tables["messages"]?[index].removeValue(forKey: "id")
    #expect(throws: Error.self) { try store.importWorldArchive(JSONEncoder().encode(malformed)) }
    #expect(try store.worlds().count == 2)
  }

  @Test func legacyNullPrimaryKeysAreRejectedWithoutTrapping() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Malformed legacy storage")
    let conversation = try store.createConversation(worldID: world.id)
    try store.db.execute(
      "INSERT INTO messages(id,world_id,conversation_id,role,body,state,created_at,updated_at) VALUES(NULL,?,?,'user','No identity','complete',?,?)",
      [world.id, conversation.id, timestamp(), timestamp()])
    #expect(throws: Error.self) { try store.validateConversationTools(worldID: world.id) }
  }
}
