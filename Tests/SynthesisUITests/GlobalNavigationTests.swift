import AppKit
import SwiftUI
import SynthesisCore
import Testing

@testable import SynthesisUI

@MainActor struct GlobalNavigationTests {
  @Test func documentsMapsChatsAndToolSubpagesReplayThroughOneHistory() throws {
    let studio = try Studio(store: WorkspaceStore(path: ":memory:"))
    studio.setMode(.manual)
    let world = studio.worldID
    let character = try studio.store.createRecord(worldID: world, title: "Mira", kind: "entity")
    let map = try studio.store.createAtlasMap(worldID: world, name: "Coast")
    let board = try studio.store.saveBoard(
      worldID: world, name: "Ideas", kind: "canvas", content: CanvasBoardContent.empty)
    let lane = try studio.store.createChronologyLane(
      worldID: world, name: "First age", kind: "period")
    let chat = try studio.store.createConversation(worldID: world, title: "Crossing")
    let proposal = try #require(
      try studio.store.stageProposal(
        worldID: world, conversationID: chat.id, messageID: nil,
        payload: [
          "summary": "Possible coast",
          "changes": [
            ["action": "create_record", "title": "Possible isle", "body": "Unaccepted suggestion"]
          ],
        ]))
    try studio.reload()
    studio.openLens("Characters")
    studio.libraryQuery = "Mira"
    studio.libraryFilter = .entities
    studio.libraryOrder = .title
    studio.navigationBack = []
    studio.navigationForward = []
    var visits = [studio.navigationLocation]
    let actions: [() -> Void] = [
      { studio.openRecord(character) },
      { studio.openRecordTab(.sections, recordID: character.id) },
      { studio.openRecordTab(.mechanics, recordID: character.id) },
      { studio.openBoard(map.id, kind: "atlas") },
      { studio.openBoard(board.id, kind: "canvas") },
      { studio.openTimelineLane(lane.id) },
      { studio.openTimelineLane(nil) },
      { studio.openSettings(.writing) },
      { studio.openSettings(.data, query: "Markdown") },
      { studio.openReviewSection(.canon) },
      { studio.openProposalReview(proposal.id) },
      { studio.openChat(chat) },
    ]
    for action in actions {
      let count = studio.navigationBack.count
      action()
      #expect(studio.error == nil && studio.navigationBack.count == count + 1)
      visits.append(studio.navigationLocation)
    }
    for expected in visits.dropLast().reversed() {
      studio.goBack()
      #expect(studio.navigationLocation == expected)
    }
    #expect(!studio.canNavigateBack)
    for expected in visits.dropFirst() {
      studio.goForward()
      #expect(studio.navigationLocation == expected)
    }
    #expect(!studio.canNavigateForward && studio.mode == .manual && !studio.busy)
    #expect(
      try studio.store.proposal(worldID: world, id: proposal.id).changes.allSatisfy {
        $0.status == "pending"
      })
    #expect(try studio.store.record(worldID: world, id: character.id) == character)
  }

  @Test func sameWorkspaceVisitsKeepSaveGuardsAndLibraryRootClearsTheCategory() throws {
    let studio = try Studio(store: WorkspaceStore(path: ":memory:"))
    studio.openLens("Places")
    let category = studio.navigationLocation
    studio.navigate(.library)
    #expect(studio.libraryCategory == nil)
    studio.goBack()
    #expect(studio.navigationLocation == category)
    let record = try studio.store.createRecord(
      worldID: studio.worldID, title: "Mira", kind: "entity")
    try studio.reload()
    studio.openRecord(record)
    studio.editorSave = { true }
    studio.openRecordTab(.sections, recordID: record.id)
    studio.openRecordTab(.mechanics, recordID: record.id)
    studio.goBack()
    #expect(studio.recordTabs[record.id] == .sections && studio.editorSave != nil)
    let back = studio.navigationBack
    let forward = studio.navigationForward
    let location = studio.navigationLocation
    studio.editorSave = { false }
    studio.goForward()
    studio.openSettings(.data)
    studio.openReviewSection(.checks)
    studio.openTimelineLane(nil)
    studio.openRecordTab(.overview, recordID: record.id)
    #expect(studio.navigationBack == back && studio.navigationForward == forward)
    #expect(studio.navigationLocation == location)
    studio.editorSave = nil
    studio.navigate(.atlas)
    var saves = 0
    studio.editorSave = {
      saves += 1
      return true
    }
    let history = studio.navigationBack
    studio.navigate(.atlas)
    #expect(studio.editorSave != nil && saves == 1 && studio.navigationBack == history)
  }

  @Test func activityInspectorReturnsAndRemovedOrForeignOptionalSourcesClear() throws {
    let studio = try Studio(store: WorkspaceStore(path: ":memory:"))
    let record = try studio.store.createRecord(worldID: studio.worldID, title: "A crossing")
    let event = try studio.store.saveChronologyEvent(
      worldID: studio.worldID, id: nil, title: "First crossing", date: "Year 1", source: record.id,
      order: nil, laneID: nil)
    try studio.reload()
    studio.navigate(.timeline)
    studio.inspect(.event(event.id))
    let visit = studio.navigationLocation
    studio.openRecord(record)
    studio.goBack()
    #expect(studio.navigationLocation == visit && studio.inspectionTarget == .event(event.id))
    let other = try studio.store.createWorld(name: "Other")
    let foreign = try studio.store.createRecord(worldID: other.id, title: "Private")
    var bad = visit
    bad.context?.inspection = .record(foreign.id)
    #expect(studio.restoreNavigation(bad) && studio.inspectionTarget == nil)
    try studio.store.archiveRecord(worldID: studio.worldID, id: record.id)
    bad.context?.inspection = .record(record.id)
    #expect(studio.restoreNavigation(bad) && studio.inspectionTarget == nil)
    let invalid = studio.navigationLocation
    studio.openTimelineLane("not-in-this-world")
    #expect(studio.navigationLocation == invalid)
  }

  @Test func nativeEditorRemainsSaveableAfterBackBetweenToolPages() async throws {
    _ = NSApplication.shared
    let studio = try Studio(store: WorkspaceStore(path: ":memory:"))
    let record = try studio.store.createRecord(
      worldID: studio.worldID, title: "Remembrance", body: "A memory has a cost.", kind: "entity",
      category: "Power systems")
    try studio.reload()
    studio.openRecord(record)
    let host = NSHostingView(rootView: EditorScreen(studio: studio, record: record))
    host.frame = CGRect(x: 0, y: 0, width: 900, height: 700)
    host.layoutSubtreeIfNeeded()
    try await Task.sleep(for: .milliseconds(100))
    #expect(studio.editorSave != nil)
    studio.openRecordTab(.sections, recordID: record.id)
    studio.openRecordTab(.mechanics, recordID: record.id)
    studio.goBack()
    host.layoutSubtreeIfNeeded()
    try await Task.sleep(for: .milliseconds(100))
    #expect(
      studio.recordTabs[record.id] == .sections && studio.editorSave != nil && studio.flushEditor())
    #expect(try studio.store.record(worldID: studio.worldID, id: record.id) == record)
  }
}
