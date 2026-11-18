import Foundation
import Testing

@testable import SynthesisCore

struct WorldReferenceContextTests {
  @Test func archiveCopyRemapsRichLinksInCurrentAcceptedAndHistoricalText() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Rich reference archive")
    let page = try store.createRecord(worldID: world.id, title: "Page")
    let source = try store.createRecord(worldID: world.id, title: "Source")
    let address = WorldReference(worldID: world.id, kind: .record, id: source.id)
    let rich = #"{\rtf1 {\field{\*\fldinst HYPERLINK "\#(address.url)"}{\fldrslt Source}}}"#
    let linked = try store.saveRecord(
      worldID: world.id, id: page.id, version: page.version, title: page.title,
      body: source.title, rtf: Data(rich.utf8).base64EncodedString())
    _ = try store.promote(
      worldID: world.id, id: page.id, version: linked.version, confirmation: page.id)

    let archive = try store.exportWorldArchive(worldID: world.id)
    let copy = try store.importWorldArchiveMapping(archive)
    let pageID = try #require(copy.ids[page.id])
    let sourceID = try #require(copy.ids[source.id])
    let copiedAddress = WorldReference(worldID: copy.world.id, kind: .record, id: sourceID)
    let copiedPage = try store.record(worldID: copy.world.id, id: pageID)
    let revisions = try store.history(worldID: copy.world.id, id: pageID)
    let snapshots = [copiedPage] + revisions.filter { $0.version > 1 }.map(\.snapshot)
    #expect(snapshots.count == 3)
    for snapshot in snapshots {
      let current = try decodedRichText(snapshot.rtf)
      #expect(current.contains(copiedAddress.url.absoluteString))
      #expect(!current.contains(address.url.absoluteString))
      if let accepted = snapshot.canonical {
        let canon = try JSONDecoder().decode(LoreRecord.self, from: Data(accepted.utf8))
        #expect(try decodedRichText(canon.rtf).contains(copiedAddress.url.absoluteString))
      }
    }
    #expect(try store.resolveReference(copiedAddress, worldID: copy.world.id).title == "Source")
  }

  private func decodedRichText(_ value: String?) throws -> String {
    let encoded = try #require(value)
    let data = try #require(Data(base64Encoded: encoded))
    return String(decoding: data, as: UTF8.self)
  }

  @MainActor @Test func mixedDirectSourcesShareOneBudgetWithoutCountingRecordAliases() async throws
  {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Mixed references")
    let records = try (1...8).map {
      try store.createRecord(worldID: world.id, title: "Record \($0)")
    }
    let recordID = records[0].id
    let record = WorldReference(worldID: world.id, kind: .record, id: recordID)
    let event = try store.saveChronologyEvent(
      worldID: world.id, id: nil, title: "Crossing", date: "Year 4", source: recordID,
      order: nil, laneID: nil)
    let eventAddress = WorldReference(worldID: world.id, kind: .event, id: event.id)
    let prompt = "[Record](synthesis://record/\(recordID)) \(record.url) \(eventAddress.url)"
    var options = AssistantContextOptions()
    options.scope = .attachments
    options.budget = .focused
    options.recordIDs = records.map(\.id)
    #expect(throws: (any Error).self) {
      try store.assistantContext(worldID: world.id, prompt: prompt, options: options)
    }
    let chat = try store.createConversation(worldID: world.id)
    let transport = CountingTransport()
    let engine = AgentEngine(store: store, transport: transport)
    await #expect(throws: SynthesisError.self) {
      try await engine.submit(
        worldID: world.id, conversationID: chat.id, prompt: prompt, preset: "Develop",
        contextOptions: options
      ) { _ in }
    }
    #expect(await transport.calls == 0)
    #expect(try store.messages(worldID: world.id, conversationID: chat.id).isEmpty)
    options.recordIDs.removeLast()
    let context = try store.assistantContext(worldID: world.id, prompt: prompt, options: options)
    #expect(context.sources.map(\.id) == options.recordIDs)
    #expect(context.sources.first?.reason == "Attached by you")
    let index = try #require(
      try JSONSerialization.jsonObject(with: Data(context.workspace.utf8)) as? [String: Any])
    let references = try #require(index["references"] as? [[String: Any]])
    #expect(references.contains { $0["url"] as? String == eventAddress.url.absoluteString })
  }

  @Test func excludingAcceptedOutputAlsoExcludesItsProposalHistory() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Private proposal output")
    let proposal = try #require(
      try store.stageProposal(
        worldID: world.id, conversationID: nil, messageID: nil,
        payload: [
          "summary": "PRIVATE_PROPOSAL_TITLE",
          "changes": [
            [
              "action": "create_record", "title": "PRIVATE_RESULT_TITLE",
              "body": "PRIVATE_PROPOSAL_BODY", "reason": "PRIVATE_PROPOSAL_REASON",
            ]
          ],
        ]))
    let accepted = try store.resolveChange(
      worldID: world.id, proposalID: proposal.id, changeID: proposal.changes[0].id,
      accept: true, confirmation: proposal.id)
    let resultID = try #require(accepted.changes[0].resultID)
    let reference = WorldReference(worldID: world.id, kind: .proposal, id: proposal.id)
    #expect(try store.resolveReference(reference, worldID: world.id).recordIDs.contains(resultID))
    for archived in [false, true] {
      if archived { try store.archiveRecord(worldID: world.id, id: resultID) }
      for scope in AssistantContextScope.allCases {
        var options = AssistantContextOptions()
        options.scope = scope
        options.excludedRecordIDs = [resultID]
        let context = try store.assistantContext(
          worldID: world.id, prompt: reference.url.absoluteString, options: options)
        for sentinel in [
          "PRIVATE_PROPOSAL_TITLE", "PRIVATE_RESULT_TITLE", "PRIVATE_PROPOSAL_BODY",
          "PRIVATE_PROPOSAL_REASON",
        ] {
          #expect(!context.workspace.contains(sentinel))
          #expect(!context.lore.contains(sentinel))
        }
        #expect(!context.sources.contains { $0.id == resultID })
        #expect(!context.includesHistory)
      }
    }
  }
  @Test func excludingAutoCreatedHistorySourceAlsoExcludesAcceptedEventProposal() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Private event output")
    let proposal = try #require(
      try store.stageProposal(
        worldID: world.id, conversationID: nil, messageID: nil,
        payload: [
          "summary": "PRIVATE_EVENT_PROPOSAL",
          "changes": [
            [
              "action": "add_event", "title": "PRIVATE_EVENT_TITLE", "date": "Year 7",
              "reason": "PRIVATE_EVENT_REASON",
            ]
          ],
        ]))
    let accepted = try store.resolveChange(
      worldID: world.id, proposalID: proposal.id, changeID: proposal.changes[0].id,
      accept: true, confirmation: proposal.id)
    let eventID = try #require(accepted.changes[0].resultID)
    let event = try #require(store.events(worldID: world.id).first { $0.id == eventID })
    let reference = WorldReference(worldID: world.id, kind: .proposal, id: proposal.id)
    for archived in [false, true] {
      if archived {
        try store.setEventArchived(worldID: world.id, id: event.id, archived: true)
        try store.archiveRecord(worldID: world.id, id: event.sourceID)
      }
      #expect(
        try store.resolveReference(reference, worldID: world.id).recordIDs.contains(event.sourceID))
      try assertExcluded(
        store, world.id, reference, recordID: event.sourceID,
        sentinels: ["PRIVATE_EVENT_PROPOSAL", "PRIVATE_EVENT_TITLE", "PRIVATE_EVENT_REASON"])
    }
  }

  @Test func reassignedEventAndMapKeepBeforeSourceProvenance() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Reassigned sources")
    let old = try store.createRecord(worldID: world.id, title: "Private old source", kind: "entity")
    let replacement = try store.createRecord(
      worldID: world.id, title: "Public replacement", kind: "entity")
    let event = try store.saveChronologyEvent(
      worldID: world.id, id: nil,
      title: "PRIVATE_OLD_EVENT", date: "Year 4", source: old.id, order: nil, laneID: nil)
    let map = try store.saveAtlasMap(
      worldID: world.id, name: "PRIVATE_OLD_MAP",
      content: "{\"markers\":[],\"placeID\":\"\(old.id)\"}")
    for (action, id, sentinel) in [
      ("revise_event", event.id, "PRIVATE_OLD_EVENT"),
      ("revise_map", map.id, "PRIVATE_OLD_MAP"),
    ] {
      let proposal = try #require(
        try store.stageProposal(
          worldID: world.id, conversationID: nil, messageID: nil,
          payload: [
            "summary": "PRIVATE_REASSIGN_REASON",
            "changes": [
              [
                "action": action, "id": id, "source": replacement.id,
                "reason": "PRIVATE_REASSIGN_REASON",
              ]
            ],
          ]))
      #expect(proposal.changes[0].source == replacement.id)
      #expect(proposal.changes[0].workspaceBefore?["source"] == old.id)
      let reference = WorldReference(worldID: world.id, kind: .proposal, id: proposal.id)
      #expect(try store.resolveReference(reference, worldID: world.id).recordIDs.contains(old.id))
      try assertExcluded(
        store, world.id, reference, recordID: old.id,
        sentinels: [sentinel, "PRIVATE_REASSIGN_REASON"])
    }
  }

  private func assertExcluded(
    _ store: WorkspaceStore, _ worldID: String,
    _ reference: WorldReference, recordID: String, sentinels: [String]
  ) throws {
    for scope in AssistantContextScope.allCases {
      var options = AssistantContextOptions()
      options.scope = scope
      options.excludedRecordIDs = [recordID]
      let context = try store.assistantContext(
        worldID: worldID, prompt: reference.url.absoluteString, options: options)
      for sentinel in sentinels {
        #expect(!context.workspace.contains(sentinel))
        #expect(!context.lore.contains(sentinel))
      }
      #expect(!context.sources.contains { $0.id == recordID })
      #expect(!context.includesHistory)
    }
  }

}
