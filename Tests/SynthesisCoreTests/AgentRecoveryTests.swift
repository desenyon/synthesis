import Foundation
import Testing

@testable import SynthesisCore

actor InterruptedTransport: ModelTransport {
  private(set) var started = false
  func generate(_ request: ModelRequest, onDelta: @escaping @Sendable (String) async -> Void)
    async throws -> String
  {
    await onDelta("A useful unfinished idea.\n```synthesis-proposal\n{\"changes\":[")
    started = true
    try await Task.sleep(for: .seconds(10))
    return "Never reached"
  }
}

@MainActor struct AgentRecoveryTests {
  @Test func malformedProposalRetainsProseAndReportsFailureWithoutStaging() async throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Malformed")
    let chat = try store.createConversation(worldID: world.id)
    let engine = AgentEngine(
      store: store,
      transport: ScriptedTransport(
        answer: "A direction to explore.\n```synthesis-proposal\n{not json}\n```"))
    await #expect(throws: (any Error).self) {
      try await engine.submit(
        worldID: world.id, conversationID: chat.id, prompt: "Explore", preset: "Create"
      ) { _ in }
    }
    let messages = try store.messages(worldID: world.id, conversationID: chat.id)
    #expect(messages.first(where: { $0.role == "assistant" })?.state == "interrupted")
    #expect(messages.first(where: { $0.role == "assistant" })?.body == "A direction to explore.")
    #expect(messages.last?.state == "error")
    #expect(try store.proposals(worldID: world.id).isEmpty)
    #expect(try store.records(worldID: world.id).isEmpty)
  }
  @Test func stopPreservesVisibleProseWithoutStagingIncompleteChanges() async throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Recovery")
    let chat = try store.createConversation(worldID: world.id)
    let transport = InterruptedTransport()
    let engine = AgentEngine(store: store, transport: transport)
    let task = Task {
      try await engine.submit(
        worldID: world.id, conversationID: chat.id, prompt: "Explore", preset: "Create"
      ) { _ in }
    }
    for _ in 0..<200 {
      if await transport.started { break }
      try await Task.sleep(for: .milliseconds(5))
    }
    #expect(await transport.started)
    engine.cancel()
    _ = await task.result
    let messages = try store.messages(worldID: world.id, conversationID: chat.id)
    #expect(messages.last?.body == "A useful unfinished idea.")
    #expect(messages.last?.state == "interrupted")
    #expect(try store.proposals(worldID: world.id).isEmpty)
    #expect(try store.records(worldID: world.id).isEmpty)
  }

  @Test func incompleteProposalFenceNeverFlashesMachineText() {
    for suffix in ["`", "``", "```s", "```synthesis-pro", "```synthesis-proposal\n{"] {
      #expect(ProposalParser.visible("Hello\n" + suffix) == "Hello")
    }
    #expect(
      ProposalParser.visible("A normal `inline code` example") == "A normal `inline code` example")
  }
}
