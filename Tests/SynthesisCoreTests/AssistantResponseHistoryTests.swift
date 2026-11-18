import Foundation
import Testing

@testable import SynthesisCore

@MainActor struct AssistantResponseHistoryTests {
  @Test func originalResponseKeepsLocalUsageAcrossReopenAndArchive() async throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    let path = folder.appendingPathComponent("workspace.sqlite").path
    let store = try WorkspaceStore(path: path)
    let world = try store.createWorld(name: "Tidekeepers")
    let other = try store.createWorld(name: "Far shore")
    let chat = try store.createConversation(worldID: world.id)
    let codex = try HarnessTests().script(
      """
      cat > /dev/null
      echo '{"type":"item.completed","item":{"type":"agent_message","text":"Keep a mirror in the lighthouse."}}'
      echo '{"type":"turn.completed","usage":{"input_tokens":514,"cached_input_tokens":300,"output_tokens":42}}'
      """)
    defer { try? FileManager.default.removeItem(at: codex.folder) }
    let engine = AgentEngine(store: store, transport: CodexTransport(executable: { codex.path }))
    try await engine.submit(
      worldID: world.id, conversationID: chat.id, prompt: "Find a motif", preset: "Create"
    ) { _ in }

    let reopened = try WorkspaceStore(path: path)
    let answer = try #require(
      try reopened.messages(worldID: world.id, conversationID: chat.id).last)
    let usage = try reopened.assistantResponseUsage(worldID: world.id, conversationID: chat.id)
    #expect(usage.count == 1)
    #expect(usage[answer.id]?.provider == .codex)
    #expect(usage[answer.id]?.inputTokens == 514)
    #expect(usage[answer.id]?.cacheReadInputTokens == 300)
    #expect(usage[answer.id]?.outputTokens == 42)
    #expect(usage[answer.id]?.cacheWriteInputTokens == nil)
    #expect(
      try reopened.assistantResponseUsage(worldID: other.id, conversationID: chat.id).isEmpty)

    let branch = try reopened.branchConversation(
      worldID: world.id, conversationID: chat.id, at: answer.id)
    #expect(
      try reopened.assistantResponseUsage(worldID: world.id, conversationID: branch.id).isEmpty)
    try reopened.setConversationArchived(worldID: world.id, id: chat.id, archived: true)
    #expect(
      try reopened.assistantResponseUsage(worldID: world.id, conversationID: chat.id) == usage)
    try reopened.setConversationArchived(worldID: world.id, id: chat.id, archived: false)
    #expect(
      try reopened.assistantResponseUsage(worldID: world.id, conversationID: chat.id) == usage)

    let portable = try reopened.exportWorldArchive(worldID: world.id)
    let raw = try JSONDecoder().decode(WorldArchive.self, from: portable)
    #expect(raw.tables["assistant_response_usage"] == nil)
    let copy = try reopened.importWorldArchive(portable)
    let copied = try #require(
      try reopened.conversations(worldID: copy.id).first { $0.title == "Find a motif" })
    #expect(
      try reopened.messages(worldID: copy.id, conversationID: copied.id).last?.body == answer.body)
    #expect(
      try reopened.assistantResponseUsage(worldID: copy.id, conversationID: copied.id).isEmpty)
    let json = String(decoding: try reopened.exportWorld(world.id), as: UTF8.self)
    #expect(!json.contains("assistant_response_usage"))
    #expect(!json.contains("cacheReadInputTokens"))
  }

  @Test func failedUsageWriteRollsBackCompletedReply() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Tidekeepers")
    let chat = try store.createConversation(worldID: world.id)
    try store.db.execute(
      """
      CREATE TRIGGER fail_response_usage BEFORE INSERT ON assistant_response_usage
      BEGIN SELECT RAISE(ABORT,'synthetic usage write failure'); END
      """)
    let usage = ModelTokenUsage(
      provider: .claudeCode, inputTokens: 31, outputTokens: 8,
      cacheReadInputTokens: 12, cacheWriteInputTokens: 4)
    #expect(throws: SynthesisError.self) {
      try store.appendAssistantResponse(
        worldID: world.id, conversationID: chat.id, body: "Use the lighthouse.", usage: usage)
    }
    #expect(try store.messages(worldID: world.id, conversationID: chat.id).isEmpty)
    #expect(try store.assistantResponseUsage(worldID: world.id, conversationID: chat.id).isEmpty)
  }
}
