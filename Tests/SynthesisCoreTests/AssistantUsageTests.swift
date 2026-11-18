import Foundation
import Testing

@testable import SynthesisCore

@MainActor struct AssistantUsageTests {
  @Test func localDailyLimitSurvivesReopenAndRejectsBeforeSavingOrGenerating() async throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: folder) }
    let path = folder.appendingPathComponent("workspace.sqlite").path
    let store = try WorkspaceStore(path: path)
    let world = try store.createWorld(name: "Tidekeepers")
    let chat = try store.createConversation(worldID: world.id)
    try store.setPreference("assistant-chat-daily-limit", value: "1")
    let firstTransport = CountingTransport()
    let engine = AgentEngine(store: store, transport: firstTransport)
    try engine.setMode(.manual)
    await #expect(throws: SynthesisError.self) {
      try await engine.submit(
        worldID: world.id, conversationID: chat.id, prompt: "Manual", preset: "Create"
      ) { _ in }
    }
    #expect(await firstTransport.calls == 0)
    try engine.setMode(.assisted)
    try await engine.submit(
      worldID: world.id, conversationID: chat.id, prompt: "First", preset: "Create"
    ) { _ in }
    #expect(await firstTransport.calls == 1)

    let reopened = try WorkspaceStore(path: path)
    let blockedTransport = CountingTransport()
    let reopenedEngine = AgentEngine(store: reopened, transport: blockedTransport)
    await #expect(throws: SynthesisError.self) {
      try await reopenedEngine.submit(
        worldID: world.id, conversationID: chat.id, prompt: "Second", preset: "Create"
      ) { _ in }
    }
    #expect(await blockedTransport.calls == 0)
    #expect(
      try reopened.messages(worldID: world.id, conversationID: chat.id).map(\.role) == [
        "user", "assistant",
      ])
  }

  @Test func usageResetsAtUTCMidnightAndFailedStorageDoesNotConsumeTheNextDay() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Tidekeepers")
    let chat = try store.createConversation(worldID: world.id)
    try store.setAssistantChatLimit(1)
    let lastSecond = Date(timeIntervalSince1970: 86_399)
    let midnight = Date(timeIntervalSince1970: 86_400)
    try store.admitAssistantMessage(
      worldID: world.id, conversationID: chat.id, prompt: "First day", firstMessage: true,
      at: lastSecond)
    #expect(try store.assistantChatBudget(at: lastSecond).submitted == 1)
    #expect(try store.assistantChatBudget(at: midnight).submitted == 0)
    #expect(throws: SynthesisError.self) {
      try store.admitAssistantMessage(
        worldID: world.id, conversationID: UUID().uuidString, prompt: "Missing chat",
        firstMessage: false, at: midnight)
    }
    #expect(try store.assistantChatBudget(at: midnight).submitted == 0)
    try store.admitAssistantMessage(
      worldID: world.id, conversationID: chat.id, prompt: "New day", firstMessage: false,
      at: midnight)
    #expect(try store.assistantChatBudget(at: midnight).submitted == 1)
  }

  @Test func archivedConversationNeverConsumesBudgetOrInvokesTheTransport() async throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Tidekeepers")
    let chat = try store.createConversation(worldID: world.id)
    try store.setConversationArchived(worldID: world.id, id: chat.id, archived: true)
    let transport = CountingTransport()
    let engine = AgentEngine(store: store, transport: transport)
    await #expect(throws: SynthesisError.self) {
      try await engine.submit(
        worldID: world.id, conversationID: chat.id, prompt: "Explore", preset: "Create"
      ) { _ in }
    }
    #expect(await transport.calls == 0)
    #expect(try store.assistantChatBudget().submitted == 0)
    #expect(try store.messages(worldID: world.id, conversationID: chat.id).isEmpty)
  }

  @Test func providerReportedTokensReachActivityThroughTheRouterWithoutApplyingProposals()
    async throws
  {
    let harnesses = HarnessTests()
    let claude = try harnesses.script(
      """
      cat > /dev/null
      echo '{"type":"result","subtype":"success","is_error":false,"result":"What if the sea were a mirror?","total_cost_usd":0.13,"usage":{"input_tokens":31,"output_tokens":8,"cache_read_input_tokens":12,"cache_creation_input_tokens":4}}'
      """)
    defer { try? FileManager.default.removeItem(at: claude.folder) }
    let codex = try harnesses.script(
      """
      cat > /dev/null
      echo '{"type":"item.completed","item":{"type":"agent_message","text":"Keep a mirror in the lighthouse."}}'
      echo '{"type":"turn.completed","usage":{"input_tokens":514,"cached_input_tokens":300,"output_tokens":42}}'
      """)
    defer { try? FileManager.default.removeItem(at: codex.folder) }
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Tidekeepers")
    let chat = try store.createConversation(worldID: world.id)
    for (provider, expected) in [(ProviderKind.codex, "514 input"), (.claudeCode, "31 input")] {
      let engine = AgentEngine(
        store: store,
        transport: ProviderRouter(
          kind: { provider }, claude: ClaudeCodeTransport(executable: { claude.path }),
          codex: CodexTransport(executable: { codex.path })))
      var detail = ""
      try await engine.submit(
        worldID: world.id, conversationID: chat.id, prompt: "Expand", preset: "Create",
        onActivity: { if $0.id == "response", $0.state == .complete { detail = $0.detail } },
        onDelta: { _ in })
      #expect(detail.contains(expected))
      #expect(detail.contains(provider == .codex ? "42 output" : "8 output"))
      #expect(detail.contains(provider == .codex ? "300 cache read" : "12 cache read"))
      #expect(detail.contains("Subscription cost unavailable"))
      #expect(!detail.contains("0.13"))
    }
    #expect(try store.records(worldID: world.id).isEmpty)
    #expect(try store.proposals(worldID: world.id).isEmpty)
  }

  @Test func missingAndInvalidTokenFieldsAreUnavailableRatherThanZero() async throws {
    let codex = try HarnessTests().script(
      """
      cat > /dev/null
      echo '{"type":"item.completed","item":{"type":"agent_message","text":"A lantern at sea."}}'
      echo '{"type":"turn.completed","usage":{"input_tokens":30,"output_tokens":12}}'
      echo '{"type":"turn.completed","usage":{"input_tokens":true,"output_tokens":-1}}'
      """)
    defer { try? FileManager.default.removeItem(at: codex.folder) }
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Tidekeepers")
    let chat = try store.createConversation(worldID: world.id)
    for transport: any ModelTransport in [
      CodexTransport(executable: { codex.path }),
      ScriptedTransport(answer: "A lantern in the harbor."),
    ] {
      let engine = AgentEngine(store: store, transport: transport)
      var detail = ""
      try await engine.submit(
        worldID: world.id, conversationID: chat.id, prompt: "Expand", preset: "Create",
        onActivity: { if $0.id == "response", $0.state == .complete { detail = $0.detail } },
        onDelta: { _ in })
      #expect(detail == "Token counts unavailable. Subscription cost unavailable.")
    }
  }
}
