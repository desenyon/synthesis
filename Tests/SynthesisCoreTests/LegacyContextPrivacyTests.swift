import Foundation
import Testing

@testable import SynthesisCore

@MainActor struct LegacyContextPrivacyTests {
  @Test func savedLegacyLabelRemainsPrivateAfterARenameAndArchive() async throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Private references")
    let secret = try store.createRecord(
      worldID: world.id, title: #"PRIVATE [Annex] \ Crossing"#, body: "PRIVATE_BODY")
    let new = try store.saveRecord(
      worldID: world.id, id: secret.id, version: secret.version,
      title: "New title", body: "New text", rtf: nil)
    try store.archiveRecord(worldID: world.id, id: new.id)
    let chat = try store.createConversation(worldID: world.id)
    let transport = CountingTransport()
    let prompt =
      "First [aside]. Compare [\(secret.title)](synthesis://record/\(secret.id)). Keep this."
    var options = AssistantContextOptions()
    options.excludedRecordIDs = [secret.id]

    try await AgentEngine(store: store, transport: transport).submit(
      worldID: world.id, conversationID: chat.id, prompt: prompt, preset: "Develop",
      contextOptions: options
    ) { _ in }

    let request = try #require(await transport.lastRequest)
    let input = try #require(request.messages.last?["content"])
    #expect(input == "First [aside]. Compare [Excluded source]. Keep this.")
    #expect(!request.instructions.contains("PRIVATE"))
    let messages = try store.messages(worldID: world.id, conversationID: chat.id)
    #expect(messages.first?.body == prompt)
  }

  @Test func legacyWorkingLabelIsReplacedWithAcceptedTitleForCanonOnly() async throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Accepted references")
    let original = try store.createRecord(
      worldID: world.id, title: "Public crossing", body: "Accepted account")
    let accepted = try store.promote(
      worldID: world.id, id: original.id, version: original.version, confirmation: original.id)
    let draft = try store.saveRecord(
      worldID: world.id, id: original.id, version: accepted.version, title: "PRIVATE [Annex",
      body: "PRIVATE_BODY", rtf: nil)
    let chat = try store.createConversation(worldID: world.id)
    let transport = CountingTransport()
    let address = "synthesis://record/\(draft.id)"
    let prompt = "Compare [\(draft.title)](\(address)). Keep this."
    var options = AssistantContextOptions()
    options.canonOnly = true

    try await AgentEngine(store: store, transport: transport).submit(
      worldID: world.id, conversationID: chat.id, prompt: prompt, preset: "Develop",
      contextOptions: options
    ) { _ in }

    let request = try #require(await transport.lastRequest)
    #expect(
      request.messages.last?["content"] == "Compare [Public crossing](\(address)). Keep this.")
    #expect(!request.instructions.contains("PRIVATE"))
    let messages = try store.messages(worldID: world.id, conversationID: chat.id)
    #expect(messages.first?.body == prompt)
  }
}
