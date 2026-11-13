import AppKit
import SwiftUI
import SynthesisCore
import SynthesisUI

/// Standard titled window with the content extended under a transparent title bar, so the app
/// keeps native window controls, resizing, full screen and accessibility while drawing its own
/// integrated header.
final class StudioWindow: NSWindow {
  static let headerHeight: CGFloat = 56
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
  private var capturing: Bool {
    ProcessInfo.processInfo.environment["SYNTHESIS_CAPTURE_DIR"] != nil
  }
  func applicationDidFinishLaunching(_ notification: Notification) {
    do {
      let store = try WorkspaceStore(path: WorkspaceStore.defaultPath)
      studio = try Studio(store: store)
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
      window.backgroundColor = NSColor(studio.t.background)
      window.isReleasedWhenClosed = false
      window.contentView = NSHostingView(rootView: ConnectedRoot(studio: studio))
      window.center()
      if !capturing { window.setFrameAutosaveName("SynthesisMainWindow") }
      NSApp.setActivationPolicy(.regular)
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
        window.orderBack(nil)
        window.layoutTrafficLights()
        Task { await capture(directory) }
      } else {
        window.makeKeyAndOrderFront(nil)
        window.layoutTrafficLights()
        NSApp.activate(ignoringOtherApps: true)
      }
    } catch {
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
    window.backgroundColor = NSColor(studio.t.background)
  }
  func windowShouldClose(_ sender: NSWindow) -> Bool {
    studio.persistPendingComposer()
    return studio.flushEditor()
  }
  func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    studio.persistPendingComposer()
    return studio.flushEditor() ? .terminateNow : .terminateCancel
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
    item(file, "New Record…", #selector(newItem), "n")
    item(file, "New Conversation", #selector(newConversation), "n", [.command, .shift])
    file.addItem(.separator())
    item(file, "Search and Commands…", #selector(search), "k")
    file.addItem(.separator())
    item(file, "Import Markdown or Text…", #selector(importFiles), "i", [.command, .shift])
    item(file, "Export World as Markdown…", #selector(exportMarkdown))
    item(file, "Export World as JSON…", #selector(exportJSON))
    file.addItem(.separator())
    item(file, "Close Window", #selector(closeWindow), "w")
    let edit = submenu(main, "Edit")
    item(edit, "Undo", #selector(undoAction), "z")
    item(edit, "Redo", #selector(redoAction), "z", [.command, .shift])
    edit.addItem(.separator())
    for (title, selector, key) in [
      ("Cut", "cut:", "x"), ("Copy", "copy:", "c"),
      ("Paste", "paste:", "v"), ("Select All", "selectAll:", "a"),
    ] { edit.addItem(withTitle: title, action: Selector(selector), keyEquivalent: key) }
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
  @objc func settings() { studio.sheet = .settings }
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
          _ = try? self.snapshot(frameView, to: folder.appendingPathComponent("\(name).png"))
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
  private func capture(_ directory: String) async {
    do {
      let folder = URL(fileURLWithPath: directory)
      try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
      let fixture = try studio.prepareConnectedCapture()
      try await Task.sleep(for: .milliseconds(200))
      let only = ProcessInfo.processInfo.environment["SYNTHESIS_CAPTURE_STATES"]?
        .split(separator: ",").map(String.init)
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
          window.backgroundColor = NSColor(studio.t.background)
          window.layoutTrafficLights()
          try await Task.sleep(for: .milliseconds(700))
          window.layoutTrafficLights()
          guard let content = window.contentView, let frameView = content.superview else {
            continue
          }
          guard Int(content.bounds.width) == width, Int(content.bounds.height) == height else {
            throw SynthesisError.invalid("Capture viewport mismatch: \(content.bounds.size)")
          }
          let start = CFAbsoluteTimeGetCurrent()
          let pixels = try snapshot(
            frameView, to: folder.appendingPathComponent("\(state)-\(width)x\(height).png"))
          print(
            "CAPTURE \(state) \(width)x\(height), bitmap \(pixels.0)x\(pixels.1), \(Int((CFAbsoluteTimeGetCurrent() - start) * 1000))ms"
          )
          if let sheet = window.attachedSheet, let sheetView = sheet.contentView {
            _ = try snapshot(
              sheetView, to: folder.appendingPathComponent("\(state)-panel-\(width)x\(height).png"))
            print("CAPTURE \(state) panel")
          } else if state.hasPrefix("sheet-") {
            print("CAPTURE \(state) panel missing")
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
  let app = NSApplication.shared
  let delegate = ApplicationDelegate()
  app.delegate = delegate
  withExtendedLifetime(delegate) { app.run() }
}
