import AppKit
import Foundation
import SynthesisCore

extension Studio {
  public func reopenedSessionCapture(
    _ state: String, board: String, conversation: String, transport: any ModelTransport
  ) async throws -> Studio {
    guard ProcessInfo.processInfo.environment["SYNTHESIS_CAPTURE_DIR"] != nil else {
      throw SynthesisError.invalid("Session capture requires isolated data.")
    }
    let base: String
    if state.hasSuffix("atlas") {
      base = "atlas-context-return"
    } else if state.hasSuffix("graph") {
      base = "graph"
    } else if state.hasSuffix("timeline") {
      base = "timeline-overview"
    } else if state.hasSuffix("canvas") {
      base = "canvas"
    } else if state.hasSuffix("conversation") {
      base = "conversation"
    } else if state.hasSuffix("split") {
      base = "split-editor"
    } else if state.hasSuffix("library") {
      base = "library"
    } else {
      base = "editor"
    }
    guard flushEditor(), await flushCanvas() else {
      throw SynthesisError.invalid("Previous capture did not save.")
    }
    configureConnectedCapture(base, board: board, conversation: conversation)
    dark = !state.hasPrefix("light-")
    if state.hasPrefix("manual-") { setMode(.manual) }
    inspector = false
    workspaceInspector = false
    companionExpanded = false
    updatePreferences { $0.launchWorkspace = "remember" }
    try store.setPreference("theme", value: dark ? "dark" : "light")
    if let record = selectedRecord {
      if state.hasSuffix("sections") { openRecordTab(.sections, recordID: record.id) }
      if let other = records.first(where: { $0.title == "The Glass Sea" && $0.id != record.id }) {
        retainDocument(other)
      }
      toggleDocumentPin(record.id)
    }
    if state.hasSuffix("graph") {
      let ids = records.filter { $0.kind == "entity" }.map(\.id).sorted()
      let relations = try store.relations(worldID: worldID)
      graphView.positions = GraphLayout.positions(
        nodes: ids, edges: relations.map { ($0.sourceID, $0.targetID) })
      graphView.landscape = true
      graphView.signature =
        ids.joined(separator: ",") + "|true|"
        + relations.map { "\($0.sourceID)>\($0.targetID)" }.sorted().joined(separator: ",")
      graphView.zoom = 0.8
      graphView.framed = true
      graphSelectedID = records.first { $0.title == "Mira Vale" }?.id
      if let id = graphSelectedID, let point = graphView.positions[id] {
        graphView.pan = CGSize(width: -point.x * 0.8 - 160, height: -point.y * 0.8)
      }
    }
    if state.hasSuffix("timeline") {
      try reload()
      timelineView.density = .overview
      timelineLaneID = contextLanes.first { $0.name == "The Eastern Crossing" }?.id
    }
    if state.hasSuffix("library") {
      libraryCategory = "Places"
      libraryQuery = "sea"
      libraryFilter = .entities
      libraryOrder = .title
    }
    let initialDraft = "Explore what Mira remembers about the Glass Sea. Keep it as a draft."
    let expectedDraft = initialDraft + " Include the Tidekeepers."
    draft = initialDraft
    try await Task.sleep(for: .milliseconds(250))
    if state.hasSuffix("canvas") {
      let deadline = Date().addingTimeInterval(10)
      while !canvasLoaded && Date() < deadline {
        try await Task.sleep(for: .milliseconds(50))
      }
      guard canvasLoaded else { throw SynthesisError.invalid("Session Canvas did not load.") }
      captureCanvasSelection(animate: false)
      guard await flushCanvas() else {
        throw SynthesisError.invalid("The original Canvas did not confirm its save.")
      }
      let snapshot = await canvas().probe()
      let keys: Set<String> = ["selectedRecordIDs", "zoom", "scrollX", "scrollY", "cards"]
      let expected = snapshot.filter { keys.contains($0.key) }
      guard let selected = expected["selectedRecordIDs"] as? [String], !selected.isEmpty else {
        throw SynthesisError.invalid("The original Canvas selection was not committed.")
      }
      let saved = try store.boards(worldID: worldID, kind: "canvas").first {
        $0.id == canvas().boardID
      }
      let scene = try saved.flatMap { try CanvasBoardContent.decode($0.content).scene }
      let viewport = scene?["appState"] as? [String: Any] ?? [:]
      try compareCanvasViewport(expected: expected, actual: viewport, step: "Canvas save")
      try store.setPreference(
        "capture-session-canvas",
        value: String(decoding: JSONSerialization.data(withJSONObject: expected), as: UTF8.self))
    }
    guard flushEditor() else {
      throw SynthesisError.invalid("Session capture could not save its original workspace.")
    }
    if !state.hasSuffix("canvas"), !(await flushCanvas()) {
      throw SynthesisError.invalid("Session capture could not save its original Canvas.")
    }
    let editorID = selectedRecord?.id
    let range = NSRange(location: 4, length: 3)
    if let record = selectedRecord {
      let handle = editorHandle(for: record)
      if let view = handle.view {
        view.setSelectedRange(range)
      } else {
        handle.pendingPosition = EditorPosition(
          location: range.location, length: range.length, scrollY: 0)
      }
    }
    pendingComposer = (worldID, expectedDraft, draft)
    guard saveSessionForClose() else {
      throw SynthesisError.invalid("Session capture could not save its original workspace.")
    }
    let location = navigationLocation
    let graph = graphView
    let timeline = timelineView
    let sources = try store.records(worldID: worldID)
    sessionSaveTask?.cancel()
    sessionObservation = nil
    let reopened = try Studio(store: store, transport: transport)
    guard reopened.navigationLocation == location, reopened.graphView == graph,
      reopened.timelineView == timeline, reopened.draft == expectedDraft,
      reopened.mode == mode, reopened.records == sources, !reopened.busy, !reopened.focusMode,
      reopened.documentSession == documentSession, reopened.recordTabs == recordTabs,
      reopened.error == nil
    else { throw SynthesisError.invalid("Session reconstruction differed for \(state).") }
    if let editorID {
      guard let position = reopened.editorPositions[editorID], position.location == range.location,
        position.length == range.length
      else { throw SynthesisError.invalid("Session reconstruction lost the selected text.") }
    }
    reopened.captureHint = state
    print(
      "SESSION_AUDIT PASS \(state): new native root restored views, tabs, selection and latest draft; lore/mode unchanged"
    )
    return reopened
  }

  public func auditRestoredWritingSession() throws {
    guard ProcessInfo.processInfo.environment["SYNTHESIS_CAPTURE_DIR"] != nil,
      let record = selectedRecord,
      editorHandle(for: record).view?.selectedRange() == NSRange(location: 4, length: 3)
    else { throw SynthesisError.invalid("The reopened editor did not select the saved text.") }
    print("SESSION_AUDIT PASS fresh native editor restored the selected text")
  }

  /// Compare the newly mounted engine with its pre-reconstruction state. The expectation is
  /// isolated fixture data; it never shares preferences or a database with the creator's app.
  public func auditRestoredCanvasSession() async throws {
    guard ProcessInfo.processInfo.environment["SYNTHESIS_CAPTURE_DIR"] != nil,
      captureHint == "session-canvas",
      let raw = try store.preference("capture-session-canvas"),
      let expected = try JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any]
    else { throw SynthesisError.invalid("Missing Canvas session expectation.") }
    let actual = await canvas().probe()
    try compareCanvasViewport(expected: expected, actual: actual, step: "Canvas restore")
    guard expected["selectedRecordIDs"] as? [String] == actual["selectedRecordIDs"] as? [String],
      let cards = actual["cards"] as? [[String: Any]],
      let oldCards = expected["cards"] as? [[String: Any]], cards.count == oldCards.count
    else { throw SynthesisError.invalid("Canvas session lost its selection or cards.") }
    for old in oldCards {
      guard let id = old["recordID"] as? String,
        let card = cards.first(where: { $0["recordID"] as? String == id }),
        card["x"] as? Double == old["x"] as? Double,
        card["y"] as? Double == old["y"] as? Double
      else { throw SynthesisError.invalid("Canvas session moved a stored card.") }
    }
    print("SESSION_AUDIT PASS fresh Canvas engine restores selection, viewport and stored cards")
  }

  private func compareCanvasViewport(
    expected: [String: Any], actual: [String: Any], step: String
  ) throws {
    for key in ["zoom", "scrollX", "scrollY"] {
      let before = expected[key] as? Double
      let after = actual[key] as? Double
      guard let before, let after, abs(before - after) < 0.01 else {
        throw SynthesisError.invalid(
          "\(step) changed \(key) from \(before.map(String.init(describing:)) ?? "missing") to \(after.map(String.init(describing:)) ?? "missing")."
        )
      }
    }
  }
}
