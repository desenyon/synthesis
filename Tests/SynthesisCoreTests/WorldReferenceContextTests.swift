import Foundation
import Testing

@testable import SynthesisCore

struct WorldReferenceContextTests {
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
