import Foundation
import Testing

@testable import SynthesisCore

@MainActor struct AssistantCitationTests {
  @Test func onlyAdmittedAcceptedPassagesBecomeLinks() async throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Glass Sea")
    let source = try store.createRecord(
      worldID: world.id, title: "Charter", body: "First passage.\n\nThe Tidekeepers held the port.")
    let accepted = try store.promote(
      worldID: world.id, id: source.id, version: source.version, confirmation: source.id)
    _ = try store.saveRecord(
      worldID: world.id, id: source.id, version: accepted.version, title: source.title,
      body: "DRAFT_CONTROLLER", rtf: nil)
    let hidden = try store.createRecord(
      worldID: world.id, title: "Sealed charter", body: "EXCLUDED_CONTROLLER")
    let hiddenApproval = try store.promote(
      worldID: world.id, id: hidden.id, version: hidden.version, confirmation: hidden.id)
    let chat = try store.createConversation(worldID: world.id)
    var options = AssistantContextOptions()
    options.canonOnly = true
    options.excludedRecordIDs = [hidden.id]
    let forged = AssistantCitation(
      worldID: world.id, recordID: hidden.id, approvalVersion: hiddenApproval.version, passage: 0)
    let transport = CitationTestTransport(
      answer: "They held the port. [[cite:2]] [[cite:999]] \(forged.marker) [Forged](\(forged.id))")
    let engine = AgentEngine(store: store, transport: transport)
    try await engine.submit(
      worldID: world.id, conversationID: chat.id, prompt: "Who held the port?", preset: "Develop",
      contextOptions: options, onDelta: { _ in })
    let sent = try #require(await transport.request)
    #expect(sent.instructions.contains("[[cite:2]] The Tidekeepers held the port."))
    #expect(!sent.instructions.contains("DRAFT_CONTROLLER"))
    #expect(!sent.instructions.contains("EXCLUDED_CONTROLLER"))
    let messages = try store.messages(worldID: world.id, conversationID: chat.id)
    let reply = try #require(messages.last)
    let citation = try #require(AssistantCitation.addresses(in: reply.body).first)
    #expect(citation.recordID == source.id && citation.approvalVersion == accepted.version)
    #expect(AssistantCitation.addresses(in: reply.body) == [citation])
    #expect(!reply.body.contains(forged.id))
    #expect(reply.body.contains("Source unavailable"))
    let exact = try store.resolveAssistantCitation(citation, worldID: world.id)
    #expect(exact.text == "The Tidekeepers held the port.")
    #expect(AssistantCitation.markdown(reply.body).contains(citation.id))
    #expect(
      AssistantCitation.markdown(reply.body, forDraft: true).contains(
        "synthesis://record/\(source.id)"))
  }

  @Test func storedPassageSurvivesReapprovalAndImportWithWorldScope() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Original")
    let record = try store.createRecord(
      worldID: world.id, title: "Old title", body: "Old 🐚 account")
    let approval = try store.promote(
      worldID: world.id, id: record.id, version: record.version, confirmation: record.id)
    let source = AssistantCitation(
      worldID: world.id, recordID: record.id, approvalVersion: approval.version, passage: 0)
    let chat = try store.createConversation(worldID: world.id)
    try store.appendMessage(
      worldID: world.id, conversationID: chat.id, role: "assistant", body: "Claim \(source.marker)",
      state: "complete")
    let draft = try store.saveRecord(
      worldID: world.id, id: record.id, version: approval.version, title: "New title",
      body: "New account", rtf: nil)
    _ = try store.promote(
      worldID: world.id, id: record.id, version: draft.version, confirmation: record.id)
    let original = try store.resolveAssistantCitation(source, worldID: world.id)
    #expect(original.title == "Old title" && original.text == "Old 🐚 account")
    let invalid = AssistantCitation(
      worldID: world.id, recordID: record.id, approvalVersion: draft.version, passage: 0)
    #expect(throws: SynthesisError.self) {
      try store.resolveAssistantCitation(invalid, worldID: world.id)
    }
    try store.archiveRecord(worldID: world.id, id: record.id)
    #expect(throws: SynthesisError.self) {
      try store.resolveAssistantCitation(source, worldID: world.id)
    }
    try store.restoreRecord(worldID: world.id, id: record.id)
    #expect(try store.resolveAssistantCitation(source, worldID: world.id).text == original.text)

    let imported = try store.importWorldArchive(store.exportWorldArchive(worldID: world.id))
    let importedChat = try #require(try store.conversations(worldID: imported.id).first)
    let importedReply = try #require(
      try store.messages(worldID: imported.id, conversationID: importedChat.id).first)
    let importedSource = try #require(AssistantCitation.addresses(in: importedReply.body).first)
    #expect(importedSource.worldID == imported.id && importedSource.recordID != record.id)
    #expect(
      try store.resolveAssistantCitation(importedSource, worldID: imported.id).text == original.text
    )
    #expect(throws: SynthesisError.self) {
      try store.resolveAssistantCitation(source, worldID: imported.id)
    }
  }

  @Test func excerptDoesNotCiteAnyTextBeyondTheSubmittedLimit() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Excerpt")
    let prefix = String(repeating: "é", count: 6000)
    let record = try store.createRecord(worldID: world.id, title: "Notes", body: prefix + "UNSENT")
    _ = try store.promote(
      worldID: world.id, id: record.id, version: record.version, confirmation: record.id)
    var options = AssistantContextOptions()
    options.canonOnly = true
    let context = try store.assistantContext(worldID: world.id, prompt: "Notes", options: options)
    let citation = try #require(context.citationAddresses.first)
    #expect(!context.lore.contains("UNSENT"))
    #expect(try store.resolveAssistantCitation(citation, worldID: world.id).text == prefix)
  }
}

private actor CitationTestTransport: ModelTransport {
  let answer: String
  private(set) var request: ModelRequest?
  init(answer: String) { self.answer = answer }
  func generate(_ request: ModelRequest, onDelta: @escaping @Sendable (String) async -> Void)
    async throws -> String
  {
    self.request = request
    await onDelta(answer)
    return answer
  }
}
