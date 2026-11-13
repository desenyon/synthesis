import Foundation
import Testing

@testable import SynthesisCore

actor CountingTransport: ModelTransport {
  var calls = 0
  let delayed: Bool
  init(delayed: Bool = false) { self.delayed = delayed }
  func generate(_ request: ModelRequest, onDelta: @escaping @Sendable (String) async -> Void)
    async throws -> String
  {
    calls += 1
    if delayed { try await Task.sleep(for: .seconds(30)) }
    await onDelta("A possible idea")
    return "A possible idea"
  }
}
@MainActor struct AgentTests {
  @Test func manualModeBlocksTransportAtCoreBoundary() async throws {
    let s = try WorkspaceStore(path: ":memory:")
    let w = try s.createWorld(name: "A")
    let c = try s.createConversation(worldID: w.id)
    let transport = CountingTransport()
    let engine = AgentEngine(store: s, transport: transport)
    try engine.setMode(.manual)
    await #expect(throws: Error.self) {
      try await engine.submit(
        worldID: w.id, conversationID: c.id, prompt: "Hello", preset: "Create"
      ) { _ in }
    }
    #expect(await transport.calls == 0)
    #expect(try s.messages(worldID: w.id, conversationID: c.id).isEmpty)
  }
  @Test func switchingToManualCancelsInFlightAndDoesNotPersistAssistant() async throws {
    let s = try WorkspaceStore(path: ":memory:")
    let w = try s.createWorld(name: "A")
    let c = try s.createConversation(worldID: w.id)
    let transport = CountingTransport(delayed: true)
    let engine = AgentEngine(store: s, transport: transport)
    let task = Task {
      try await engine.submit(
        worldID: w.id, conversationID: c.id, prompt: "Hello", preset: "Develop"
      ) { _ in }
    }
    while await transport.calls == 0 { await Task.yield() }
    try engine.setMode(.manual)
    do {
      try await task.value
      Issue.record("Request should be cancelled")
    } catch {}
    #expect(
      try s.messages(worldID: w.id, conversationID: c.id).filter { $0.role == "assistant" }.isEmpty)
    #expect(try s.preference("mode") == "manual")
  }
  @Test func responsesPersistWithoutChangingCanon() async throws {
    let s = try WorkspaceStore(path: ":memory:")
    let w = try s.createWorld(name: "A")
    let c = try s.createConversation(worldID: w.id)
    let r = try s.createRecord(worldID: w.id, title: "Rule", body: "One moon")
    let engine = AgentEngine(store: s, transport: CountingTransport())
    try await engine.submit(worldID: w.id, conversationID: c.id, prompt: "Expand", preset: "Create")
    { _ in }
    #expect(
      try s.messages(worldID: w.id, conversationID: c.id).map(\.role) == ["user", "assistant"])
    #expect(try s.record(worldID: w.id, id: r.id).canonical == nil)
  }
  @Test func cancellationBeforeQueuedSubmitNeverStartsTransport() async throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "A")
    let conversation = try store.createConversation(worldID: world.id)
    let transport = CountingTransport()
    let engine = AgentEngine(store: store, transport: transport)
    let task = Task {
      try await engine.submit(
        worldID: world.id, conversationID: conversation.id, prompt: "Do not send", preset: "Create"
      ) { _ in }
    }
    engine.cancel()
    task.cancel()
    do {
      try await task.value
      Issue.record("A queued cancelled submission must not run")
    } catch {}
    #expect(await transport.calls == 0)
    #expect(try store.messages(worldID: world.id, conversationID: conversation.id).isEmpty)
  }
}
