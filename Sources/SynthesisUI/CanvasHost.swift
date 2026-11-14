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
  /// A request raised from the canvas's own menu: `library`, `entity`, `image` or `export`.
  @Published var request: String?
  /// Records whose cards are selected on the board, and which of those carry artwork.
  @Published var selection: [String] = []
  @Published var selectionWithArt: [String] = []
  private var pendingReveal: [String] = []
  private var worldID = ""
  private var content = CanvasBoardContent()
  private var ready = false
  private var openRequestID = UUID()
  private var loadID = UUID().uuidString
  private var pendingLoad = false
  private var writable = false
  private var flushWaiters: [CheckedContinuation<Void, Never>] = []
  private var flushTimeout: Task<Void, Never>?
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
    webView.load(URLRequest(url: URL(string: "\(Self.scheme)://app/index.html")!))
    // Cards follow their records, and the canvas follows the theme.
    studio.$records.dropFirst().debounce(for: .milliseconds(120), scheduler: RunLoop.main)
      .sink { [weak self] _ in self?.sync() }.store(in: &observers)
    studio.$mode.dropFirst().removeDuplicates().sink { [weak self] mode in
      self?.call("setAssistance", [mode == .assisted])
    }.store(in: &observers)
    studio.$dark.dropFirst().removeDuplicates().sink { [weak self] dark in
      self?.call("setTheme", [dark ? "dark" : "light"])
    }.store(in: &observers)
  }

  // MARK: Boards

  /// Opens the requested board, the last one used in this world, or creates the first.
  func open(boardID requested: String? = nil) {
    let requestID = UUID()
    openRequestID = requestID
    if loaded && (worldID != studio.worldID || (requested != nil && requested != boardID)) {
      Task {
        await flush()
        guard openRequestID == requestID, failure == nil else { return }
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
      loadID = UUID().uuidString
      worldID = world
      boardID = board.id
      name = board.name
      selection = []
      selectionWithArt = []
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
      "theme": studio.dark ? "dark" : "light",
      "hiddenRelations": content.hiddenRelations, "records": recordPayload(),
      "relations": relationPayload(),
    ]
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
  func sync() {
    guard loaded, worldID == studio.worldID else { return }
    call("sync", [recordPayload(), relationPayload()])
  }

  // MARK: Commands

  func add(_ records: [LoreRecord]) { call("addCards", [records.map(\.id)]) }
  /// Places a record on the open board (or selects its card) and brings it into view. If the
  /// board is still loading the request waits for it.
  func reveal(_ record: LoreRecord) {
    if loaded, worldID == studio.worldID {
      add([record])
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
  func command(_ name: String) { call("command", [name]) }
  func showHiddenRelations() {
    content.hiddenRelations = []
    hiddenCount = 0
    call("showHiddenRelations", [])
  }
  func exportImage() { call("exportImage", []) }
  /// Asks the canvas to send its latest scene and waits briefly for it to be saved.
  func flush() async {
    guard loaded, writable else { return }
    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
      flushWaiters.append(continuation)
      guard flushWaiters.count == 1 else { return }
      flushTimeout = Task { @MainActor [weak self] in
        do { try await Task.sleep(for: .milliseconds(900)) } catch { return }
        guard let self, !self.flushWaiters.isEmpty else { return }
        self.failure = "The canvas did not confirm its save. Keep this board open and retry."
        self.resumeFlush()
      }
      command("flush")
    }
  }
  private func resumeFlush() {
    flushTimeout?.cancel()
    flushTimeout = nil
    let waiting = flushWaiters
    flushWaiters = []
    for continuation in waiting { continuation.resume() }
  }
  func audit() async throws -> [String] {
    guard ProcessInfo.processInfo.environment["SYNTHESIS_CAPTURE_DIR"] != nil else { return [] }
    let value = try await webView.callAsyncJavaScript(
      "return await window.synthesis.audit()", arguments: [:], in: nil, contentWorld: .page)
    var checks = value as? [String] ?? ["FAIL missing engine audit response"]
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
      store(message, migrated: message["migrated"] as? Bool == true)
      if !pendingReveal.isEmpty {
        call("addCards", [pendingReveal])
        pendingReveal = []
      }
    case "selection":
      selection = message["recordIDs"] as? [String] ?? []
      selectionWithArt = message["withArt"] as? [String] ?? []
    case "change":
      store(message, migrated: false)
      resumeFlush()
    case "openRecord":
      guard let id = message["id"] as? String else { return }
      if let record = studio.records.first(where: { $0.id == id }) {
        studio.openRecord(record)
      } else {
        studio.show("This card’s record is archived. Restore it from Library.", icon: "archivebox")
      }
    case "connect":
      guard let arrow = message["arrowID"] as? String,
        let source = studio.records.first(where: { $0.id == message["source"] as? String }),
        let target = studio.records.first(where: { $0.id == message["target"] as? String })
      else { return }
      connection = Connection(
        arrowID: arrow, source: source, target: target, label: message["label"] as? String ?? "")
    case "relabel":
      guard let id = message["relationID"] as? String, let label = message["label"] as? String
      else { return }
      do {
        try studio.store.updateRelation(worldID: worldID, id: id, label: label)
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
    case "exported":
      save(png: message["data"] as? String ?? "")
    default: break
    }
  }
  /// Writes the scene the canvas sent. Image data is only resent when it changes, so the last
  /// known files are carried forward.
  private func store(_ message: [String: Any], migrated: Bool) {
    // Saved against the world and board this scene was loaded from, even if the creator has
    // already navigated elsewhere.
    guard writable, let boardID, var scene = message["scene"] as? [String: Any] else { return }
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
    }
    if migrated { studio.show("This board now uses the new canvas. The original layout is kept.") }
  }
  /// Creates a draft relationship for an arrow the creator drew between two entity cards.
  func saveConnection(_ connection: Connection, label: String) {
    studio.perform {
      let relation = try studio.store.addRelation(
        worldID: worldID, source: connection.source.id, target: connection.target.id,
        label: label.trimmingCharacters(in: .whitespacesAndNewlines))
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
  func makeNSView(context: Context) -> NSView {
    let container = NSView()
    attach(to: container)
    return container
  }
  func updateNSView(_ container: NSView, context: Context) { attach(to: container) }
  private func attach(to container: NSView) {
    let web = session.webView
    guard web.superview !== container else { return }
    web.removeFromSuperview()
    web.frame = container.bounds
    web.autoresizingMask = [.width, .height]
    container.addSubview(web)
  }
}
