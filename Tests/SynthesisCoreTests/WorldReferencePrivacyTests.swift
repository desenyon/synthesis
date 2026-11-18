import Foundation
import Testing

@testable import SynthesisCore

@MainActor struct WorldReferencePrivacyTests {
  @Test func excludedLinkLabelsStayInTheLocalTranscriptOnly() async throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Private links")
    let record = try store.createRecord(
      worldID: world.id, title: #"PRIVATE [SOURCE] \ title"#, body: "PRIVATE_BODY")
    let reference = WorldReference(worldID: world.id, kind: .record, id: record.id)
    let source = try store.resolveReference(reference, worldID: world.id)
    let chat = try store.createConversation(worldID: world.id)
    let transport = CountingTransport()
    let engine = AgentEngine(store: store, transport: transport)
    var options = AssistantContextOptions()
    options.excludedRecordIDs = [record.id]
    let legacyLink = "[PRIVATE_LEGACY](synthesis://record/\(record.id))"
    let prompt = "My first thought: \(source.markdown) and \(legacyLink). Keep this prose."
    let preview = try store.assistantContext(worldID: world.id, prompt: prompt, options: options)
    try await engine.submit(
      worldID: world.id, conversationID: chat.id, prompt: prompt, preset: "Develop",
      contextOptions: options
    ) { _ in }
    let request = try #require(await transport.lastRequest)
    let input = try #require(request.messages.last?["content"])
    #expect(input == preview.providerPrompt)
    #expect(input.hasPrefix("My first thought: "))
    #expect(input.hasSuffix(". Keep this prose."))
    for sentinel in ["PRIVATE", record.id] {
      #expect(!request.instructions.contains(sentinel))
      #expect(!input.contains(sentinel))
    }
    let transcript = try store.messages(worldID: world.id, conversationID: chat.id)
    #expect(transcript.first(where: { $0.role == "user" })?.body == prompt)
  }

  @Test func repeatedAddressesCannotHideLaterForeignReferences() async throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Local")
    let other = try store.createWorld(name: "Foreign")
    let localRecord = try store.createRecord(worldID: world.id, title: "Local")
    let foreignRecord = try store.createRecord(worldID: other.id, title: "Foreign")
    let local = WorldReference(worldID: world.id, kind: .record, id: localRecord.id)
    let foreign = WorldReference(worldID: other.id, kind: .record, id: foreignRecord.id)
    let prompt =
      String(repeating: "\(local.url.absoluteString) ", count: 64)
      + foreign.url.absoluteString
    #expect(try WorkspaceStore.requestWorldReferences(in: prompt) == [local, foreign])
    let tooMany = (0..<65).map {
      WorldReference(worldID: world.id, kind: .record, id: "source-\($0)").url.absoluteString
    }.joined(separator: " ")
    #expect(throws: SynthesisError.self) { try WorkspaceStore.requestWorldReferences(in: tooMany) }
    let chat = try store.createConversation(worldID: world.id)
    let transport = CountingTransport()
    let engine = AgentEngine(store: store, transport: transport)
    await #expect(throws: SynthesisError.self) {
      try await engine.submit(
        worldID: world.id, conversationID: chat.id, prompt: prompt, preset: "Develop"
      ) { _ in }
    }
    #expect(await transport.calls == 0)
    #expect(try store.messages(worldID: world.id, conversationID: chat.id).isEmpty)
  }

  @Test func acceptedEventKeepsItsOriginalSourceAfterReassignmentAndArchiveRoundTrip() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Event provenance")
    let proposal = try #require(
      try store.stageProposal(
        worldID: world.id, conversationID: nil, messageID: nil,
        payload: [
          "summary": "PRIVATE_EVENT_SUMMARY",
          "changes": [["action": "add_event", "title": "PRIVATE_EVENT_TITLE"]],
        ]))
    let accepted = try store.resolveChange(
      worldID: world.id, proposalID: proposal.id, changeID: proposal.changes[0].id,
      accept: true, confirmation: proposal.id)
    let eventID = try #require(accepted.changes[0].resultID)
    let event = try #require(try store.events(worldID: world.id).first { $0.id == eventID })
    let replacement = try store.createRecord(worldID: world.id, title: "Replacement source")
    _ = try store.updateEvent(
      worldID: world.id, id: eventID, title: "Public event", date: "", source: replacement.id,
      order: nil)
    try store.archiveRecord(worldID: world.id, id: event.sourceID)
    try assertEventProvenance(store, world.id, proposal.id, event.sourceID)

    let archive = try store.exportWorldArchive(worldID: world.id)
    let imported = try store.importWorldArchiveMapping(archive)
    let importedProposal = try #require(imported.ids[proposal.id])
    let importedSource = try #require(imported.ids[event.sourceID])
    try assertEventProvenance(store, imported.world.id, importedProposal, importedSource)
  }

  @Test func proposalOriginExcludesContentWithoutExpandingItsAttachmentScope() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Proposal provenance")
    let hidden = try store.createRecord(worldID: world.id, title: "Original context")
    let chat = try store.createConversation(worldID: world.id)
    let message = try store.appendMessage(
      worldID: world.id, conversationID: chat.id, role: "assistant",
      body: "A proposal without explicit evidence.", state: "complete")
    try store.saveMessageContext(
      worldID: world.id, messageID: message.id, sources: [.init(record: hidden, reason: "Selected")]
    )
    let proposal = try #require(
      try store.stageProposal(
        worldID: world.id, conversationID: chat.id, messageID: message.id,
        payload: [
          "summary": "PRIVATE_ORIGIN_TITLE",
          "changes": [["action": "create_record", "title": "PRIVATE_ORIGIN_CHANGE"]],
        ]))
    let address = WorldReference(worldID: world.id, kind: .proposal, id: proposal.id)
    let source = try store.resolveReference(address, worldID: world.id)
    #expect(source.recordIDs.isEmpty)
    #expect(source.exclusionRecordIDs.contains(hidden.id))
    var options = AssistantContextOptions()
    options.scope = .attachments
    let attached = try store.assistantContext(
      worldID: world.id, prompt: source.markdown, options: options)
    #expect(attached.sources.isEmpty)
    #expect(attached.workspace.contains("PRIVATE_ORIGIN_TITLE"))

    try store.archiveRecord(worldID: world.id, id: hidden.id)
    options.excludedRecordIDs = [hidden.id]
    let restricted = try store.assistantContext(
      worldID: world.id, prompt: source.markdown, options: options)
    #expect(!restricted.workspace.contains("PRIVATE_ORIGIN"))
    #expect(!restricted.providerPrompt.contains("PRIVATE_ORIGIN"))
  }

  private func assertEventProvenance(
    _ store: WorkspaceStore, _ worldID: String, _ proposalID: String, _ sourceID: String
  ) throws {
    let reference = WorldReference(worldID: worldID, kind: .proposal, id: proposalID)
    let source = try store.resolveReference(reference, worldID: worldID)
    #expect(source.exclusionRecordIDs.contains(sourceID))
    var options = AssistantContextOptions()
    options.excludedRecordIDs = [sourceID]
    let context = try store.assistantContext(
      worldID: worldID, prompt: source.markdown, options: options)
    #expect(!context.workspace.contains("PRIVATE_EVENT"))
    #expect(!context.providerPrompt.contains("PRIVATE_EVENT"))
  }
}
