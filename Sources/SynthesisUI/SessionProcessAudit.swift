import Foundation
import SynthesisCore

extension Studio {
  /// Two executions of the actual app binary, with no windows or provider access. The path is
  /// derived from a dedicated temporary directory; this cannot reopen the creator's database.
  public static func auditSessionProcess(
    phase: String, directory: String, token: String, transport: any ModelTransport
  ) throws {
    let folder = URL(fileURLWithPath: directory).standardizedFileURL.resolvingSymlinksInPath()
    let temporary = FileManager.default.temporaryDirectory.standardizedFileURL
      .resolvingSymlinksInPath()
    guard ProcessInfo.processInfo.environment["SYNTHESIS_CAPTURE_DIR"] == directory,
      folder.deletingLastPathComponent() == temporary,
      folder.lastPathComponent.hasPrefix("synthesis-session."), UUID(uuidString: token) != nil,
      ["write", "read"].contains(phase)
    else { throw SynthesisError.invalid("Session process audit needs its own temporary fixture.") }
    let path = folder.appendingPathComponent("session.sqlite").path
    let receipt = folder.appendingPathComponent("expectation.json")
    if phase == "write" {
      guard !FileManager.default.fileExists(atPath: path),
        !FileManager.default.fileExists(atPath: receipt.path)
      else { throw SynthesisError.invalid("The session fixture must start empty.") }
      let studio = try Studio(store: WorkspaceStore(path: path), transport: transport)
      let first = try studio.store.createRecord(
        worldID: studio.worldID, title: "Process audit cartographer", body: "Authored fixture.",
        kind: "entity", category: "Characters")
      let second = try studio.store.createRecord(
        worldID: studio.worldID, title: "Process audit sea", body: "Authored fixture.",
        kind: "entity", category: "Places")
      let chat = try studio.store.createConversation(worldID: studio.worldID)
      let message = try studio.store.appendMessage(
        worldID: studio.worldID, conversationID: chat.id, role: "user",
        body: "An authored fixture message.", state: "complete")
      let lane = try studio.store.createChronologyLane(
        worldID: studio.worldID, name: "Before the crossing", kind: "period")
      try studio.reload()
      studio.openChat(chat)
      studio.navigate(.knowledge)
      studio.openRecord(first)
      studio.openBeside(second)
      studio.openRecordTab(.sections, recordID: first.id)
      studio.toggleDocumentPin(first.id)
      studio.editorPositions[first.id] = EditorPosition(location: 3, length: 4, scrollY: 18)
      studio.graphSelectedID = first.id
      studio.graphView = GraphViewState(
        positions: [first.id: CGPoint(x: -90, y: 20), second.id: CGPoint(x: 210, y: 70)],
        signature: "process-audit", landscape: true, zoom: 1.25,
        pan: CGSize(width: 72, height: -43), query: "sea", framed: true)
      studio.timelineLaneID = lane.id
      studio.timelineView = TimelineViewState(density: .overview, foldedLanes: [lane.id])
      studio.conversationScrollAnchors[chat.id] = message.id
      studio.draft = "Earlier message"
      studio.pendingComposer = (studio.worldID, "Newest unsent message", studio.draft)
      studio.setMode(.manual)
      studio.updatePreferences { $0.launchWorkspace = "remember" }
      guard studio.saveSessionForClose() else {
        throw SynthesisError.invalid("The first process could not save its session.")
      }
      let expected = SessionProcessExpectation(
        token: token, session: studio.workspaceSession(), draft: "Newest unsent message",
        records: try studio.store.records(worldID: studio.worldID))
      try JSONEncoder().encode(expected).write(to: receipt, options: .atomic)
      print("SESSION_PROCESS PASS write: on-disk native session, editors, views and newest draft")
    } else {
      let expected = try JSONDecoder().decode(
        SessionProcessExpectation.self, from: Data(contentsOf: receipt))
      guard expected.token == token, FileManager.default.fileExists(atPath: path) else {
        throw SynthesisError.invalid("This is not the expected isolated session fixture.")
      }
      let studio = try Studio(store: WorkspaceStore(path: path), transport: transport)
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.sortedKeys]
      guard try encoder.encode(studio.workspaceSession()) == encoder.encode(expected.session),
        studio.draft == expected.draft, studio.records == expected.records,
        studio.mode == .manual, !studio.busy, studio.error == nil
      else { throw SynthesisError.invalid("A new process did not restore the original session.") }
      print(
        "SESSION_PROCESS PASS read: separate process restored exact state; lore and Manual unchanged"
      )
    }
  }
}

private struct SessionProcessExpectation: Codable {
  var token: String
  var session: WorkspaceSession
  var draft: String
  var records: [LoreRecord]
}
