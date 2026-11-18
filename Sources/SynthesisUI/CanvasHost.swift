import AppKit
import Combine
import SwiftUI
import SynthesisCore
import UniformTypeIdentifiers
import WebKit

enum CanvasMessageScope {
  static func accepts(_ message: [String: Any], current: String) -> Bool {
    message["type"] as? String == "ready" || message["sessionID"] as? String == current
  }
}

/// What a board row holds. New boards store an Excalidraw scene; boards saved by the earlier
/// native canvas (a `CanvasDocument`) are converted the first time they are opened and the
/// original is kept alongside the new scene.
struct CanvasBoardContent {
  var scene: [String: Any]?
  var hiddenRelations: [String] = []
  var legacy: CanvasDocument?
  var legacyRaw: String?
  enum Failure: Error { case unreadable }
  static func decode(_ content: String) throws -> CanvasBoardContent {
    guard let object = try? JSONSerialization.jsonObject(with: Data(content.utf8)) as? [String: Any]
    else { throw Failure.unreadable }
    if object["format"] as? String == "excalidraw" {
      var value = CanvasBoardContent(scene: object["scene"] as? [String: Any] ?? [:])
      value.hiddenRelations = object["hiddenRelations"] as? [String] ?? []
      if let legacy = object["legacy"] {
        value.legacyRaw = (try? JSONSerialization.data(withJSONObject: legacy)).map {
          String(decoding: $0, as: UTF8.self)
        }
      }
      return value
    }
    if object.isEmpty { return CanvasBoardContent(legacy: CanvasDocument(), legacyRaw: content) }
    guard object["cards"] != nil || object["edges"] != nil,
      let legacy = try? JSONDecoder().decode(CanvasDocument.self, from: Data(content.utf8))
    else { throw Failure.unreadable }
    return CanvasBoardContent(legacy: legacy, legacyRaw: content)
  }
  func encoded() throws -> String {
    var object: [String: Any] = [
      "format": "excalidraw", "version": 1, "scene": scene ?? [:],
      "hiddenRelations": hiddenRelations,
    ]
    if let legacyRaw,
      let legacy = try? JSONSerialization.jsonObject(with: Data(legacyRaw.utf8))
    {
      object["legacy"] = legacy
    }
    return String(
      decoding: try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
      as: UTF8.self)
  }
  static var empty: String {
    (try? CanvasBoardContent(scene: ["elements": [Any](), "appState": [String: Any]()]).encoded())
      ?? "{}"
  }
  /// Number of record cards and other elements, for summaries and tests.
  var counts: (cards: Int, elements: Int) {
    let elements = scene?["elements"] as? [[String: Any]] ?? []
    let cards = elements.filter {
      ($0["customData"] as? [String: Any])?["synthesis"] as? String == "card"
    }
    return (cards.count, elements.count)
  }
}

/// The canvas: Excalidraw's engine in a web view that only ever loads files from the
/// application bundle, plus the bridge that keeps cards and arrows in step with the world.
/// One session lives for the whole run so edits still arrive and save after navigation.
@MainActor final class CanvasSession: NSObject, ObservableObject {
  struct Connection: Identifiable {
    let id = UUID()
    let sessionID: String
    var arrowID: String
    var source: LoreRecord
    var target: LoreRecord
    var label: String
  }
  unowned let studio: Studio
  let webView: WKWebView
  @Published var boardID: String?
  @Published var name = "Untitled board"
  @Published var failure: String?
  @Published var loaded = false
  @Published var hiddenCount = 0
  @Published var connection: Connection?
  @Published var editingRelation: RelationshipEditTarget?
  private var capturedElements: Set<String> = []
  /// A request raised from the canvas's own menu: `library`, `entity`, `image` or `export`.
  @Published var request: String?
  /// Records whose cards are selected on the board, and which of those carry artwork.
  @Published var selection: [String] = []
  @Published var selectionWithArt: [String] = []
  @Published private(set) var selectedImageID: String?
  private var pendingReveal: [String] = []
  private var pendingImageReveal: WorldReference?
  private var worldID = ""
  private var content = CanvasBoardContent()
  private var composerHeight: CGFloat = 76
  private var fitInsets: [String: Double] {
    [
      "top": 76, "right": 80, "left": 32,
      "bottom": !studio.focusMode && studio.mode == .assisted && !studio.companionExpanded
        && !studio.splitUsesSharedComposer
        ? Double(composerHeight) + 24 + 76 : 76,
    ]
  }
  func updateFitInsets(composerHeight: CGFloat? = nil) {
    if let composerHeight { self.composerHeight = composerHeight }
    call("setFitInsets", [fitInsets])
  }
  private var ready = false
  private var openRequestID = UUID()
  private var loadID = UUID().uuidString
  private var pendingLoad = false
  private var writable = false
  private struct FlushRequest {
    let continuation: CheckedContinuation<Bool, Never>
    let timeout: Task<Void, Never>
  }
  private var flushRequests: [String: FlushRequest] = [:]
  private var observers: Set<AnyCancellable> = []
  private static let scheme = "synthesis-canvas"

  init(studio: Studio) {
    self.studio = studio
    let configuration = WKWebViewConfiguration()
    let files = BundleFiles()
    configuration.setURLSchemeHandler(files, forURLScheme: Self.scheme)
    webView = WKWebView(frame: .zero, configuration: configuration)
    super.init()
    configuration.userContentController.add(MessageRelay(self), name: "synthesis")
    webView.navigationDelegate = self
    webView.uiDelegate = self
    webView.setValue(false, forKey: "drawsBackground")
    webView.allowsMagnification = false
    webView.allowsBackForwardNavigationGestures = false
    webView.setAccessibilityLabel("Canvas")
    // The capture runner keeps its window behind others. WebKit stops painting occluded
    // windows, which would leave canvas screenshots empty, so occlusion detection is turned
    // off for that runner only. Normal runs are untouched.
    if ProcessInfo.processInfo.environment["SYNTHESIS_CAPTURE_DIR"] != nil {
      let selector = Selector(("_setWindowOcclusionDetectionEnabled:"))
      if webView.responds(to: selector), let method = webView.method(for: selector) {
        typealias Setter = @convention(c) (AnyObject, Selector, Bool) -> Void
        unsafeBitCast(method, to: Setter.self)(webView, selector, false)
      }
    }
    // The first React render must already use the native theme, before the bridge is ready.
    let initialTheme = studio.t.canvasTheme
    webView.load(
      URLRequest(url: URL(string: "\(Self.scheme)://app/index.html?theme=\(initialTheme)")!))
    // Cards follow their records, and the canvas follows the theme.
    studio.$records.dropFirst().debounce(for: .milliseconds(120), scheduler: RunLoop.main)
      .sink { [weak self] _ in self?.sync() }.store(in: &observers)
    studio.$mode.dropFirst().removeDuplicates().sink { [weak self] mode in
      self?.call("setAssistance", [mode == .assisted])
    }.store(in: &observers)
    studio.$dark.combineLatest(studio.$preferences)
      .map { dark, preferences in
        Theme(dark: dark, oled: preferences.darkPalette == .oled).canvasTheme
      }.removeDuplicates().dropFirst().sink { [weak self] theme in
        self?.call("setTheme", [theme])
      }.store(in: &observers)
  }

  // MARK: Boards

  /// Opens the requested board, the last one used in this world, or creates the first.
  func open(boardID requested: String? = nil) {
    let requestID = UUID()
    openRequestID = requestID
    if loaded && (worldID != studio.worldID || (requested != nil && requested != boardID)) {
      Task {
        guard await flush(), openRequestID == requestID, failure == nil else { return }
        openBoard(boardID: requested)
      }
    } else {
      openBoard(boardID: requested)
    }
  }
  private func openBoard(boardID requested: String?) {
    let world = studio.worldID
    do {
      var boards = try studio.store.boards(worldID: world, kind: "canvas")
      if boards.isEmpty {
        boards = [
          try studio.store.saveBoard(
            worldID: world, name: "Untitled board", kind: "canvas",
            content: CanvasBoardContent.empty)
        ]
      }
      let preferred = try requested ?? studio.store.preference("canvas-selected:\(world)")
      let board = boards.first { $0.id == preferred } ?? boards[0]
      if board.id == boardID, world == worldID, loaded { return }
      if let pendingImageReveal,
        pendingImageReveal.worldID != world || pendingImageReveal.containerID != board.id
      {
        self.pendingImageReveal = nil
      }
      loadID = UUID().uuidString
      worldID = world
      boardID = board.id
      name = board.name
      selection = []
      selectionWithArt = []
      selectedImageID = nil
      connection = nil
      editingRelation = nil
      capturedElements = []
      loaded = false
      writable = false
      try studio.store.setPreference("canvas-selected:\(world)", value: board.id)
      do {
        content = try CanvasBoardContent.decode(board.content)
        failure = nil
      } catch {
        // Unreadable data is left exactly as it is; nothing is written over it.
        content = CanvasBoardContent()
        failure = "This board could not be read. It has been left untouched."
        return
      }
      hiddenCount = content.hiddenRelations.count
      pendingLoad = true
      loadIfReady()
    } catch {
      failure = error.localizedDescription
    }
  }
  /// Saves outstanding edits to the board that is open, then opens the requested one.
  func switchBoard(_ id: String?) { open(boardID: id) }
  func rename(_ value: String) {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, let boardID, writable else { return }
    studio.perform {
      let saved = try studio.store.saveBoard(
        worldID: worldID, id: boardID, name: String(trimmed.prefix(120)), kind: "canvas",
        content: try content.encoded())
      name = saved.name
    }
  }
  private func loadIfReady() {
    guard ready, pendingLoad else { return }
    pendingLoad = false
    var payload: [String: Any] = [
      "sessionID": loadID, "assisted": studio.mode == .assisted, "name": name,
      "theme": studio.t.canvasTheme, "fitInsets": fitInsets,
      "hiddenRelations": content.hiddenRelations, "records": recordPayload(),
      "relations": relationPayload(),
    ]
    if let boardID,
      let raw = try? studio.store.preference("canvas-selection:\(worldID):\(boardID)"),
      let ids = try? JSONDecoder().decode([String].self, from: Data(raw.utf8))
    {
      payload["selectedRecordIDs"] = Array(ids.prefix(500)).filter { id in
        studio.records.contains { $0.id == id && $0.worldID == worldID }
      }
    }
    payload["scene"] = content.scene ?? NSNull()
    if content.scene == nil, let legacy = content.legacy,
      let data = try? JSONEncoder().encode(legacy),
      let object = try? JSONSerialization.jsonObject(with: data)
    {
      payload["legacy"] = object
    } else {
      payload["legacy"] = NSNull()
    }
    call("load", [payload])
  }
  private func recordPayload() -> [[String: Any]] {
    studio.records.map {
      [
        "id": $0.id, "title": $0.title, "body": String($0.body.prefix(600)), "kind": $0.kind,
        "category": $0.category, "state": $0.state, "origin": $0.origin,
        "canonKept": $0.canonical != nil,
      ]
    }
  }
  private func relationPayload() -> [[String: Any]] {
    ((try? studio.store.relations(worldID: studio.worldID)) ?? []).map {
      ["id": $0.id, "sourceID": $0.sourceID, "targetID": $0.targetID, "label": $0.label]
    }
  }
  /// Called only after a confirmed flush and a reviewed domain write.
  func reloadStoredBoard() {
    guard worldID == studio.worldID, let id = boardID else { return }
    loaded = false
    writable = false
    openBoard(boardID: id)
  }
  func sync() {
    guard loaded, worldID == studio.worldID else { return }
    call("sync", [recordPayload(), relationPayload()])
  }

  // MARK: Commands

  var dropSessionID: String? {
    // Studio selects the destination before the outgoing engine finishes saving.
    guard loaded, writable, studio.destination == .canvas, studio.selectedRecord == nil,
      worldID == studio.worldID, let boardID,
      studio.canvasBoardID == nil || studio.canvasBoardID == boardID
    else { return nil }
    return loadID
  }

  private func canDrop(on boardID: String, sessionID: String) -> Bool {
    self.boardID == boardID && dropSessionID == sessionID
  }

  var boardReference: WorldReference? {
    guard dropSessionID != nil, let boardID else { return nil }
    return WorldReference(worldID: worldID, kind: .board, id: boardID)
  }

  var selectedImageReference: WorldReference? {
    guard let board = boardReference, let selectedImageID else { return nil }
    return WorldReference(
      worldID: board.worldID, kind: .canvasImage, id: selectedImageID, containerID: board.id)
  }

  /// A native drop is measured in this web view's points. Excalidraw converts it using the
  /// current pan/zoom. The captured board generation prevents a late drop entering another board.
  func drop(_ record: LoreRecord, at point: CGPoint, boardID: String, sessionID: String)
    async throws
  {
    guard canDrop(on: boardID, sessionID: sessionID), record.worldID == worldID,
      point.x.isFinite, point.y.isFinite, webView.bounds.contains(point)
    else { throw SynthesisError.invalid("This canvas changed. Drag the record again.") }
    sync()
    let accepted = try await webView.callAsyncJavaScript(
      "return window.synthesis.dropCard(id, x, y, sessionID)",
      arguments: ["id": record.id, "x": point.x, "y": point.y, "sessionID": sessionID],
      in: nil, contentWorld: .page)
    guard accepted as? Bool == true, canDrop(on: boardID, sessionID: sessionID)
    else { throw SynthesisError.invalid("The record could not be placed on this canvas.") }
    guard await flush() else {
      throw SynthesisError.invalid(failure ?? "The record placement could not be saved.")
    }
    guard canDrop(on: boardID, sessionID: sessionID) else {
      throw SynthesisError.invalid("The canvas changed before its save completed.")
    }
  }

  func drop(_ source: WorldReferenceSource, at point: CGPoint, boardID: String, sessionID: String)
    async throws
  {
    guard canDrop(on: boardID, sessionID: sessionID), source.reference.worldID == worldID,
      point.x.isFinite, point.y.isFinite, webView.bounds.contains(point)
    else { throw SynthesisError.invalid("This canvas changed. Drag the reference again.") }
    let current = try studio.store.resolveReference(source.reference, worldID: worldID)
    if current.reference.kind == .record {
      let record = try studio.store.record(worldID: worldID, id: current.reference.id)
      try await drop(record, at: point, boardID: boardID, sessionID: sessionID)
      return
    }
    let payload = [
      "url": current.reference.url.absoluteString,
      "title": String(current.title.prefix(160)),
      "detail": String(current.detail.prefix(100)),
    ]
    let accepted = try await webView.callAsyncJavaScript(
      "return window.synthesis.dropReference(reference, x, y, sessionID)",
      arguments: ["reference": payload, "x": point.x, "y": point.y, "sessionID": sessionID],
      in: nil, contentWorld: .page)
    guard accepted as? Bool == true, canDrop(on: boardID, sessionID: sessionID)
    else { throw SynthesisError.invalid("The reference could not be placed on this canvas.") }
    guard await flush() else {
      throw SynthesisError.invalid(failure ?? "The reference placement could not be saved.")
    }
    guard canDrop(on: boardID, sessionID: sessionID) else {
      throw SynthesisError.invalid("The canvas changed before its save completed.")
    }
  }

  func revealImage(_ reference: WorldReference) {
    guard reference.kind == .canvasImage, reference.worldID == studio.worldID,
      reference.containerID == studio.canvasBoardID, studio.destination == .canvas
    else { return }
    pendingImageReveal = reference
    revealPendingImage()
  }

  private func revealPendingImage() {
    guard loaded, writable, let reference = pendingImageReveal,
      reference.worldID == worldID, reference.containerID == boardID
    else { return }
    pendingImageReveal = nil
    let sessionID = loadID
    Task {
      guard loadID == sessionID, studio.worldID == reference.worldID,
        studio.canvasBoardID == reference.containerID, studio.destination == .canvas,
        studio.selectedRecord == nil
      else { return }
      let revealed = try? await webView.callAsyncJavaScript(
        "return window.synthesis.revealImage(id, sessionID)",
        arguments: ["id": reference.id, "sessionID": sessionID], in: nil, contentWorld: .page)
      if loadID == sessionID, studio.worldID == reference.worldID,
        studio.destination == .canvas, revealed as? Bool != true
      {
        studio.show(
          "This image is no longer available on the canvas.", icon: "exclamationmark.triangle")
      }
    }
  }

  func add(_ records: [LoreRecord], animateReveal: Bool = true) {
    let ids = records.filter { $0.worldID == worldID }.map(\.id)
    guard !ids.isEmpty else { return }
    guard loaded else {
      pendingReveal.append(contentsOf: ids)
      return
    }
    // A newly saved entity may not exist in the engine's last record snapshot yet.
    // WebKit queues these calls in order; sync the shared model before placing its card.
    sync()
    call("addCards", [ids, animateReveal])
  }
  /// Places a record on the open board (or selects its card) and brings it into view. If the
  /// board is still loading the request waits for it.
  func reveal(_ record: LoreRecord, animate: Bool = true) {
    if loaded, worldID == studio.worldID {
      add([record], animateReveal: animate)
    } else {
      pendingReveal.append(record.id)
    }
  }
  /// Chooses a picture for the top of a record's card. It is stored with the board.
  func chooseArtwork(for recordID: String) {
    studio.perform {
      if let image = try pickImage(limit: 4_000_000) { setArtwork(image, for: recordID) }
    }
  }
  func setArtwork(_ base64: String?, for recordID: String) {
    call("setCardArt", [recordID, base64 ?? NSNull()])
  }
  func addImage() {
    studio.perform {
      if let image = try pickImage(limit: 4_000_000) { call("addImage", [image]) }
    }
  }
  func addImage(_ base64: String) { call("addImage", [base64]) }
  func command(_ name: String) {
    call("command", name == "fit" ? [name, fitInsets] : [name])
  }
  func showHiddenRelations() {
    content.hiddenRelations = []
    hiddenCount = 0
    call("showHiddenRelations", [])
  }
  func exportImage() { call("exportImage", []) }
  /// Asks the canvas to send its latest scene and waits briefly for it to be saved.
  @discardableResult func flush() async -> Bool {
    guard loaded, writable else { return failure == nil }
    let generation = loadID
    let id = UUID().uuidString
    return await withCheckedContinuation { continuation in
      let timeout = Task { @MainActor [weak self] in
        do { try await Task.sleep(for: .milliseconds(900)) } catch { return }
        guard let self else { return }
        if self.loadID == generation {
          self.failure = "The canvas did not confirm its save. Keep this board open and retry."
        }
        self.resumeFlush(id, saved: false)
      }
      flushRequests[id] = FlushRequest(continuation: continuation, timeout: timeout)
      call("command", ["flush", NSNull(), id])
    }
  }
  private func resumeFlush(_ id: String, saved: Bool) {
    guard let request = flushRequests.removeValue(forKey: id) else { return }
    request.timeout.cancel()
    request.continuation.resume(returning: saved)
  }
  func audit() async throws -> [String] {
    guard ProcessInfo.processInfo.environment["SYNTHESIS_CAPTURE_DIR"] != nil else { return [] }
    let value = try await webView.callAsyncJavaScript(
      "return await window.synthesis.audit()", arguments: [:], in: nil, contentWorld: .page)
    var checks = value as? [String] ?? ["FAIL missing engine audit response"]
    if let directory = ProcessInfo.processInfo.environment["SYNTHESIS_CAPTURE_DIR"],
      let png = try await webView.evaluateJavaScript("window.__synthesisAuditPNG ?? null")
        as? String,
      let data = Data(base64Encoded: png)
    {
      try data.write(
        to: URL(fileURLWithPath: directory).appendingPathComponent("canvas-export.png"),
        options: .atomic)
    }
    await flush()
    checks.append(
      failure == nil ? "PASS scene persisted after engine audit" : "FAIL scene save: \(failure!)")
    if let board = try studio.store.boards(worldID: worldID, kind: "canvas").first(where: {
      $0.id == boardID
    }) {
      let saved = try CanvasBoardContent.decode(board.content)
      let files = saved.scene?["files"] as? [String: Any] ?? [:]
      checks.append(
        saved.counts.cards > 0 && !files.isEmpty
          ? "PASS persisted board retains records and image files"
          : "FAIL persisted board missing content")
    } else {
      checks.append("FAIL board missing after audit")
    }
    // Let the engine's trailing autosave settle before simulating a lost acknowledgement.
    try await Task.sleep(for: .milliseconds(650))
    // Withhold only the flush command to verify the native shutdown decision on timeout.
    _ = try await webView.evaluateJavaScript(
      "window.__auditCommand = window.synthesis.command; window.synthesis.command = name => { if (name !== 'flush') window.__auditCommand(name); }; true"
    )
    let blockedFlush = Task { await studio.flushCanvas() }
    let flushDeadline = Date().addingTimeInterval(0.5)
    while flushRequests.isEmpty, Date() < flushDeadline {
      try await Task.sleep(for: .milliseconds(20))
    }
    if let scene = content.scene {
      receive(["type": "change", "sessionID": loadID, "scene": scene])
    }
    let mayClose = await blockedFlush.value
    checks.append(
      !mayClose
        ? "PASS an unrelated autosave does not acknowledge a pending flush"
        : "FAIL shutdown allowed without save acknowledgement")
    _ = try await webView.evaluateJavaScript(
      "window.synthesis.command = window.__auditCommand; delete window.__auditCommand")
    let recovered = await studio.flushCanvas()
    checks.append(
      recovered
        ? "PASS confirmed retry clears canvas save failure" : "FAIL canvas save did not recover")
    // Exercise the complete reviewed proposal -> persisted board -> live engine path.
    let before = await probe()
    if let card = (before["cards"] as? [[String: Any]])?.first,
      let recordID = card["recordID"] as? String, let x = card["x"] as? Double,
      let y = card["y"] as? Double, let boardID,
      let proposal = try studio.store.stageProposal(
        worldID: worldID, conversationID: nil, messageID: nil,
        payload: [
          "changes": [
            [
              "action": "place_record", "source": recordID,
              "board": boardID, "x": x + 36, "y": y + 20,
            ]
          ]
        ])
    {
      studio.resolve(proposal, change: proposal.changes[0], accept: true)
      let deadline = Date().addingTimeInterval(5)
      while studio.reviewingProposal || !loaded, Date() < deadline {
        try await Task.sleep(for: .milliseconds(50))
      }
      try await Task.sleep(for: .milliseconds(250))
      let after = await probe()
      let viewportKeys = ["zoom", "scrollX", "scrollY"]
      let viewportDetail = viewportKeys.map {
        "\($0): \(before[$0] ?? "missing") -> \(after[$0] ?? "missing")"
      }.joined(separator: ", ")
      checks.append(
        viewportKeys.allSatisfy { key in
          guard let a = before[key] as? Double, let b = after[key] as? Double else { return false }
          return abs(a - b) < 0.01
        }
          ? "PASS reviewed placement preserves the viewport"
          : "FAIL reviewed placement changed the viewport: \(viewportDetail)")
      let moved = (after["cards"] as? [[String: Any]])?.first {
        $0["recordID"] as? String == recordID
      }
      checks.append(
        moved?["x"] as? Double == x + 36 && moved?["y"] as? Double == y + 20
          ? "PASS reviewed placement reaches the live engine"
          : "FAIL reviewed placement did not reach the live engine")
      await flush()
      _ = try studio.store.placeRecord(
        worldID: worldID, boardID: boardID, recordID: recordID, x: x, y: y)
      reloadStoredBoard()
      let restoreDeadline = Date().addingTimeInterval(5)
      while !loaded, Date() < restoreDeadline { try await Task.sleep(for: .milliseconds(50)) }
      try await Task.sleep(for: .milliseconds(250))
      let restored = await probe()
      checks.append(
        viewportKeys.allSatisfy { key in
          guard let a = before[key] as? Double, let b = restored[key] as? Double else {
            return false
          }
          return abs(a - b) < 0.01
        }
          ? "PASS repeated board reload retains the viewport"
          : "FAIL repeated board reload lost the viewport")
      studio.toast = nil
    } else {
      checks.append("FAIL missing linked card for reviewed placement audit")
    }
    do {
      let previousSelection = studio.canvasBoardID
      defer { studio.canvasBoardID = previousSelection }
      // Navigation selects the next board before WebKit acknowledges the outgoing save.
      studio.canvasBoardID = UUID().uuidString
      checks.append(
        loaded && dropSessionID == nil && boardReference == nil
          ? "PASS the outgoing canvas stops accepting drops during a board switch"
          : "FAIL the outgoing canvas remains available after the selected board changes")
    }
    if let boardID, let sessionID = dropSessionID {
      let beforeDrop = try content.encoded()
      let record = try studio.store.createRecord(
        worldID: worldID, title: "Dropped source",
        body: "A real linked source in the isolated audit.",
        kind: "entity", category: "Characters")
      try studio.reload()
      let point = CGPoint(x: webView.bounds.width * 0.35, y: webView.bounds.height * 0.4)
      _ = studio.beginRecordDrag(record, monitor: false)
      let dragID = studio.recordDrag!.id
      let accepted = try await studio.receiveRecordDrop(
        JSONEncoder().encode(RecordDragAddress(worldID: worldID, recordID: record.id)),
        target: .canvas(boardID: boardID, sessionID: sessionID, point: point),
        location: studio.navigationLocation, dragID: dragID)
      checks.append(
        accepted ? "PASS native record drop is acknowledged and saved" : "FAIL native record drop")
      let dropped = await probe()
      let position = (dropped["cards"] as? [[String: Any]])?.first {
        $0["recordID"] as? String == record.id
      }
      reloadStoredBoard()
      let deadline = Date().addingTimeInterval(5)
      while !loaded, Date() < deadline { try await Task.sleep(for: .milliseconds(50)) }
      try await Task.sleep(for: .milliseconds(150))
      let restored = await probe()
      let matches =
        (restored["cards"] as? [[String: Any]])?.filter { $0["recordID"] as? String == record.id }
        ?? []
      checks.append(
        matches.count == 1 && position != nil
          && ["x", "y"].allSatisfy {
            position?[$0] as? Double == matches.first?[$0] as? Double
          }
          ? "PASS native record drop survives a board reload without duplicates"
          : "FAIL native drop persistence")
      checks.append(
        try studio.store.record(worldID: worldID, id: record.id) == record
          ? "PASS native record drop preserves source lore and canon state"
          : "FAIL native drop modified lore")
      if let event = try studio.store.events(worldID: worldID).first,
        let referenceSession = dropSessionID
      {
        let reference = WorldReference(worldID: worldID, kind: .event, id: event.id)
        let source = try studio.store.resolveReference(reference, worldID: worldID)
        do {
          try await drop(source, at: point, boardID: boardID, sessionID: sessionID)
          checks.append("FAIL stale reference drop entered the reloaded board")
        } catch {
          checks.append("PASS a stale reference drop cannot enter the reloaded board")
        }
        try await drop(source, at: point, boardID: boardID, sessionID: referenceSession)
        let savedBoard = try studio.store.boards(worldID: worldID, kind: "canvas").first {
          $0.id == boardID
        }
        let savedElements =
          try savedBoard.map { try CanvasBoardContent.decode($0.content) }?
          .scene?["elements"] as? [[String: Any]] ?? []
        let references = savedElements.filter { element in
          let data = element["customData"] as? [String: Any]
          return data?["synthesis"] as? String == "reference"
            && element["link"] as? String == reference.url.absoluteString
        }
        checks.append(
          references.count == 1 && references[0]["x"] is Double && references[0]["y"] is Double
            ? "PASS native event drop confirms a saved reference with board coordinates"
            : "FAIL native event drop did not persist a located reference")
      } else {
        checks.append("FAIL missing writable canvas or event for native reference drop")
      }
      // Keep later appearance fixtures independent from the audit's deliberately overlapping drop.
      _ = try studio.store.saveBoard(
        worldID: worldID, id: boardID, name: name, kind: "canvas", content: beforeDrop)
      try studio.store.archiveRecord(worldID: worldID, id: record.id)
      try studio.reload()
      reloadStoredBoard()
      let cleanupDeadline = Date().addingTimeInterval(5)
      while !loaded, Date() < cleanupDeadline { try await Task.sleep(for: .milliseconds(50)) }
      studio.toast = nil
    } else {
      checks.append("FAIL missing writable canvas for native record drop")
    }
    return checks
  }
  /// Where cards are on screen, for the interaction self-test.
  func probe() async -> [String: Any] {
    guard
      let text = try? await webView.evaluateJavaScript("window.synthesis?.probe() ?? '{}'")
        as? String,
      let object = try? JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any]
    else { return [:] }
    return object
  }
  /// Drags a card with pointer events dispatched inside the page. For the self-test only:
  /// WebKit reports no pressed button for mouse drags posted to a window, so a drag cannot
  /// be driven from outside the web view without a real mouse.
  func testDrag(recordID: String, dx: Double, dy: Double) async -> Bool {
    let result = try? await webView.callAsyncJavaScript(
      "return await window.synthesis.testDrag(id, dx, dy)",
      arguments: ["id": recordID, "dx": dx, "dy": dy], in: nil, contentWorld: .page)
    return result as? String == "done"
  }
  private func call(_ function: String, _ arguments: [Any]) {
    guard let data = try? JSONSerialization.data(withJSONObject: arguments),
      let json = String(data: data, encoding: .utf8)
    else { return }
    webView.evaluateJavaScript("window.synthesis && window.synthesis.\(function)(...\(json))") {
      _, _ in
    }
  }

  // MARK: Messages from the canvas

  fileprivate func receive(_ message: [String: Any]) {
    // Late WebKit messages belong to the board generation that emitted them.
    guard CanvasMessageScope.accepts(message, current: loadID) else {
      return
    }
    switch message["type"] as? String {
    case "ready":
      ready = true
      loadIfReady()
    case "loaded":
      loaded = true
      writable = true
      selection = []
      selectionWithArt = []
      selectedImageID = nil
      store(message, migrated: message["migrated"] as? Bool == true)
      if !pendingReveal.isEmpty {
        sync()
        call("addCards", [pendingReveal])
        pendingReveal = []
      }
      revealPendingImage()
    case "selection":
      selection = message["recordIDs"] as? [String] ?? []
      selectionWithArt = message["withArt"] as? [String] ?? []
      selectedImageID = message["imageID"] as? String
      if writable, let boardID {
        studio.perform {
          try studio.store.setPreference(
            "canvas-selection:\(worldID):\(boardID)",
            value: String(decoding: JSONEncoder().encode(selection), as: UTF8.self))
        }
      }
      if studio.destination == .canvas && studio.selectedRecord == nil {
        studio.followInspectionSelection()
      }
      studio.objectWillChange.send()
    case "change":
      let saved = store(message, migrated: false)
      if let id = message["flushID"] as? String { resumeFlush(id, saved: saved) }
    case "openRecord":
      guard let id = message["id"] as? String else { return }
      if let record = studio.records.first(where: { $0.id == id }) {
        studio.openRecord(record)
      } else {
        studio.show("This card’s record is archived. Restore it from Library.", icon: "archivebox")
      }
    case "openReference":
      guard worldID == studio.worldID, studio.destination == .canvas, studio.selectedRecord == nil,
        let raw = message["url"] as? String, raw.utf8.count <= 2048,
        let url = URL(string: raw)
      else { return }
      _ = studio.openWorkspaceReference(url)
    case "captureText":
      guard let id = message["elementID"] as? String, let body = message["body"] as? String,
        !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, body.count <= 100_000,
        !capturedElements.contains(id)
      else { return }
      studio.perform {
        let record = try studio.store.createRecord(
          worldID: worldID,
          title: String(body.prefix(60)), body: body, kind: "capture")
        capturedElements.insert(id)
        try studio.reload()
        sync()
        call("captureSaved", [id, record.id])
        studio.show("Idea saved in Library and linked to this board.", icon: "lightbulb")
      }
    case "inspectRelation":
      guard worldID == studio.worldID, let id = message["relationID"] as? String,
        let edge = (try? studio.store.relations(worldID: worldID))?.first(where: { $0.id == id })
      else { return }
      editingRelation = RelationshipEditTarget(worldID: worldID, relation: edge)
    case "connect":
      guard worldID == studio.worldID, let arrow = message["arrowID"] as? String,
        let source = studio.records.first(where: { $0.id == message["source"] as? String }),
        let target = studio.records.first(where: { $0.id == message["target"] as? String })
      else { return }
      connection = Connection(
        sessionID: loadID, arrowID: arrow, source: source, target: target,
        label: message["label"] as? String ?? "")
    case "relabel":
      guard let id = message["relationID"] as? String, let label = message["label"] as? String
      else { return }
      do {
        try studio.store.updateRelation(worldID: worldID, id: id, label: label)
        try studio.reload()
      } catch {
        let stored = (try? studio.store.relations(worldID: worldID))?.first { $0.id == id }
        call("relabelRejected", [id, stored?.label ?? label])
        studio.error = error.localizedDescription
      }
    case "relationHidden":
      hiddenCount += 1
      studio.show(
        "Hidden on this board. The relationship “\(message["label"] as? String ?? "")” still exists.",
        icon: "eye.slash")
    case "request":
      request = message["action"] as? String
    case "exportFailed":
      studio.error = message["message"] as? String ?? "This board could not be exported."
    case "exported":
      save(png: message["data"] as? String ?? "")
    default: break
    }
  }
  /// Writes the scene the canvas sent. Image data is only resent when it changes, so the last
  /// known files are carried forward.
  @discardableResult private func store(_ message: [String: Any], migrated: Bool) -> Bool {
    // Saved against the world and board this scene was loaded from, even if the creator has
    // already navigated elsewhere.
    guard writable, let boardID, var scene = message["scene"] as? [String: Any] else {
      return false
    }
    if scene["files"] == nil { scene["files"] = content.scene?["files"] ?? [String: Any]() }
    content.scene = scene
    content.hiddenRelations = message["hiddenRelations"] as? [String] ?? content.hiddenRelations
    hiddenCount = content.hiddenRelations.count
    do {
      _ = try studio.store.saveBoard(
        worldID: worldID, id: boardID, name: name, kind: "canvas", content: try content.encoded())
      failure = nil
    } catch {
      failure = error.localizedDescription
      return false
    }
    if migrated { studio.show("This board now uses the new canvas. The original layout is kept.") }
    return true
  }
  func hideRelationship(_ id: String) { call("hideRelationship", [id]) }
  /// Creates a draft relationship for an arrow the creator drew between two entity cards.
  func saveConnection(_ connection: Connection, label: String, attributes: RelationshipAttributes) {
    guard self.connection?.id == connection.id, connection.sessionID == loadID,
      connection.source.worldID == worldID, connection.target.worldID == worldID,
      studio.worldID == worldID
    else {
      studio.error = "This canvas changed. Draw the relationship again."
      return
    }
    guard studio.flushEditor() else { return }
    studio.perform {
      let relation = try studio.store.addRelation(
        worldID: worldID, source: connection.source.id, target: connection.target.id,
        label: label.trimmingCharacters(in: .whitespacesAndNewlines), attributes: attributes)
      call(
        "relationSaved",
        [
          connection.arrowID,
          [
            "id": relation.id, "sourceID": relation.sourceID, "targetID": relation.targetID,
            "label": relation.label,
          ],
        ])
      self.connection = nil
      try studio.reload()
    }
  }
  private func save(png base64: String) {
    guard let data = Data(base64Encoded: base64), !data.isEmpty else {
      studio.show("There is nothing on this board to export yet.", icon: "square.dashed")
      return
    }
    let panel = NSSavePanel()
    panel.allowedContentTypes = [.png]
    panel.nameFieldStringValue = "\(name).png"
    if panel.runModal() == .OK, let url = panel.url {
      studio.perform {
        try data.write(to: url, options: .atomic)
        studio.show("Exported \(url.lastPathComponent)", icon: "square.and.arrow.up")
      }
    }
  }
}

extension CanvasSession: WKNavigationDelegate, WKUIDelegate {
  /// Only the bundled canvas may load. Links a person clicks open in their browser instead.
  func webView(
    _ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
    decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void
  ) {
    guard let url = action.request.url else { return decisionHandler(.cancel) }
    if url.scheme == Self.scheme || url.scheme == "about" || url.scheme == "blob" {
      return decisionHandler(.allow)
    }
    if action.navigationType == .linkActivated, ["http", "https"].contains(url.scheme ?? "") {
      NSWorkspace.shared.open(url)
    }
    decisionHandler(.cancel)
  }
  func webView(
    _ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
    for action: WKNavigationAction, windowFeatures: WKWindowFeatures
  ) -> WKWebView? {
    if let url = action.request.url, ["http", "https"].contains(url.scheme ?? "") {
      NSWorkspace.shared.open(url)
    }
    return nil
  }
  /// Excalidraw's image tool uses a file input; this supplies the native open panel.
  func webView(
    _ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters,
    initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping @MainActor ([URL]?) -> Void
  ) {
    let panel = NSOpenPanel()
    panel.allowsMultipleSelection = parameters.allowsMultipleSelection
    panel.allowedContentTypes = [.image]
    completionHandler(panel.runModal() == .OK ? panel.urls : nil)
  }
}

/// Breaks the retain cycle between the web view's content controller and the session.
private final class MessageRelay: NSObject, WKScriptMessageHandler {
  weak var session: CanvasSession?
  init(_ session: CanvasSession) { self.session = session }
  func userContentController(
    _ controller: WKUserContentController, didReceive message: WKScriptMessage
  ) {
    guard let body = message.body as? [String: Any] else { return }
    Task { @MainActor [weak session] in session?.receive(body) }
  }
}

/// Serves the canvas bundle from inside the application under its own URL scheme. Nothing
/// else can be requested: the content security policy forbids every other origin.
private final class BundleFiles: NSObject, WKURLSchemeHandler {
  static let root: URL? = {
    let bundled = Bundle.main.resourceURL?.appendingPathComponent("CanvasBundle")
    if let bundled, FileManager.default.fileExists(atPath: bundled.path) { return bundled }
    return Bundle.module.url(forResource: "CanvasBundle", withExtension: nil)
  }()
  static let policy =
    "default-src 'self' data: blob:; script-src 'self' 'unsafe-eval' 'unsafe-inline' blob:; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; font-src 'self' data:; connect-src 'self' data: blob:; worker-src 'self' blob:; frame-src 'none'"
  private static let types = [
    "html": "text/html; charset=utf-8", "js": "text/javascript; charset=utf-8",
    "css": "text/css; charset=utf-8", "json": "application/json", "svg": "image/svg+xml",
    "png": "image/png", "woff2": "font/woff2", "woff": "font/woff", "ttf": "font/ttf",
    "wasm": "application/wasm", "ico": "image/x-icon",
  ]
  func webView(_ webView: WKWebView, start task: any WKURLSchemeTask) {
    guard let url = task.request.url, let root = Self.root else {
      return task.didFailWithError(URLError(.fileDoesNotExist))
    }
    let path = url.path.isEmpty || url.path == "/" ? "/index.html" : url.path
    let file = root.appendingPathComponent(String(path.dropFirst())).standardizedFileURL
    // Never serve anything outside the bundle, whatever the requested path says.
    guard file.path.hasPrefix(root.standardizedFileURL.path), let data = try? Data(contentsOf: file)
    else { return task.didFailWithError(URLError(.fileDoesNotExist)) }
    let response = HTTPURLResponse(
      url: url, statusCode: 200, httpVersion: "HTTP/1.1",
      headerFields: [
        "Content-Type": Self.types[file.pathExtension.lowercased()] ?? "application/octet-stream",
        "Content-Length": String(data.count), "Content-Security-Policy": Self.policy,
        "Access-Control-Allow-Origin": "*", "Cache-Control": "no-cache",
      ])!
    task.didReceive(response)
    task.didReceive(data)
    task.didFinish()
  }
  func webView(_ webView: WKWebView, stop task: any WKURLSchemeTask) {}
}

/// Where the Canvas workspace wants the engine to appear, in the shell's coordinate space.
struct CanvasFrameKey: PreferenceKey {
  static let defaultValue: CGRect? = nil
  static func reduce(value: inout CGRect?, nextValue: () -> CGRect?) {
    value = nextValue() ?? value
  }
}

/// Places the session's long-lived web view in the SwiftUI hierarchy. The shell mounts it once.
struct CanvasWebView: NSViewRepresentable {
  let session: CanvasSession
  var visible = true
  func makeNSView(context: Context) -> NSView {
    let container = NSView()
    attach(to: container)
    return container
  }
  func updateNSView(_ container: NSView, context: Context) { attach(to: container) }
  private func attach(to container: NSView) {
    let web = session.webView
    web.isHidden = !visible
    guard web.superview !== container else { return }
    web.removeFromSuperview()
    web.frame = container.bounds
    web.autoresizingMask = [.width, .height]
    container.addSubview(web)
  }
}
