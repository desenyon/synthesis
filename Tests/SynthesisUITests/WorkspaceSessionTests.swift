import AppKit
import SwiftUI
import SynthesisCore
import Testing

@testable import SynthesisUI

@MainActor struct WorkspaceSessionTests {
  @Test func diskRestartRestoresBothEditorsViewsAndNewestDraftWithoutRequests() async throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    let path = folder.appendingPathComponent("session.sqlite").path
    let transport = RecordingResponse()
    let studio = try Studio(store: WorkspaceStore(path: path), transport: transport)
    studio.sheet = nil
    let first = try studio.store.createRecord(
      worldID: studio.worldID, title: "Mira", body: "A cartographer", kind: "entity",
      category: "Characters")
    let second = try studio.store.createRecord(
      worldID: studio.worldID, title: "Sea", body: "A sea", kind: "entity", category: "Places")
    let chat = try studio.store.createConversation(worldID: studio.worldID)
    let lane = try studio.store.createChronologyLane(
      worldID: studio.worldID, name: "Before the tide", kind: "period")
    try studio.reload()
    studio.openChat(chat)
    studio.openRecord(first)
    studio.openBeside(second)
    studio.openRecordTab(.sections, recordID: first.id)
    studio.toggleDocumentPin(first.id)
    studio.graphSelectedID = second.id
    studio.graphView = GraphViewState(
      positions: [first.id: CGPoint(x: -200, y: 130), second.id: CGPoint(x: 140, y: -50)],
      signature: "saved", landscape: true, zoom: 1.4, pan: CGSize(width: 52, height: -91),
      query: "sea", framed: true)
    studio.timelineLaneID = lane.id
    studio.timelineView = TimelineViewState(
      density: .overview, foldedLanes: [lane.id], query: "tide")
    studio.draft = "Earlier idea"
    studio.pendingComposer = (studio.worldID, "Latest unsent idea", studio.draft)
    studio.focusMode = true
    studio.setMode(.manual)
    #expect(studio.saveSessionForClose())
    let reopened = try Studio(store: WorkspaceStore(path: path), transport: transport)
    #expect(reopened.selectedRecord?.id == first.id && reopened.splitRecord?.id == second.id)
    #expect(reopened.documentSession == studio.documentSession)
    #expect(reopened.recordTabs[first.id] == .sections)
    #expect(reopened.graphView == studio.graphView && reopened.graphSelectedID == second.id)
    #expect(reopened.timelineLaneID == lane.id && reopened.timelineView == studio.timelineView)
    #expect(reopened.conversationID == chat.id && reopened.draft == "Latest unsent idea")
    #expect(reopened.mode == .manual && !reopened.focusMode && !reopened.busy)
    #expect(reopened.records == studio.records)
    #expect(await transport.requests.isEmpty)
  }

  @Test func staleAndForeignAddressesDropIndividuallyWithoutLosingLiveWork() throws {
    let studio = try Studio(store: WorkspaceStore(path: ":memory:"))
    studio.sheet = nil
    let live = try studio.store.createRecord(worldID: studio.worldID, title: "Live", kind: "entity")
    let gone = try studio.store.createRecord(worldID: studio.worldID, title: "Archived")
    let other = try studio.store.createWorld(name: "Elsewhere")
    let foreign = try studio.store.createRecord(
      worldID: other.id, title: "Private elsewhere", kind: "entity")
    try studio.reload()
    studio.openRecord(gone)
    studio.openBeside(live)
    var session = studio.workspaceSession()
    session.graphSelection = foreign.id
    session.graph.positions = [foreign.id: CGPoint(x: 1, y: 2), live.id: CGPoint(x: 5, y: 10)]
    session.graph.zoom = 100
    session.canvasID = "gone-board"
    session.conversationID = "gone-chat"
    session.timelineLane = "gone-lane"
    session.editorPositions = [foreign.id: EditorPosition(location: 5, length: 10, scrollY: 0)]
    try studio.store.archiveRecord(worldID: studio.worldID, id: gone.id)
    try studio.store.setPreference(
      "workspace-session:\(studio.worldID)",
      value: String(decoding: JSONEncoder().encode(session), as: UTF8.self))
    let restored = try Studio(store: studio.store)
    #expect(restored.selectedRecord == nil && restored.splitRecord?.id == live.id)
    #expect(restored.openDocuments.map(\.id) == [live.id])
    #expect(restored.graphSelectedID == nil && restored.canvasBoardID == nil)
    #expect(restored.conversationID == nil && restored.timelineLaneID == nil)
    #expect(restored.graphView.positions.count == 1 && restored.graphView.zoom == 2.2)
    #expect(restored.editorPositions.isEmpty && restored.error == nil)
  }

  @Test func sessionsStayWorldScopedAndDoNotOverrideExplicitHomeOrManual() throws {
    let studio = try Studio(store: WorkspaceStore(path: ":memory:"))
    studio.sheet = nil
    let world = studio.worldID
    let record = try studio.store.createRecord(worldID: world, title: "First-world writing")
    let second = try studio.store.createWorld(name: "Second")
    try studio.reload()
    studio.openRecord(record)
    studio.draft = "First-world draft"
    studio.switchWorld(second.id)
    studio.navigate(.atlas)
    studio.draft = "Second-world draft"
    studio.switchWorld(world)
    #expect(studio.selectedRecord?.id == record.id && studio.draft == "First-world draft")
    studio.switchWorld(second.id)
    #expect(
      studio.destination == .atlas && studio.selectedRecord == nil
        && studio.draft == "Second-world draft")
    studio.switchWorld(world)
    studio.updatePreferences { $0.launchWorkspace = "Atlas" }
    #expect(studio.saveSessionForClose())
    let chosen = try Studio(store: studio.store)
    #expect(chosen.destination == .atlas && chosen.selectedRecord == nil)
    #expect(chosen.openDocuments.map(\.id) == [record.id])
    studio.newChat()
    studio.setMode(.manual)
    studio.updatePreferences { $0.launchWorkspace = "remember" }
    #expect(studio.persistWorkspaceSession())
    let manual = try Studio(store: studio.store)
    #expect(manual.mode == .manual && manual.destination == .library)
    let archive = String(
      decoding: try studio.store.exportWorldArchive(worldID: world), as: UTF8.self)
    #expect(!archive.contains("workspace-session") && !archive.contains("editorPositions"))
  }

  @Test func corruptSessionsAreBackedUpAndUnsavedEditorsPreventClose() throws {
    let studio = try Studio(store: WorkspaceStore(path: ":memory:"))
    studio.sheet = nil
    let original = studio.records
    for bad in ["broken json", #"{"version":999}"#] {
      try studio.store.setPreference("workspace-session:\(studio.worldID)", value: bad)
      let restored = try Studio(store: studio.store)
      #expect(restored.error?.contains("preserved") == true && restored.records == original)
      #expect(try studio.store.preference("workspace-session-backup:\(studio.worldID)") == bad)
    }
    studio.editorSave = { false }
    #expect(!studio.saveSessionForClose())
    #expect(
      try studio.store.preference("workspace-session:\(studio.worldID)") == #"{"version":999}"#)
  }

  @Test func quietAutosaveIncludesSelectionAndLatestPendingTyping() async throws {
    let studio = try Studio(store: WorkspaceStore(path: ":memory:"))
    studio.sheet = nil
    studio.navigate(.knowledge)
    studio.graphView.zoom = 1.65
    studio.graphView.query = "harbor"
    studio.draft = "Base"
    studio.pendingComposer = (studio.worldID, "Latest pending", "Base")
    // The full native suite shares MainActor with hundreds of other fixtures. Wait for the
    // observable disk result, not an assumed scheduler order between two elapsed timers.
    let deadline = Date().addingTimeInterval(3)
    while try studio.store.preference("composer:\(studio.worldID)") != "Latest pending",
      Date() < deadline
    {
      try await Task.sleep(for: .milliseconds(40))
    }
    let reopened = try Studio(store: studio.store)
    #expect(reopened.destination == .knowledge && reopened.graphView.zoom == 1.65)
    #expect(reopened.graphView.query == "harbor" && reopened.draft == "Latest pending")
    #expect(!reopened.busy)
  }

  @Test func nativeEditorRestoresClampedSelectionAfterRestart() async throws {
    let studio = try Studio(store: WorkspaceStore(path: ":memory:"))
    studio.sheet = nil
    let record = try studio.store.createRecord(
      worldID: studio.worldID, title: "Journal", body: "The sea remembers.")
    try studio.reload()
    studio.openRecord(record)
    studio.editorPositions[record.id] = EditorPosition(location: 4, length: 3, scrollY: 0)
    #expect(studio.saveSessionForClose())
    let reopened = try Studio(store: studio.store)
    let host = NSHostingView(rootView: EditorScreen(studio: reopened, record: record))
    host.frame = NSRect(x: 0, y: 0, width: 1000, height: 700)
    host.layoutSubtreeIfNeeded()
    try await Task.sleep(for: .milliseconds(120))
    let handle = reopened.editorHandle(for: record)
    handle.scrollView?.layoutSubtreeIfNeeded()
    let text = try #require(handle.view)
    #expect(text.selectedRange() == NSRange(location: 4, length: 3))
    #expect(text.string == record.body && !handle.undoManager.canUndo)
    #expect(reopened.records == studio.records)
  }

  @Test func departingLargeGraphCannotReplaceTheNextUniversesSavedArrangement() async throws {
    let studio = try Studio(store: WorkspaceStore(path: ":memory:"), transport: RecordingResponse())
    studio.sheet = nil
    let firstWorld = studio.worldID
    var firstRecords: [LoreRecord] = []
    for index in 0..<90 {
      firstRecords.append(
        try studio.store.createRecord(
          worldID: firstWorld, title: "First-world entity \(index)", kind: "entity"))
    }
    let second = try studio.store.createWorld(name: "Another graph")
    let a = try studio.store.createRecord(worldID: second.id, title: "A", kind: "entity")
    let b = try studio.store.createRecord(worldID: second.id, title: "B", kind: "entity")
    try studio.reload()
    studio.switchWorld(second.id)
    studio.navigate(.knowledge)
    let expected = GraphViewState(
      positions: [a.id: CGPoint(x: -72, y: 89), b.id: CGPoint(x: 210, y: -23)],
      signature: [a.id, b.id].sorted().joined(separator: ",") + "|true|",
      landscape: true, zoom: 1.3, pan: CGSize(width: 31, height: -17), framed: true)
    studio.graphView = expected
    #expect(studio.persistWorkspaceSession())
    studio.switchWorld(firstWorld)
    studio.navigate(.knowledge)
    // Eighty previously arranged nodes, then ten newly created entities. The old completed
    // arrangement must survive an interrupted recomputation without pretending to include all 90.
    let previousSignature =
      firstRecords.prefix(80).map(\.id).sorted().joined(separator: ",") + "|true|"
    studio.graphView = GraphViewState(
      positions: Dictionary(
        uniqueKeysWithValues: firstRecords.prefix(80).enumerated().map {
          ($0.element.id, CGPoint(x: $0.offset * 30, y: 80))
        }), signature: previousSignature, landscape: true, framed: true)
    let host = NSHostingView(
      rootView: SessionGraphSwitchFixture(studio: studio, target: second.id))
    host.frame = NSRect(x: 0, y: 0, width: 1100, height: 700)
    host.layoutSubtreeIfNeeded()
    try await Task.sleep(for: .milliseconds(250))
    host.layoutSubtreeIfNeeded()
    #expect(studio.worldID == second.id)
    #expect(studio.graphView == expected)
    #expect(studio.error == nil && !studio.busy)
    let raw = try #require(try studio.store.preference("workspace-session:\(firstWorld)"))
    let interrupted = try JSONDecoder().decode(WorkspaceSession.self, from: Data(raw.utf8))
    #expect(interrupted.graph.signature == previousSignature)
    #expect(interrupted.graph.positions.count == 80)
    let reopened = try Studio(store: studio.store, transport: RecordingResponse())
    reopened.switchWorld(firstWorld)
    #expect(reopened.graphView.signature.isEmpty && reopened.graphView.positions.count == 80)
    let resumed = NSHostingView(rootView: RelationshipGraph(studio: reopened))
    resumed.frame = NSRect(x: 0, y: 0, width: 1100, height: 700)
    resumed.layoutSubtreeIfNeeded()
    let deadline = Date().addingTimeInterval(3)
    while reopened.graphView.positions.count != 90, Date() < deadline {
      try await Task.sleep(for: .milliseconds(40))
    }
    #expect(reopened.graphView.positions.count == 90 && !reopened.graphView.signature.isEmpty)
  }

  @Test func revertingTopologyCancelsTheNewerLayoutAndKeepsTheSavedArrangement() async throws {
    let studio = try Studio(store: WorkspaceStore(path: ":memory:"), transport: RecordingResponse())
    studio.sheet = nil
    var records: [LoreRecord] = []
    for index in 0..<90 {
      records.append(
        try studio.store.createRecord(
          worldID: studio.worldID, title: "Entity \(index)", kind: "entity"))
    }
    try studio.reload()
    studio.navigate(.knowledge)
    let completed = GraphViewState(
      positions: Dictionary(
        uniqueKeysWithValues: records.prefix(80).enumerated().map {
          ($0.element.id, CGPoint(x: $0.offset * 20, y: 60))
        }), signature: records.prefix(80).map(\.id).sorted().joined(separator: ",") + "|true|",
      landscape: true, framed: true)
    studio.graphView = completed
    let host = NSHostingView(
      rootView: SessionGraphRevertFixture(studio: studio, removed: Array(records.suffix(10))))
    host.frame = NSRect(x: 0, y: 0, width: 1100, height: 700)
    host.layoutSubtreeIfNeeded()
    try await Task.sleep(for: .milliseconds(350))
    #expect(studio.records.count == 80 && studio.error == nil)
    #expect(studio.graphView == completed)
  }
}

/// Parent appearance runs immediately after the old graph starts its asynchronous layout.
/// The new world is restored before that graph disappears or publishes its pending result.
private struct SessionGraphSwitchFixture: View {
  @ObservedObject var studio: Studio
  let target: String
  var body: some View {
    RelationshipGraph(studio: studio).id(studio.worldID)
      .onAppear {
        if studio.worldID != target { studio.switchWorld(target) }
      }
  }
}

private struct SessionGraphRevertFixture: View {
  @ObservedObject var studio: Studio
  let removed: [LoreRecord]
  var body: some View {
    RelationshipGraph(studio: studio)
      .onAppear {
        studio.perform {
          for record in removed {
            try studio.store.archiveRecord(worldID: studio.worldID, id: record.id)
          }
          try studio.reload()
        }
      }
  }
}
