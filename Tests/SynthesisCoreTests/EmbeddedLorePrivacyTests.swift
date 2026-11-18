import Foundation
import Testing

@testable import SynthesisCore

@MainActor struct EmbeddedLorePrivacyTests {
  @Test func includedLoreRedactsExcludedLinksFromWorkingAndFrozenExcerpts() async throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Embedded sources")
    let secret = try store.createRecord(
      worldID: world.id, title: #"EXCLUDED_RECORD [Bay] \ Annex"#, body: "EXCLUDED_BODY")
    let lane = try store.createChronologyLane(
      worldID: world.id, name: "EXCLUDED_LANE", kind: "branch")
    let history = try store.createRecord(worldID: world.id, title: "EXCLUDED_HISTORY")
    let event = try store.saveChronologyEvent(
      worldID: world.id, id: nil, title: "EXCLUDED_EVENT", date: "EXCLUDED_DATE",
      source: history.id, order: nil, laneID: lane.id)
    let eventSource = try store.resolveReference(
      WorldReference(worldID: world.id, kind: .event, id: event.id), worldID: world.id)
    let open = try store.createRecord(worldID: world.id, title: "Open source")
    let openSource = try store.resolveReference(
      WorldReference(worldID: world.id, kind: .record, id: open.id), worldID: world.id)
    let frozen =
      "Frozen paragraph: [\(secret.title)](synthesis://record/\(secret.id))."
    let record = try store.createRecord(worldID: world.id, title: "Public overview", body: frozen)
    let accepted = try store.promote(
      worldID: world.id, id: record.id, version: record.version, confirmation: record.id)
    // The address crosses the ordinary working-body cutoff. Filtering first must hide its label.
    let introduction = "Working paragraph: \(openSource.markdown). "
    let working =
      introduction + String(repeating: "x", count: 2960 - introduction.count)
      + " \(eventSource.markdown)"
    let draft = try store.saveRecord(
      worldID: world.id, id: record.id, version: accepted.version, title: record.title,
      body: working, rtf: nil)
    var options = AssistantContextOptions()
    options.recordIDs = [record.id]
    options.excludedRecordIDs = [secret.id]
    options.excludedLaneIDs = [lane.id]
    let chat = try store.createConversation(worldID: world.id)
    let transport = CountingTransport()

    try await AgentEngine(store: store, transport: transport).submit(
      worldID: world.id, conversationID: chat.id, prompt: "Summarize the overview.",
      preset: "Develop", contextOptions: options
    ) { _ in }

    let request = try #require(await transport.lastRequest)
    let payload = request.instructions + request.messages.compactMap { $0["content"] }.joined()
    #expect(payload.contains("Working paragraph: \(openSource.markdown)."))
    #expect(payload.contains("Frozen paragraph: [Excluded source]."))
    for sentinel in ["EXCLUDED_", secret.id, history.id, lane.id, event.id] {
      #expect(!payload.contains(sentinel))
    }
    #expect(try store.record(worldID: world.id, id: record.id) == draft)
  }

  @Test func canonOnlySubstitutesTheAcceptedTitleInAnEmbeddedLink() async throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Frozen sources")
    let publicRecord = try store.createRecord(
      worldID: world.id, title: "Accepted harbor", body: "The harbor is closed after dark.")
    let accepted = try store.promote(
      worldID: world.id, id: publicRecord.id, version: publicRecord.version,
      confirmation: publicRecord.id)
    _ = try store.saveRecord(
      worldID: world.id, id: publicRecord.id, version: accepted.version, title: "WORKING_TITLE",
      body: "WORKING_BODY", rtf: nil)
    let draft = try store.createRecord(worldID: world.id, title: "DRAFT_ONLY")
    let target = WorldReference(worldID: world.id, kind: .record, id: publicRecord.id)
    let draftAddress = WorldReference(worldID: world.id, kind: .record, id: draft.id)
    let workingLink = try store.resolveReference(target, worldID: world.id).markdown
    let draftLink = try store.resolveReference(draftAddress, worldID: world.id).markdown
    let body = "An authored sentence remains. See \(workingLink) and \(draftLink)."
    let owner = try store.createRecord(worldID: world.id, title: "Frozen overview", body: body)
    let frozen = try store.promote(
      worldID: world.id, id: owner.id, version: owner.version, confirmation: owner.id)
    let transport = CountingTransport()
    let chat = try store.createConversation(worldID: world.id)
    var options = AssistantContextOptions()
    options.canonOnly = true
    options.scope = .attachments
    options.recordIDs = [owner.id, publicRecord.id]

    try await AgentEngine(store: store, transport: transport).submit(
      worldID: world.id, conversationID: chat.id, prompt: "Summarize the accepted overview.",
      preset: "Develop", contextOptions: options
    ) { _ in }

    let context = try store.assistantContext(
      worldID: world.id, prompt: "Read the accepted overview.", options: options)
    #expect(context.citationAddresses.allSatisfy { $0.recordID != owner.id })
    #expect(context.citationAddresses.contains { $0.recordID == publicRecord.id })
    let request = try #require(await transport.lastRequest)
    let payload = request.instructions + request.messages.compactMap { $0["content"] }.joined()
    let acceptedLink = WorldReferenceSource.markdown(title: publicRecord.title, url: target.url)
    #expect(
      payload.contains("An authored sentence remains. See \(acceptedLink) and [Excluded source]."))
    for sentinel in ["WORKING_", "DRAFT_ONLY", draft.id] {
      #expect(!payload.contains(sentinel))
    }
    #expect(try store.record(worldID: world.id, id: owner.id) == frozen)
  }
}
