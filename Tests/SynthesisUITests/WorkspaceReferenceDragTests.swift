import AppKit
import Foundation
import Testing

@testable import SynthesisCore
@testable import SynthesisUI

@MainActor struct WorkspaceReferenceDragTests {
  @Test func lateDeliveryCannotConsumeANewerDragAtTheSameLocation() async throws {
    let studio = try Studio(store: WorkspaceStore(path: ":memory:"))
    let first = try studio.store.createRecord(worldID: studio.worldID, title: "First")
    let second = try studio.store.createRecord(worldID: studio.worldID, title: "Second")
    _ = studio.beginRecordDrag(first, monitor: false)
    let old = try #require(studio.claimWorkspaceReferenceDrop())
    #expect(studio.claimWorkspaceReferenceDrop() == nil)
    _ = studio.beginRecordDrag(second, monitor: false)
    let new = try #require(studio.claimWorkspaceReferenceDrop())
    let source = try JSONEncoder().encode(old.reference)
    let delivered = await studio.receiveWorkspaceReference(source, delivery: old) { _ in
      Issue.record("A stale drag must not write to the current workspace")
      return true
    }
    #expect(!delivered)
    #expect(studio.isCurrentWorkspaceReferenceDrop(new))
    #expect(studio.draft.isEmpty)
    let current = try JSONEncoder().encode(new.reference)
    let accepted = await studio.receiveWorkspaceReference(current, delivery: new) {
      studio.appendWorkspaceReference($0.reference)
    }
    #expect(accepted)
    #expect(WorkspaceStore.worldReferences(in: studio.draft) == [new.reference])
    #expect(!studio.isCurrentWorkspaceReferenceDrop(new))
  }

  @Test func payloadContainsOnlyTheScopedAddressAndPendingTypingSurvivesDrop() async throws {
    let studio = try Studio(store: WorkspaceStore(path: ":memory:"))
    studio.setMode(.manual)
    let record = try studio.store.createRecord(
      worldID: studio.worldID, title: "A reference", body: "Private source text")
    let reference = WorldReference(worldID: studio.worldID, kind: .record, id: record.id)
    let provider = try studio.beginWorkspaceReferenceDrag(reference, monitor: false)
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
    let delivery = try #require(studio.claimWorkspaceReferenceDrop())
    let delivered = await studio.receiveWorkspaceReference(payload, delivery: delivery) {
      studio.appendWorkspaceReference($0.reference)
    }
    #expect(delivered)
    #expect(studio.draft.hasPrefix("Existing writing and the last keystroke"))
    #expect(WorkspaceStore.worldReferences(in: studio.draft) == [reference])
    #expect(try studio.store.preference("composer:\(studio.worldID)") == studio.draft)
    #expect(studio.navigationLocation == location && studio.mode == .manual && !studio.busy)
    #expect(try studio.store.record(worldID: studio.worldID, id: record.id) == record)
  }

  @Test func changedWorkspaceAndArchivedSourceCannotWriteReferences() async throws {
    let studio = try Studio(store: WorkspaceStore(path: ":memory:"))
    let record = try studio.store.createRecord(
      worldID: studio.worldID, title: "A scoped reference", body: "Keep this source")
    try studio.reload()
    let reference = WorldReference(worldID: studio.worldID, kind: .record, id: record.id)
    let data = try JSONEncoder().encode(reference)
    let draft = studio.draft
    _ = try studio.beginWorkspaceReferenceDrag(reference, monitor: false)
    let oldLocation = try #require(studio.claimWorkspaceReferenceDrop())
    studio.navigate(.timeline)
    let moved = await studio.receiveWorkspaceReference(data, delivery: oldLocation) { _ in
      Issue.record("Must not deliver")
      return true
    }
    #expect(!moved)
    _ = try studio.beginWorkspaceReferenceDrag(reference, monitor: false)
    let archived = try #require(studio.claimWorkspaceReferenceDrop())
    try studio.store.archiveRecord(worldID: studio.worldID, id: record.id)
    let unavailable = await studio.receiveWorkspaceReference(data, delivery: archived) { _ in
      Issue.record("Must not deliver")
      return true
    }
    #expect(!unavailable)
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
