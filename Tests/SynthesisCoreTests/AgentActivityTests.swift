import Foundation
import Testing

@testable import SynthesisCore

@MainActor struct AgentActivityTests {
  @Test func activityReflectsRealRetrievalAndResponse() async throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Aster")
    let other = try store.createWorld(name: "Elsewhere")
    _ = try store.createRecord(worldID: world.id, title: "Mira", body: "Cartographer")
    _ = try store.createRecord(worldID: other.id, title: "Private foreign record")
    let chat = try store.createConversation(worldID: world.id)
    var events: [AgentActivity] = []
    let transport = CountingTransport()
    let engine = AgentEngine(store: store, transport: transport)
    try await engine.submit(
      worldID: world.id, conversationID: chat.id, prompt: "Mira", preset: "Develop",
      onActivity: { events.append($0) }, onDelta: { _ in })
    #expect(events.map(\.id) == ["lore", "lore", "response", "response"])
    #expect(events.map(\.state) == [.running, .complete, .running, .complete])
    #expect(events[1].detail == "1 record · selected world only")
    #expect(events[3].endedAt! >= events[3].startedAt)
    #expect(await transport.calls == 1)
    #expect(await transport.lastRequest?.instructions.contains("Private foreign record") == false)
  }

  @Test func invalidActionsNeverReportSuccessfulReview() async throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Aster")
    let chat = try store.createConversation(worldID: world.id)
    let engine = AgentEngine(
      store: store,
      transport: ScriptedTransport(
        answer: """
          ```synthesis-proposal
          {"changes":[{"action":"execute_code","body":"malicious"}]}
          ```
          """))
    var events: [AgentActivity] = []
    try await engine.submit(
      worldID: world.id, conversationID: chat.id, prompt: "Help", preset: "Create",
      onActivity: { events.append($0) }, onDelta: { _ in })
    #expect(events.last?.id == "review" && events.last?.state == .failed)
    #expect(try store.proposals(worldID: world.id).isEmpty)
    #expect(
      try store.messages(worldID: world.id, conversationID: chat.id).last?.body.contains(
        "No changes were staged") == true)
  }

  @Test func manualProducesNoActivityAndNoProviderCall() async throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Manual world")
    let chat = try store.createConversation(worldID: world.id)
    let transport = CountingTransport()
    let engine = AgentEngine(store: store, transport: transport)
    try engine.setMode(.manual)
    var events: [AgentActivity] = []
    do {
      try await engine.submit(
        worldID: world.id, conversationID: chat.id, prompt: "Hello", preset: "Create",
        onActivity: { events.append($0) }, onDelta: { _ in })
      Issue.record("Manual mode accepted a model request")
    } catch SynthesisError.manualMode {}
    #expect(events.isEmpty)
    #expect(await transport.calls == 0)
  }
}
