import AppKit
import Foundation
import Testing

@testable import SynthesisCore
@testable import SynthesisUI

@MainActor struct WorkspaceReferenceDragTests {
  @Test func payloadContainsOnlyTheScopedAddressAndPendingTypingSurvivesDrop() async throws {
    let studio = try Studio(store: WorkspaceStore(path: ":memory:"))
    studio.setMode(.manual)
    let record = try studio.store.createRecord(
      worldID: studio.worldID, title: "A reference", body: "Private source text")
    let reference = WorldReference(worldID: studio.worldID, kind: .record, id: record.id)
    let provider = try WorkspaceReferenceDrag.provider(reference)
    #expect(provider.registeredTypeIdentifiers == [WorkspaceReferenceDrag.type.identifier])
    let payload: Data = try await withCheckedThrowingContinuation { continuation in
      provider.loadDataRepresentation(forTypeIdentifier: WorkspaceReferenceDrag.type.identifier) {
        data, error in
        if let data {
          continuation.resume(returning: data)
        } else {
          continuation.resume(throwing: error ?? SynthesisError.notFound)
        }
      }
    }
    #expect(!String(decoding: payload, as: UTF8.self).contains(record.body))
    studio.draft = "Existing writing"
    studio.pendingComposer = (
      studio.worldID, "Existing writing and the last keystroke", studio.draft
    )
    let location = studio.navigationLocation
    #expect(
      studio.receiveWorkspaceReference(payload, at: location) {
        studio.appendWorkspaceReference($0.reference)
      })
    #expect(studio.draft.hasPrefix("Existing writing and the last keystroke"))
    #expect(WorkspaceStore.worldReferences(in: studio.draft) == [reference])
    #expect(try studio.store.preference("composer:\(studio.worldID)") == studio.draft)
    #expect(studio.navigationLocation == location && studio.mode == .manual && !studio.busy)
    #expect(try studio.store.record(worldID: studio.worldID, id: record.id) == record)
  }

  @Test func changedWorkspaceAndArchivedSourceCannotWriteReferences() throws {
    let studio = try Studio(store: WorkspaceStore(path: ":memory:"))
    let record = try studio.store.createRecord(
      worldID: studio.worldID, title: "A scoped reference", body: "Keep this source")
    try studio.reload()
    let reference = WorldReference(worldID: studio.worldID, kind: .record, id: record.id)
    let data = try JSONEncoder().encode(reference)
    let location = studio.navigationLocation
    let draft = studio.draft
    studio.navigate(.timeline)
    #expect(
      !studio.receiveWorkspaceReference(data, at: location) { _ in
        Issue.record("Must not deliver")
        return true
      })
    try studio.store.archiveRecord(worldID: studio.worldID, id: record.id)
    #expect(
      !studio.receiveWorkspaceReference(data, at: studio.navigationLocation) { _ in
        Issue.record("Must not deliver")
        return true
      })
    #expect(studio.draft == draft)
    let other = try studio.store.createWorld(name: "Other universe")
    studio.switchWorld(other.id)
    #expect(!studio.appendWorkspaceReference(reference))
    #expect(studio.worldID == other.id && studio.draft.isEmpty)
  }

  @Test func openReferenceHonorsSaveGuardAndNeverAcceptsProposals() throws {
    let studio = try Studio(store: WorkspaceStore(path: ":memory:"))
    let proposal = try #require(
      try studio.store.stageProposal(
        worldID: studio.worldID, conversationID: nil, messageID: nil,
        payload: ["changes": [["action": "create_record", "title": "A possibility"]]]))
    let address = WorldReference(worldID: studio.worldID, kind: .proposal, id: proposal.id)
    let before = studio.navigationLocation
    studio.editorSave = { false }
    #expect(studio.openWorkspaceReference(address.url))
    #expect(studio.navigationLocation == before)
    studio.editorSave = nil
    #expect(studio.openWorkspaceReference(address.url))
    #expect(studio.destination == .review && studio.reviewFocusID == proposal.id)
    #expect(try studio.store.proposal(worldID: studio.worldID, id: proposal.id) == proposal)
    #expect(!studio.openWorkspaceReference(URL(string: "https://example.com")!))
  }
}
