import Foundation
import Testing

@testable import SynthesisCore

struct WhatIfBranchTests {
  @Test func pendingRelationshipMergeRoundTripsWithWordedDatesAndRemappedEvidence() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Aster")
    let mira = try store.createRecord(worldID: world.id, title: "Mira", kind: "entity")
    let oren = try store.createRecord(worldID: world.id, title: "Oren", kind: "entity")
    let evidence = try store.createRecord(worldID: world.id, title: "Testimony")
    let branch = try store.createWhatIfBranch(parentID: world.id, name: "The winter voyage")
    let copies = Dictionary(
      uniqueKeysWithValues: try store.records(worldID: branch.id).map { ($0.title, $0.id) })
    var attributes = RelationshipAttributes()
    attributes.kind = .mentor
    attributes.startLabel = "After the incantation \(evidence.id)"
    attributes.evidenceRecordIDs = [copies[evidence.title]!]
    _ = try store.addRelation(
      worldID: branch.id, source: copies[oren.title]!, target: copies[mira.title]!,
      label: "mentors", attributes: attributes)
    _ = try store.proposeBranchMerge(worldID: branch.id)

    let archive = try store.exportWorldArchive(worldID: world.id)
    let copy = try store.importWorldArchiveMapping(archive)
    let proposal = try #require(try store.proposals(worldID: copy.world.id).first)
    let change = try #require(proposal.changes.first)
    let evidenceID = try #require(copy.ids[evidence.id])
    #expect(change.evidence == [evidenceID])
    _ = try store.resolveChange(
      worldID: copy.world.id, proposalID: proposal.id, changeID: change.id, accept: true,
      confirmation: proposal.id)
    let edge = try #require(try store.relations(worldID: copy.world.id).first)
    #expect(edge.attributes.startLabel == attributes.startLabel)
    #expect(edge.attributes.kind == .mentor && edge.attributes.evidenceRecordIDs == [evidenceID])
  }

  @Test func branchIsAnIndependentCopyThatNeverTouchesTheOriginal() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Aster")
    let mira = try store.createRecord(
      worldID: world.id, title: "Mira", body: "A cartographer.", kind: "entity")
    _ = try store.promote(
      worldID: world.id, id: mira.id, version: mira.version, confirmation: mira.id)
    let branch = try store.createWhatIfBranch(parentID: world.id, name: "If Mira stayed")
    #expect(branch.id != world.id)
    #expect(branch.description == "What-if of Aster")
    #expect(try store.branchInfo(worldID: branch.id)?.parentID == world.id)
    #expect(try store.branchInfo(worldID: world.id) == nil)

    let copy = try #require(try store.records(worldID: branch.id).first { $0.title == "Mira" })
    #expect(copy.id != mira.id)
    _ = try store.saveRecord(
      worldID: branch.id, id: copy.id, version: copy.version, title: "Mira",
      body: "A cartographer who never left.", rtf: nil)
    let original = try store.record(worldID: world.id, id: mira.id)
    #expect(original.body == "A cartographer.")
    #expect(original.state == "canon")
    #expect(try store.branchChanges(worldID: branch.id).map(\.kind) == [.revise])
  }

  @Test func mergeProposesOnlyCleanChangesAndAcceptanceStaysDraft() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Aster")
    let mira = try store.createRecord(
      worldID: world.id, title: "Mira", body: "A cartographer.", kind: "entity")
    let oren = try store.createRecord(
      worldID: world.id, title: "Oren", body: "Eldest keeper.", kind: "entity")
    let sea = try store.createRecord(worldID: world.id, title: "Sea", body: "Glass.")
    _ = try store.promote(
      worldID: world.id, id: mira.id, version: mira.version, confirmation: mira.id)
    let branch = try store.createWhatIfBranch(parentID: world.id, name: "Flooded")
    let copies = Dictionary(
      uniqueKeysWithValues: try store.records(worldID: branch.id).map { ($0.title, $0) })

    // Branch: revise Mira, add a new entity related to Oren, add an event, edit Sea.
    _ = try store.saveRecord(
      worldID: branch.id, id: copies["Mira"]!.id, version: copies["Mira"]!.version,
      title: "Mira", body: "A cartographer who drowned.", rtf: nil)
    let ledger = try store.createRecord(
      worldID: branch.id, title: "The Ledger", body: "Lists every crossing.", kind: "entity")
    _ = try store.addRelation(
      worldID: branch.id, source: copies["Oren"]!.id, target: ledger.id, label: "keeps")
    _ = try store.addEvent(
      worldID: branch.id, title: "The flood", date: "Year 3", source: ledger.id)
    _ = try store.saveRecord(
      worldID: branch.id, id: copies["Sea"]!.id, version: copies["Sea"]!.version, title: "Sea",
      body: "Glass, then water.", rtf: nil)
    // Original: Sea edited meanwhile, so the branch edit conflicts.
    _ = try store.saveRecord(
      worldID: world.id, id: sea.id, version: sea.version, title: "Sea", body: "Black glass.",
      rtf: nil)

    let preview = try store.branchChanges(worldID: branch.id)
    #expect(Set(preview.map(\.kind)) == [.revise, .create, .relate, .event, .conflict])
    let proposal = try store.proposeBranchMerge(worldID: branch.id)
    #expect(proposal.worldID == world.id && proposal.isBranchMerge)
    let actions = proposal.changes.map(\.action)
    #expect(Set(actions) == ["revise_record", "create_record", "relate", "add_event"])
    #expect(actions.count == 4)
    #expect(actions.firstIndex(of: "create_record")! < actions.firstIndex(of: "relate")!)
    #expect(try store.branchInfo(worldID: branch.id)?.lastProposalID == proposal.id)
    #expect(try store.record(worldID: world.id, id: sea.id).body == "Black glass.")

    var current = proposal
    for change in proposal.changes {
      current = try store.resolveChange(
        worldID: world.id, proposalID: proposal.id, changeID: change.id, accept: true,
        confirmation: proposal.id)
    }
    #expect(current.pending == 0)
    let merged = try store.record(worldID: world.id, id: mira.id)
    #expect(merged.body == "A cartographer who drowned.")
    #expect(merged.state == "draft" && merged.canonical != nil)
    let created = try #require(
      try store.records(worldID: world.id).first { $0.title == "The Ledger" })
    #expect(created.origin == "imported")
    #expect(
      try store.relations(worldID: world.id).contains {
        $0.sourceID == oren.id && $0.targetID == created.id && $0.label == "keeps"
      })
    #expect(try store.events(worldID: world.id).contains { $0.sourceID == created.id })
  }

  @Test func reviewedMergeCarriesTypedRelationshipAndResolvesEvidenceByIdentity() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Aster")
    let mira = try store.createRecord(worldID: world.id, title: "Mira", kind: "entity")
    let oren = try store.createRecord(worldID: world.id, title: "Oren", kind: "entity")
    let witness = try store.createRecord(worldID: world.id, title: "Witness account")
    let branch = try store.createWhatIfBranch(parentID: world.id, name: "The winter voyage")
    let copies = Dictionary(
      uniqueKeysWithValues: try store.records(worldID: branch.id).map { ($0.title, $0) })
    let recordInBranch = try store.createRecord(
      worldID: branch.id, title: witness.title, body: "New evidence")
    var attributes = RelationshipAttributes()
    attributes.kind = .mentor
    attributes.startLabel = "Departure in Year 3"
    attributes.endLabel = "Before the winter moot"
    attributes.strength = .strong
    attributes.secrecy = .restricted
    attributes.mutuality = .oneSided
    attributes.status = .ended
    attributes.evidenceRecordIDs = [copies[witness.title]!.id, recordInBranch.id]
    let original = try store.addRelation(
      worldID: branch.id, source: copies["Oren"]!.id, target: copies["Mira"]!.id, label: "mentors",
      attributes: attributes)

    let proposal = try store.proposeBranchMerge(worldID: branch.id)
    let create = try #require(proposal.changes.first { $0.action == "create_record" })
    let relate = try #require(proposal.changes.first { $0.action == "relate" })
    #expect(relate.evidence == [witness.id, "change:\(create.id)"])
    #expect(proposal.prerequisites(for: relate).map(\.id) == [create.id])
    #expect(try store.relations(worldID: world.id).isEmpty)
    #expect(throws: SynthesisError.self) {
      _ = try store.resolveChange(
        worldID: world.id, proposalID: proposal.id, changeID: relate.id, accept: true,
        confirmation: branch.id)
    }
    #expect(throws: SynthesisError.self) {
      _ = try store.resolveChange(
        worldID: world.id, proposalID: proposal.id, changeID: relate.id, accept: true,
        confirmation: proposal.id)
    }
    let partial = try store.resolveChange(
      worldID: world.id, proposalID: proposal.id, changeID: create.id, accept: true,
      confirmation: proposal.id)
    let newEvidenceID = try #require(partial.changes.first { $0.id == create.id }?.resultID)
    #expect(newEvidenceID != witness.id && newEvidenceID != recordInBranch.id)

    try store.archiveRecord(worldID: world.id, id: witness.id)
    #expect(throws: SynthesisError.self) {
      _ = try store.resolveChange(
        worldID: world.id, proposalID: proposal.id, changeID: relate.id, accept: true,
        confirmation: proposal.id)
    }
    #expect(try store.relations(worldID: world.id).isEmpty)
    #expect(try store.proposal(worldID: world.id, id: proposal.id).pending == 1)
    try store.restoreRecord(worldID: world.id, id: witness.id)

    let accepted = try store.resolveChange(
      worldID: world.id, proposalID: proposal.id, changeID: relate.id, accept: true,
      confirmation: proposal.id)
    let edge = try #require(try store.relations(worldID: world.id).first)
    attributes.evidenceRecordIDs = [witness.id, newEvidenceID]
    #expect(edge.sourceID == oren.id && edge.targetID == mira.id && edge.state == "draft")
    #expect(edge.attributes == attributes)
    #expect(accepted.changes.first { $0.id == relate.id }?.evidence == [witness.id, newEvidenceID])
    #expect(try store.relations(worldID: branch.id) == [original])
  }

  @Test func anUnavailableEvidenceRecordBlocksOnlyItsRelationshipBeforeStaging() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Aster")
    _ = try store.createRecord(worldID: world.id, title: "Mira", kind: "entity")
    _ = try store.createRecord(worldID: world.id, title: "Oren", kind: "entity")
    let note = try store.createRecord(worldID: world.id, title: "Testimony")
    let branch = try store.createWhatIfBranch(parentID: world.id, name: "The winter voyage")
    let copies = Dictionary(
      uniqueKeysWithValues: try store.records(worldID: branch.id).map { ($0.title, $0.id) })
    var attributes = RelationshipAttributes()
    attributes.kind = .mentor
    attributes.evidenceRecordIDs = [copies[note.title]!]
    _ = try store.addRelation(
      worldID: branch.id, source: copies["Oren"]!, target: copies["Mira"]!, label: "mentors",
      attributes: attributes)
    _ = try store.createRecord(worldID: branch.id, title: "Sendable note")
    try store.archiveRecord(worldID: world.id, id: note.id)

    let preview = try store.branchChanges(worldID: branch.id)
    #expect(preview.filter(\.sendable).map(\.kind) == [.create])
    #expect(preview.first { !$0.sendable }?.detail.contains("evidence") == true)
    let proposal = try store.proposeBranchMerge(worldID: branch.id)
    #expect(proposal.changes.map(\.action) == ["create_record"])
    #expect(try store.relations(worldID: world.id).isEmpty)
  }

  @Test func modelPayloadCannotSupplyBranchRelationshipMetadata() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Aster")
    let mira = try store.createRecord(worldID: world.id, title: "Mira", kind: "entity")
    let oren = try store.createRecord(worldID: world.id, title: "Oren", kind: "entity")
    var claimedAttributes = RelationshipAttributes()
    claimedAttributes.kind = .mentor
    let proposal = try #require(
      try store.stageProposal(
        worldID: world.id, conversationID: nil, messageID: nil,
        payload: [
          "changes": [
            [
              "action": "relate", "source": oren.id, "target": mira.id, "label": "mentors",
              "relationshipAttributes": claimedAttributes, "relationshipEvidence": [mira.id],
            ]
          ]
        ]))
    #expect(!proposal.isBranchMerge)
    let change = try #require(proposal.changes.first)
    #expect(change.evidence.isEmpty)
    _ = try store.resolveChange(
      worldID: world.id, proposalID: proposal.id, changeID: change.id, accept: true,
      confirmation: proposal.id)
    #expect(try store.relations(worldID: world.id).first?.attributes == .init())
  }

  @Test func emptyBranchCannotBeSent() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Quiet")
    _ = try store.createRecord(worldID: world.id, title: "Note", body: "x")
    let branch = try store.createWhatIfBranch(parentID: world.id, name: "Unchanged")
    #expect(try store.branchChanges(worldID: branch.id).isEmpty)
    #expect(throws: SynthesisError.self) { try store.proposeBranchMerge(worldID: branch.id) }
    #expect(throws: SynthesisError.self) { try store.proposeBranchMerge(worldID: world.id) }
  }
}
