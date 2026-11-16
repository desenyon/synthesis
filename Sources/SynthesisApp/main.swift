import AppKit
import SwiftUI
import SynthesisCore
import SynthesisUI
import WebKit

/// Prevent framework focus requests from activating a background verification process.
final class SynthesisApplication: NSApplication {
  private var backgroundCapture: Bool {
    ProcessInfo.processInfo.environment["SYNTHESIS_CAPTURE_DIR"] != nil
      && ProcessInfo.processInfo.environment["SYNTHESIS_SELFTEST_DIR"] == nil
  }
  override func activate() {
    if !backgroundCapture { super.activate() }
  }
  override func activate(ignoringOtherApps flag: Bool) {
    if !backgroundCapture { super.activate(ignoringOtherApps: flag) }
  }
}

private struct CaptureTransport: ModelTransport {
  func generate(_ request: ModelRequest, onDelta: @escaping @Sendable (String) async -> Void)
    async throws -> String
  {
    throw SynthesisError.invalid("Model requests are blocked during verification.")
  }
}

/// Standard titled window with the content extended under a transparent title bar, so the app
/// keeps native window controls, resizing, full screen and accessibility while drawing its own
/// integrated header.
final class StudioWindow: NSWindow {
  static let headerHeight: CGFloat = 56
  private var backgroundCapture: Bool {
    ProcessInfo.processInfo.environment["SYNTHESIS_CAPTURE_DIR"] != nil
      && ProcessInfo.processInfo.environment["SYNTHESIS_SELFTEST_DIR"] == nil
  }
  override var canBecomeKey: Bool { !backgroundCapture && super.canBecomeKey }
  override var canBecomeMain: Bool { !backgroundCapture && super.canBecomeMain }
  override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
    if ProcessInfo.processInfo.environment["SYNTHESIS_CAPTURE_DIR"] != nil { return frameRect }
    return super.constrainFrameRect(frameRect, to: screen)
  }
  /// Centres the close, minimise and zoom buttons in the 56-point header.
  func layoutTrafficLights() {
    guard !styleMask.contains(.fullScreen),
      let close = standardWindowButton(.closeButton),
      let minimise = standardWindowButton(.miniaturizeButton),
      let zoom = standardWindowButton(.zoomButton),
      let container = close.superview?.superview
    else { return }
    var bar = container.frame
    bar.size.height = Self.headerHeight
    bar.origin.y = frame.height - Self.headerHeight
    if container.frame != bar { container.frame = bar }
    for (index, button) in [close, minimise, zoom].enumerated() {
      let origin = NSPoint(
        x: 20 + CGFloat(index) * 20, y: (Self.headerHeight - button.frame.height) / 2)
      if button.frame.origin != origin { button.setFrameOrigin(origin) }
    }
  }
  /// AppKit restores the default button positions after appearance and key-state changes.
  override func update() {
    super.update()
    layoutTrafficLights()
  }
}
@MainActor final class ApplicationDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
  var window: StudioWindow!
  var studio: Studio!
  private var previousApplication: NSRunningApplication?
  private var closeApproved = false
  private var closePending = false
  private var capturing: Bool {
    ProcessInfo.processInfo.environment["SYNTHESIS_CAPTURE_DIR"] != nil
  }
  func applicationDidFinishLaunching(_ notification: Notification) {
    do {
      // Set before creating any hosting view: a first-screen sheet can otherwise request focus.
      NSApp.setActivationPolicy(
        capturing && ProcessInfo.processInfo.environment["SYNTHESIS_SELFTEST_DIR"] == nil
          ? .accessory : .regular)
      if capturing {
        guard NSApp is SynthesisApplication else {
          throw SynthesisError.invalid("Background activation guard was not installed.")
        }
        guard let path = ProcessInfo.processInfo.environment["SYNTHESIS_DATABASE_PATH"],
          !FileManager.default.fileExists(atPath: path)
        else {
          throw SynthesisError.invalid("Verification requires a fresh isolated database path.")
        }
      }
      let store = try WorkspaceStore(path: WorkspaceStore.defaultPath)
      studio = try Studio(store: store, transport: capturing ? CaptureTransport() : nil)
      window = StudioWindow(
        contentRect: NSRect(x: 0, y: 0, width: 1440, height: 900),
        styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
        backing: .buffered, defer: false)
      window.title = "Synthesis"
      window.titleVisibility = .hidden
      window.titlebarAppearsTransparent = true
      window.isMovableByWindowBackground = false
      window.minSize = NSSize(width: 520, height: 520)
      window.delegate = self
      window.appearance = NSAppearance(named: studio.dark ? .darkAqua : .aqua)
      window.backgroundColor = NSColor(studio.t.background)
      window.isReleasedWhenClosed = false
      window.contentView = NSHostingView(rootView: ConnectedRoot(studio: studio))
      window.center()
      if !capturing { window.setFrameAutosaveName("SynthesisMainWindow") }
      buildMenu()
      if let directory = ProcessInfo.processInfo.environment["SYNTHESIS_SELFTEST_DIR"],
        capturing
      {
        // Gestures only respond in the key window of the active app, so this runner comes
        // forward briefly and hands focus back to whatever was in front when it finishes.
        previousApplication = NSWorkspace.shared.frontmostApplication
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window.layoutTrafficLights()
        Task { await selfTest(directory) }
      } else if let directory = ProcessInfo.processInfo.environment["SYNTHESIS_CAPTURE_DIR"] {
        // The capture runner stays in the background and never takes focus from other work.
        window.ignoresMouseEvents = true
        window.level = NSWindow.Level(rawValue: NSWindow.Level.normal.rawValue - 1)
        window.orderBack(nil)
        window.layoutTrafficLights()
        Task { await capture(directory) }
      } else {
        window.makeKeyAndOrderFront(nil)
        window.layoutTrafficLights()
        NSApp.activate(ignoringOtherApps: true)
      }
    } catch {
      if capturing {
        fputs("Verification startup failed: \(error)\n", stderr)
        exit(1)
      }
      let alert = NSAlert()
      alert.messageText = "Synthesis could not open its workspace"
      alert.informativeText = error.localizedDescription
      alert.runModal()
      NSApp.terminate(nil)
    }
  }
  func windowDidResize(_ notification: Notification) { window.layoutTrafficLights() }
  func windowDidExitFullScreen(_ notification: Notification) { window.layoutTrafficLights() }
  func windowDidBecomeKey(_ notification: Notification) {
    window.layoutTrafficLights()
    window.appearance = NSAppearance(named: studio.dark ? .darkAqua : .aqua)
    window.backgroundColor = NSColor(studio.t.background)
  }
  func windowShouldClose(_ sender: NSWindow) -> Bool {
    studio.persistPendingComposer()
    guard studio.flushEditor() else { return false }
    if closeApproved || studio.canvasWebView == nil { return true }
    guard !closePending else { return false }
    closePending = true
    Task {
      let saved = await studio.flushCanvas()
      closePending = false
      if saved && studio.flushEditor() {
        closeApproved = true
        window.performClose(nil)
      } else if !saved {
        studio.error = "The canvas has not confirmed its save. Keep this window open and retry."
      }
    }
    return false
  }
  func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    studio.persistPendingComposer()
    guard studio.flushEditor() else { return .terminateCancel }
    guard studio.canvasWebView != nil else { return .terminateNow }
    // The canvas hands over its latest edits asynchronously; wait for that before quitting.
    Task {
      let saved = await studio.flushCanvas()
      if !saved {
        studio.error = "The canvas has not confirmed its save. Keep this window open and retry."
      }
      NSApp.reply(toApplicationShouldTerminate: saved && studio.flushEditor())
    }
    return .terminateLater
  }
  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

  // MARK: Menu

  private func item(
    _ menu: NSMenu, _ title: String, _ action: Selector, _ key: String = "",
    _ modifiers: NSEvent.ModifierFlags = .command, tag: Int = 0
  ) {
    let entry = menu.addItem(withTitle: title, action: action, keyEquivalent: key)
    entry.keyEquivalentModifierMask = modifiers
    entry.target = self
    entry.tag = tag
  }
  private func submenu(_ main: NSMenu, _ title: String) -> NSMenu {
    let holder = NSMenuItem()
    holder.title = title
    let menu = NSMenu(title: title)
    holder.submenu = menu
    main.addItem(holder)
    return menu
  }
  private func buildMenu() {
    let main = NSMenu()
    let app = submenu(main, "Synthesis")
    app.addItem(
      withTitle: "About Synthesis",
      action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
    app.addItem(.separator())
    item(app, "Settings…", #selector(settings), ",")
    app.addItem(.separator())
    app.addItem(
      withTitle: "Hide Synthesis", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
    app.addItem(
      withTitle: "Quit Synthesis", action: #selector(NSApplication.terminate(_:)),
      keyEquivalent: "q")
    let file = submenu(main, "File")
    item(file, "All Worlds", #selector(allWorlds))
    item(file, "New World…", #selector(newWorld))
    item(file, "Open World File…", #selector(openWorldFile), "o")
    item(file, "Save World File…", #selector(saveWorldFile), "s", [.command, .shift])
    file.addItem(.separator())
    item(file, "New Record…", #selector(newItem), "n")
    item(file, "New Conversation", #selector(newConversation), "n", [.command, .shift])
    file.addItem(.separator())
    item(file, "Search and Commands…", #selector(search), "k")
    file.addItem(.separator())
    item(file, "Import Markdown or Text…", #selector(importFiles), "i", [.command, .shift])
    item(file, "Export World as Markdown…", #selector(exportMarkdown))
    item(file, "Export World as JSON…", #selector(exportJSON))
    item(file, "Export World Images…", #selector(exportImages))
    file.addItem(.separator())
    item(file, "Close Window", #selector(closeWindow), "w")
    let edit = submenu(main, "Edit")
    item(edit, "Undo", #selector(undoAction), "z")
    item(edit, "Redo", #selector(redoAction), "z", [.command, .shift])
    edit.addItem(.separator())
    for (title, selector, key) in [
      ("Cut", "cut:", "x"), ("Copy", "copy:", "c"), ("Paste", "paste:", "v"),
    ] { edit.addItem(withTitle: title, action: Selector(selector), keyEquivalent: key) }
    item(edit, "Select All", #selector(selectAllAction), "a")
    let view = submenu(main, "View")
    for (index, destination) in Destination.allCases.enumerated() {
      item(view, destination.rawValue, #selector(go(_:)), "\(index + 1)", tag: index)
    }
    view.addItem(.separator())
    item(view, "Toggle Navigation", #selector(toggleSidebar), "\\")
    item(view, "Toggle AI Assisted / Manual", #selector(toggleMode), "m", [.command, .shift])
    item(view, "Toggle Appearance", #selector(toggleTheme), "l", [.command, .shift])
    view.addItem(.separator())
    view.addItem(
      withTitle: "Enter Full Screen", action: #selector(NSWindow.toggleFullScreen(_:)),
      keyEquivalent: "f"
    ).keyEquivalentModifierMask = [.command, .control]
    let windowMenu = submenu(main, "Window")
    windowMenu.addItem(
      withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
    windowMenu.addItem(
      withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
    NSApp.mainMenu = main
    NSApp.windowsMenu = windowMenu
  }
  @objc func undoAction() {
    if window.firstResponder is NSTextView {
      NSApp.sendAction(Selector(("undo:")), to: nil, from: nil)
    } else {
      studio.canvasUndo?(true)
    }
  }
  @objc func redoAction() {
    if window.firstResponder is NSTextView {
      NSApp.sendAction(Selector(("redo:")), to: nil, from: nil)
    } else {
      studio.canvasUndo?(false)
    }
  }
  /// True when keyboard focus is inside the canvas engine's web view.
  private var canvasHasFocus: Bool {
    guard let web = studio.canvasWebView, let responder = window.firstResponder as? NSView
    else { return false }
    return responder === web || responder.isDescendant(of: web)
  }
  @objc func selectAllAction() {
    if canvasHasFocus {
      studio.canvasCommand("selectAll")
    } else {
      NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
    }
  }
  @objc func settings() { studio.navigate(.settings) }
  @objc func allWorlds() { studio.navigate(.worlds) }
  @objc func newWorld() { studio.sheet = .world }
  @objc func openWorldFile() { studio.openPortableWorld() }
  @objc func saveWorldFile() { studio.savePortableWorld() }
  @objc func exportImages() { studio.exportWorldImages() }
  @objc func search() { studio.palette.toggle() }
  @objc func closeWindow() { window.performClose(nil) }
  @objc func newItem() {
    studio.newRecordKind = "lore"
    studio.sheet = .document
  }
  @objc func newConversation() { studio.newChat() }
  @objc func importFiles() { studio.importDocuments() }
  @objc func exportMarkdown() { studio.exportMarkdown() }
  @objc func exportJSON() { studio.exportWorld() }
  @objc func go(_ sender: NSMenuItem) {
    let all = Destination.allCases
    if all.indices.contains(sender.tag) { studio.navigate(all[sender.tag]) }
  }
  @objc func toggleSidebar() { studio.toggleSidebar() }
  @objc func toggleMode() { studio.setMode(studio.mode == .assisted ? .manual : .assisted) }
  @objc func toggleTheme() {
    studio.toggleTheme()
    window.appearance = NSAppearance(named: studio.dark ? .darkAqua : .aqua)
    window.backgroundColor = NSColor(studio.t.background)
  }

  // MARK: Capture runner

  /// Renders the window frame, including the native window controls, into a PNG.
  private func snapshot(_ view: NSView, to url: URL) throws -> (Int, Int) {
    view.layoutSubtreeIfNeeded()
    view.displayIfNeeded()
    guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
      throw SynthesisError.invalid("Could not allocate a capture bitmap.")
    }
    view.cacheDisplay(in: view.bounds, to: bitmap)
    guard let png = bitmap.representation(using: .png, properties: [:]) else {
      throw SynthesisError.invalid("Could not encode a capture.")
    }
    try png.write(to: url)
    return (bitmap.pixelsWide, bitmap.pixelsHigh)
  }
  /// Posts pointer and key events to this window only and reports what the app did with them.
  private func selfTest(_ directory: String) async {
    let folder = URL(fileURLWithPath: directory)
    do {
      try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
      let fixture = try studio.prepareConnectedCapture()
      window.setContentSize(NSSize(width: 1440, height: 900))
      studio.configureConnectedCapture(
        "canvas", board: fixture.board, conversation: fixture.conversation)
      try await Task.sleep(for: .milliseconds(1500))
      let lines = await studio.runInteractionSelfTest(window: window) { name in
        if let frameView = self.window.contentView?.superview {
          _ = try? await self.shot(
            frameView, to: folder.appendingPathComponent("\(name).png"), web: true)
        }
      }
      for line in lines { print("SELFTEST \(line)") }
      if lines.contains(where: { $0.hasPrefix("FAIL") }) {
        print("Interaction self-test FAILED")
      } else if lines.contains(where: { $0.hasPrefix("SKIP") }) {
        print("Interaction self-test incomplete: the window lost focus during the run")
      } else {
        print("Interaction self-test passed: \(lines.count) checks")
      }
    } catch {
      print("Interaction self-test FAILED: \(error)")
    }
    window.orderOut(nil)
    previousApplication?.activate()
    fflush(stdout)
    exit(0)
  }
  /// Renders the window frame and, when the canvas is showing, its web content. View caching
  /// cannot see web content, so the web view's own snapshot is laid in wherever the cached
  /// image shows the plain backdrop behind it; native overlays drawn above the canvas stay.
  private func shot(_ frameView: NSView, to url: URL, web: Bool) async throws -> (Int, Int) {
    frameView.layoutSubtreeIfNeeded()
    frameView.displayIfNeeded()
    guard let bitmap = frameView.bitmapImageRepForCachingDisplay(in: frameView.bounds) else {
      throw SynthesisError.invalid("Could not allocate a capture bitmap.")
    }
    frameView.cacheDisplay(in: frameView.bounds, to: bitmap)
    if web, let webView = studio.canvasWebView as? WKWebView, webView.window === window,
      let image = try? await webView.takeSnapshot(configuration: nil)
    {
      lay(image, from: webView, into: bitmap, of: frameView)
    }
    guard let png = bitmap.representation(using: .png, properties: [:]) else {
      throw SynthesisError.invalid("Could not encode a capture.")
    }
    try png.write(to: url)
    return (bitmap.pixelsWide, bitmap.pixelsHigh)
  }
  private func lay(
    _ image: NSImage, from webView: NSView, into bitmap: NSBitmapImageRep, of frameView: NSView
  ) {
    let scale = CGFloat(bitmap.pixelsWide) / frameView.bounds.width
    let rect = webView.convert(webView.bounds, to: frameView)
    let width = Int((rect.width * scale).rounded())
    let height = Int((rect.height * scale).rounded())
    let left = Int((rect.minX * scale).rounded())
    let top = Int(((frameView.bounds.height - rect.maxY) * scale).rounded())
    guard width > 8, height > 8, bitmap.samplesPerPixel == 4, let base = bitmap.bitmapData,
      let layer = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: bitmap.colorSpaceName, bitmapFormat: bitmap.bitmapFormat, bytesPerRow: 0,
        bitsPerPixel: 32), let context = NSGraphicsContext(bitmapImageRep: layer)
    else { return }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    image.draw(in: NSRect(x: 0, y: 0, width: width, height: height))
    NSGraphicsContext.restoreGraphicsState()
    guard let source = layer.bitmapData else { return }
    // The backdrop colour is read from a corner of the canvas area, which no overlay covers.
    let key = base + (top + 3) * bitmap.bytesPerRow + (left + 3) * 4
    let backdrop = (key[0], key[1], key[2])
    for y in 0..<height where top + y < bitmap.pixelsHigh {
      let row = base + (top + y) * bitmap.bytesPerRow
      let from = source + y * layer.bytesPerRow
      for x in 0..<width where left + x < bitmap.pixelsWide {
        let pixel = row + (left + x) * 4
        if abs(Int(pixel[0]) - Int(backdrop.0)) < 3, abs(Int(pixel[1]) - Int(backdrop.1)) < 3,
          abs(Int(pixel[2]) - Int(backdrop.2)) < 3
        {
          let web = from + x * 4
          pixel[0] = web[0]
          pixel[1] = web[1]
          pixel[2] = web[2]
          pixel[3] = 255
        }
      }
    }
  }
  private func capture(_ directory: String) async {
    do {
      let folder = URL(fileURLWithPath: directory)
      try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
      let fixture = try studio.prepareConnectedCapture()
      try await Task.sleep(for: .milliseconds(200))
      let only = ProcessInfo.processInfo.environment["SYNTHESIS_CAPTURE_STATES"]?
        .split(separator: ",").map(String.init)
      let unknown = (only ?? []).filter { !Studio.captureStates.contains($0) }
      guard unknown.isEmpty else {
        throw SynthesisError.invalid("Unknown capture states: \(unknown.joined(separator: ", "))")
      }
      let sizes: [(Int, Int)] =
        ProcessInfo.processInfo.environment["SYNTHESIS_CAPTURE_SIZES"]?.split(separator: ",")
        .compactMap { value -> (Int, Int)? in
          let parts = value.split(separator: "x").compactMap { Int($0) }
          return parts.count == 2 ? (parts[0], parts[1]) : nil
        } ?? [(1440, 900), (1920, 1080), (1024, 768), (720, 800)]
      for (width, height) in sizes {
        for state in Studio.captureStates where only?.contains(state) ?? true {
          window.setContentSize(NSSize(width: width, height: height))
          studio.configureConnectedCapture(
            state, board: fixture.board, conversation: fixture.conversation)
          window.appearance = NSAppearance(named: studio.dark ? .darkAqua : .aqua)
          window.backgroundColor = NSColor(studio.t.background)
          window.layoutTrafficLights()
          try await Task.sleep(for: .milliseconds(700))
          let canvas = studio.destination == .canvas && studio.selectedRecord == nil
          if canvas {
            // The engine loads asynchronously; wait for the board, then frame it.
            for _ in 0..<40 where !studio.canvasLoaded {
              try await Task.sleep(for: .milliseconds(250))
            }
            try await Task.sleep(for: .milliseconds(500))
            studio.canvasFit?()
            try await Task.sleep(for: .milliseconds(900))
          }
          if state == "canvas", width == 1440,
            ProcessInfo.processInfo.environment["SYNTHESIS_CANVAS_AUDIT"] == "1"
          {
            let checks = try await studio.auditCanvas()
            for line in checks { print("CANVAS_AUDIT \(line)") }
            if checks.contains(where: { $0.hasPrefix("FAIL") }) {
              throw SynthesisError.invalid("Canvas engine audit failed; see checks above.")
            }
          }
          try await Task.sleep(for: .milliseconds(200))
          studio.toast = nil
          window.layoutTrafficLights()
          guard !NSApp.isActive, !window.isKeyWindow else {
            throw SynthesisError.invalid(
              "Background verification unexpectedly took focus (active=\(NSApp.isActive), key=\(window.isKeyWindow))."
            )
          }
          guard let content = window.contentView, let frameView = content.superview else {
            continue
          }
          guard Int(content.bounds.width) == width, Int(content.bounds.height) == height else {
            throw SynthesisError.invalid("Capture viewport mismatch: \(content.bounds.size)")
          }
          let start = CFAbsoluteTimeGetCurrent()
          let pixels = try await shot(
            frameView, to: folder.appendingPathComponent("\(state)-\(width)x\(height).png"),
            web: canvas)
          print(
            "CAPTURE \(state) \(width)x\(height), bitmap \(pixels.0)x\(pixels.1), \(Int((CFAbsoluteTimeGetCurrent() - start) * 1000))ms"
          )
          if let sheet = window.attachedSheet, let sheetView = sheet.contentView {
            _ = try snapshot(
              sheetView, to: folder.appendingPathComponent("\(state)-panel-\(width)x\(height).png"))
            print("CAPTURE \(state) panel")
          } else if state.hasPrefix("sheet-") {
            print("CAPTURE \(state) content inline; native modal presentation not exercised")
          }
        }
      }
      print("Native captures complete: \(directory)")
    } catch {
      print("Capture failed: \(error)")
    }
    // An attached sheet would defer a normal terminate; the runner owns an isolated database.
    fflush(stdout)
    exit(0)
  }
}
MainActor.assumeIsolated {
  let app = SynthesisApplication.shared
  if ProcessInfo.processInfo.environment["SYNTHESIS_CAPTURE_DIR"] != nil,
    ProcessInfo.processInfo.environment["SYNTHESIS_SELFTEST_DIR"] == nil
  {
    app.setActivationPolicy(.accessory)
  }
  let delegate = ApplicationDelegate()
  app.delegate = delegate
  withExtendedLifetime(delegate) { app.run() }
}
