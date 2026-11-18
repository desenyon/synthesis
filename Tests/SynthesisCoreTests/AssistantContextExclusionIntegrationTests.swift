import Foundation
import Testing

@testable import SynthesisCore

@MainActor struct AssistantContextExclusionIntegrationTests {
  @Test func acceptedOnlyUsesFrozenTitlesAndBodiesOnTheActualRequest() async throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Accepted scope")
    let record = try store.createRecord(
      worldID: world.id, title: "Accepted coastline", body: "The old crossing is open.",
      kind: "entity", category: "Power systems")
    let accepted = try store.promote(
      worldID: world.id, id: record.id, version: record.version, confirmation: record.id)
    let live = try store.saveRecord(
      worldID: world.id, id: record.id, version: accepted.version, title: "WORKING_TITLE",
      body: "WORKING_BODY", rtf: nil)
    let draft = try store.createRecord(
      worldID: world.id, title: "UNAPPROVED_DOCUMENT", body: "UNAPPROVED_BODY", kind: "entity")
    _ = try store.addRule(
      worldID: world.id, systemID: record.id, kind: .cost, title: "LIVE_RULE",
      body: "LIVE_RULE_BODY")
    _ = try store.addRelation(
      worldID: world.id, source: record.id, target: draft.id, label: "UNAPPROVED_CONNECTION")
    let board = try store.saveBoard(
      worldID: world.id, name: "LIVE_BOARD", kind: "canvas",
      content: #"{"cards":[{"recordID":"\#(record.id)"}]}"#)
    let chat = try store.createConversation(worldID: world.id)
    _ = try store.appendMessage(
      worldID: world.id, conversationID: chat.id, role: "assistant", body: "OLD_HISTORY",
      state: "complete")
    let addresses: [(WorldReference.Kind, String)] = [
      (.record, live.id), (.record, draft.id), (.board, board.id),
    ]
    let links = try addresses.map {
      try store.resolveReference(
        WorldReference(worldID: world.id, kind: $0.0, id: $0.1), worldID: world.id
      ).markdown
    }
    let prompt =
      "Compare \(links.joined(separator: " and ")) with [LIVE_LEGACY](synthesis://record/\(live.id))."
    var options = AssistantContextOptions()
    options.canonOnly = true
    options.scope = .attachments
    options.boardIDs = [board.id]
    let preview = try store.assistantContext(worldID: world.id, prompt: prompt, options: options)
    let source = try #require(preview.sources.first)
    #expect(preview.sources.count == 1 && source.record.title == "Accepted coastline")
    #expect(source.record.body == record.body && !preview.includesHistory)
    let transport = CountingTransport()
    try await AgentEngine(store: store, transport: transport).submit(
      worldID: world.id, conversationID: chat.id, prompt: prompt, preset: "Develop",
      workspaceName: "WORKING_TITLE", contextOptions: options
    ) { _ in }
    let request = try #require(await transport.lastRequest)
    let payload = request.instructions + request.messages.compactMap { $0["content"] }.joined()
    #expect(payload.contains("Accepted coastline"))
    #expect(payload.contains("The old crossing is open."))
    for sentinel in ["WORKING_", "UNAPPROVED_", "LIVE_", "OLD_HISTORY", draft.id, board.id] {
      #expect(!payload.contains(sentinel))
    }
    let transcript = try store.messages(worldID: world.id, conversationID: chat.id)
    #expect(transcript.first { $0.role == "user" }?.body == prompt)
    #expect(try store.record(worldID: world.id, id: record.id) == live)
  }

  @Test func inheritedHistoryExclusionWinsOverPinsBoardLinksAndActiveSelection() async throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Selective history")
    let visible = try store.createRecord(worldID: world.id, title: "Public record", body: "Safe")
    let hidden = try store.createRecord(
      worldID: world.id, title: "HIDDEN_RECORD", body: "HIDDEN_BODY")
    let root = try store.createChronologyLane(
      worldID: world.id, name: "HIDDEN_ROOT", kind: "branch")
    let child = try store.createChronologyLane(
      worldID: world.id, name: "HIDDEN_CHILD", kind: "period", parentID: root.id)
    let event = try store.saveChronologyEvent(
      worldID: world.id, id: nil, title: "HIDDEN_EVENT", date: "HIDDEN_DATE", source: hidden.id,
      order: nil, laneID: child.id)
    try store.setChronologyLaneArchived(worldID: world.id, id: root.id, archived: true)
    let board = try store.saveBoard(
      worldID: world.id, name: "Shared board", kind: "canvas",
      content: #"{"cards":[{"recordID":"\#(hidden.id)"},{"recordID":"\#(visible.id)"}]}"#)
    let eventLink = try store.resolveReference(
      WorldReference(worldID: world.id, kind: .event, id: event.id), worldID: world.id
    ).markdown
    let prompt = "Compare \(eventLink) with [HIDDEN_RECORD](synthesis://record/\(hidden.id))."
    var options = AssistantContextOptions()
    options.excludedLaneIDs = [root.id]
    options.boardIDs = [board.id]
    try store.setAssistantContextOptions(worldID: world.id, options: options)
    var pins = AssistantRequestPins()
    pins.recordIDs = [hidden.id]
    pins.laneIDs = [child.id]
    let chat = try store.createConversation(worldID: world.id)
    let transport = CountingTransport()
    try await AgentEngine(store: store, transport: transport).submit(
      worldID: world.id, conversationID: chat.id, prompt: prompt, preset: "Develop",
      selectedRecordIDs: [hidden.id], chronologyLaneID: child.id,
      contextOptions: try store.assistantContextOptions(worldID: world.id), requestPins: pins
    ) { _ in }
    let request = try #require(await transport.lastRequest)
    let payload = request.instructions + request.messages.compactMap { $0["content"] }.joined()
    #expect(payload.contains("Public record"))
    for sentinel in ["HIDDEN_", event.id, child.id, root.id, hidden.id] {
      #expect(!payload.contains(sentinel))
    }
    #expect(try store.assistantContextOptions(worldID: world.id).excludedLaneIDs == [root.id])
  }
}
