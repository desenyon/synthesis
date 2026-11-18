import AppKit
import Foundation
import Testing

@testable import SynthesisCore

@MainActor struct RichLorePrivacyTests {
  @Test func restrictedRequestsFilterNativeWorkingAndFrozenHyperlinkLabels() async throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Native links")
    let port = try store.createRecord(
      worldID: world.id, title: "Approved port", body: "Open at dawn.")
    let approval = try store.promote(
      worldID: world.id, id: port.id, version: port.version, confirmation: port.id)
    let livePort = try store.saveRecord(
      worldID: world.id, id: port.id, version: approval.version, title: "WORKING_PORT",
      body: "Draft opening hours", rtf: nil)
    let privateRecord = try store.createRecord(worldID: world.id, title: "PRIVATE_NATIVE_LINK")
    let target = WorldReference(worldID: world.id, kind: .record, id: port.id).url
    let secretTarget = WorldReference(worldID: world.id, kind: .record, id: privateRecord.id).url
    let owner = try store.createRecord(worldID: world.id, title: "Overview")
    let (frozenBody, frozenRTF) = try linkedBody(
      "Frozen text: ", links: [(livePort.title, target), (privateRecord.title, secretTarget)])
    let draft = try store.saveRecord(
      worldID: world.id, id: owner.id, version: owner.version, title: owner.title,
      body: frozenBody, rtf: frozenRTF)
    let frozen = try store.promote(
      worldID: world.id, id: owner.id, version: draft.version, confirmation: owner.id)
    let (workingBody, workingRTF) = try linkedBody(
      "Working text: ", links: [(privateRecord.title, secretTarget), (livePort.title, target)])
    let working = try store.saveRecord(
      worldID: world.id, id: owner.id, version: frozen.version, title: owner.title,
      body: workingBody, rtf: workingRTF)
    try #require(MarkdownText.richBody(working.body, rtf: working.rtf) != nil)
    #expect(!working.body.contains("synthesis://"))
    var options = AssistantContextOptions()
    options.scope = .attachments
    options.recordIDs = [owner.id, port.id]
    options.excludedRecordIDs = [privateRecord.id]

    let text = try await outbound(store, worldID: world.id, options: options)
    #expect(text.contains("Frozen text: WORKING_PORT and [Excluded source]."))
    #expect(text.contains("Working text: [Excluded source] and WORKING_PORT."))
    #expect(!text.contains(privateRecord.title) && !text.contains(privateRecord.id))

    options.canonOnly = true
    let acceptedText = try await outbound(store, worldID: world.id, options: options)
    #expect(acceptedText.contains("Frozen text: Approved port and [Excluded source]."))
    #expect(!acceptedText.contains("Working text:") && !acceptedText.contains(livePort.title))
    #expect(!acceptedText.contains(privateRecord.title) && !acceptedText.contains(privateRecord.id))
    let prepared = try store.assistantContext(
      worldID: world.id, prompt: "Summarize", options: options)
    #expect(prepared.citationAddresses.contains { $0.recordID == port.id })
    #expect(!prepared.citationAddresses.contains { $0.recordID == owner.id })
    #expect(prepared.sources.allSatisfy { $0.record.rtf == nil })
    #expect(try store.record(worldID: world.id, id: owner.id) == working)
  }

  @Test func incompatibleRtfIsWithheldWhenItsLinksCannotBeChecked() async throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Mismatched resources")
    let original = try store.createRecord(worldID: world.id, title: "Overview")
    let (rtfBody, rtf) = try linkedBody("Old text", links: [])
    let draft = try store.saveRecord(
      worldID: world.id, id: original.id, version: original.version, title: original.title,
      body: "UNVERIFIABLE_PLAIN_BODY", rtf: rtf)
    #expect(draft.body != rtfBody)
    _ = try store.promote(
      worldID: world.id, id: draft.id, version: draft.version, confirmation: draft.id)
    var options = AssistantContextOptions()
    options.canonOnly = true
    options.recordIDs = [draft.id]
    let text = try await outbound(store, worldID: world.id, options: options)
    #expect(text.contains("rich-text links could not be checked"))
    #expect(!text.contains(draft.body))
    let prepared = try store.assistantContext(
      worldID: world.id, prompt: "Summarize", options: options)
    #expect(prepared.citationAddresses.isEmpty)
  }

  private func linkedBody(_ prefix: String, links: [(String, URL)]) throws -> (String, String) {
    let text = NSMutableAttributedString(string: prefix)
    for (index, link) in links.enumerated() {
      if index > 0 { text.append(NSAttributedString(string: " and ")) }
      text.append(NSAttributedString(string: link.0, attributes: [.link: link.1]))
    }
    text.append(NSAttributedString(string: "."))
    let rtf = try text.data(
      from: NSRange(location: 0, length: text.length),
      documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
    return (text.string, rtf.base64EncodedString())
  }

  private func outbound(_ store: WorkspaceStore, worldID: String, options: AssistantContextOptions)
    async throws -> String
  {
    let chat = try store.createConversation(worldID: worldID)
    let transport = CountingTransport()
    try await AgentEngine(store: store, transport: transport).submit(
      worldID: worldID, conversationID: chat.id, prompt: "Summarize", preset: "Develop",
      contextOptions: options, onDelta: { _ in })
    let request = try #require(await transport.lastRequest)
    return request.instructions + request.messages.compactMap { $0["content"] }.joined()
  }
}
