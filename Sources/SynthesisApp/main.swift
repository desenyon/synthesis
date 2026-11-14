import AppKit
import SwiftUI
import SynthesisCore
import SynthesisUI

private struct CaptureTransport: ModelTransport {
  func generate(_ request: ModelRequest, onDelta: @escaping @Sendable (String) async -> Void)
    async throws -> String
  {
    throw SynthesisError.invalid("Model requests are disabled during background verification.")
  }
}

final class StudioWindow: NSWindow {
  override var canBecomeKey: Bool {
    ProcessInfo.processInfo.environment["SYNTHESIS_CAPTURE_DIR"] == nil
  }
  override var canBecomeMain: Bool { canBecomeKey }
  override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
    if ProcessInfo.processInfo.environment["SYNTHESIS_CAPTURE_DIR"] != nil { return frameRect }
    return super.constrainFrameRect(frameRect, to: screen)
  }
}
@MainActor final class ApplicationDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
  var window: NSWindow!
  var studio: Studio!
  private var captureDirectory: String? {
    ProcessInfo.processInfo.environment["SYNTHESIS_CAPTURE_DIR"]
  }
  private var activatedDuringCapture = false
  private var activationObserver: NSObjectProtocol?
  func applicationDidFinishLaunching(_ notification: Notification) {
    do {
      if captureDirectory != nil {
        guard let path = ProcessInfo.processInfo.environment["SYNTHESIS_DATABASE_PATH"],
          !FileManager.default.fileExists(atPath: path)
        else {
          throw SynthesisError.invalid(
            "Background capture requires a fresh isolated database path.")
        }
        NSApp.setActivationPolicy(.prohibited)
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
          forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] notification in
          if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
            as? NSRunningApplication,
            app.processIdentifier == ProcessInfo.processInfo.processIdentifier
          {
            MainActor.assumeIsolated { self?.activatedDuringCapture = true }
          }
        }
      }
      let store = try WorkspaceStore(path: WorkspaceStore.defaultPath)
      studio = try Studio(
        store: store, transport: captureDirectory == nil ? nil : CaptureTransport())
      window = StudioWindow(
        contentRect: NSRect(x: 0, y: 0, width: 1440, height: 900),
        styleMask: [.borderless, .closable, .miniaturizable, .resizable], backing: .buffered,
        defer: false)
      window.title = "Synthesis"
      window.minSize = NSSize(width: 360, height: 580)
      window.delegate = self
      window.isOpaque = false
      window.backgroundColor = .clear
      window.hasShadow = true
      window.contentView = NSHostingView(rootView: ConnectedRoot(studio: studio))
      if let directory = captureDirectory {
        // A never-ordered NSWindow supplies native layout/backing scale without touching focus.
        Task { await capture(directory) }
      } else {
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        buildMenu()
      }
    } catch {
      if captureDirectory != nil {
        fputs("Background capture startup failed: \(error)\n", stderr)
        exit(EXIT_FAILURE)
      }
      let alert = NSAlert()
      alert.messageText = "Synthesis could not open its workspace"
      alert.informativeText = error.localizedDescription
      alert.runModal()
      NSApp.terminate(nil)
    }
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
  private func buildMenu() {
    let main = NSMenu()
    let appItem = NSMenuItem()
    let appMenu = NSMenu()
    appMenu.addItem(
      withTitle: "About Synthesis",
      action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
    appMenu.addItem(.separator())
    appMenu.addItem(withTitle: "Settings…", action: #selector(settings), keyEquivalent: ",")
      .target = self
    appMenu.addItem(.separator())
    appMenu.addItem(
      withTitle: "Quit Synthesis", action: #selector(NSApplication.terminate(_:)),
      keyEquivalent: "q")
    appItem.submenu = appMenu
    main.addItem(appItem)
    let file = NSMenuItem()
    file.title = "File"
    let fileMenu = NSMenu(title: "File")
    fileMenu.addItem(withTitle: "New", action: #selector(newItem), keyEquivalent: "n").target = self
    fileMenu.addItem(withTitle: "Search", action: #selector(search), keyEquivalent: "k").target =
      self
    fileMenu.addItem(withTitle: "Close Window", action: #selector(closeWindow), keyEquivalent: "w")
      .target = self
    file.submenu = fileMenu
    main.addItem(file)
    let edit = NSMenuItem()
    edit.title = "Edit"
    let editMenu = NSMenu(title: "Edit")
    editMenu.addItem(withTitle: "Undo", action: #selector(undoAction), keyEquivalent: "z").target =
      self
    editMenu.addItem(withTitle: "Redo", action: #selector(redoAction), keyEquivalent: "Z").target =
      self
    for (title, selector, key) in [
      ("Cut", "cut:", "x"), ("Copy", "copy:", "c"),
      ("Paste", "paste:", "v"), ("Select All", "selectAll:", "a"),
    ] { editMenu.addItem(withTitle: title, action: Selector(selector), keyEquivalent: key) }
    edit.submenu = editMenu
    main.addItem(edit)
    NSApp.mainMenu = main
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
  @objc func search() { studio.sheet = .search }
  @objc func closeWindow() { window.close() }
  @objc func newItem() { studio.sheet = .document }
  private func capture(_ directory: String) async {
    do {
      try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
      let fixture = try studio.prepareConnectedCapture()
      try await Task.sleep(for: .milliseconds(150))
      let sizes: [(Int, Int)] = [(1440, 900), (1920, 1080), (1024, 768)]
      for (width, height) in sizes {
        for state in [
          "conversation-home", "conversation", "canvas", "companion", "manual", "collapsed",
          "light", "graph", "library",
        ] {
          studio.configureConnectedCapture(
            state, board: fixture.board, conversation: fixture.conversation)
          window.setContentSize(NSSize(width: width, height: height))
          try await Task.sleep(for: .milliseconds(450))
          guard !window.isVisible, !window.isKeyWindow, !NSApp.isActive, !activatedDuringCapture
          else {
            throw SynthesisError.invalid(
              "Background capture unexpectedly activated or displayed a window.")
          }
          guard let view = window.contentView else {
            throw SynthesisError.invalid("Missing capture view")
          }
          view.layoutSubtreeIfNeeded()
          view.displayIfNeeded()
          guard Int(view.bounds.width) == width, Int(view.bounds.height) == height else {
            throw SynthesisError.invalid("Capture viewport mismatch: \(view.bounds.size)")
          }
          guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { continue }
          let start = CFAbsoluteTimeGetCurrent()
          view.cacheDisplay(in: view.bounds, to: bitmap)
          if let png = bitmap.representation(using: .png, properties: [:]) {
            try png.write(
              to: URL(fileURLWithPath: directory).appendingPathComponent(
                "\(state)-\(width)x\(height).png"))
          }
          print(
            "CAPTURE \(state) \(width)x\(height), bitmap \(bitmap.pixelsWide)x\(bitmap.pixelsHigh), capture+PNG \(Int((CFAbsoluteTimeGetCurrent()-start)*1000))ms"
          )
        }
      }
      print("BACKGROUND VERIFIED: no visible window or activation")
      print("Native captures complete: \(directory)")
      NSApp.terminate(nil)
    } catch {
      fputs("Capture failed: \(error)\n", stderr)
      exit(EXIT_FAILURE)
    }
  }
}
MainActor.assumeIsolated {
  let app = NSApplication.shared
  if ProcessInfo.processInfo.environment["SYNTHESIS_CAPTURE_DIR"] != nil {
    app.setActivationPolicy(.prohibited)
  }
  let delegate = ApplicationDelegate()
  app.delegate = delegate
  withExtendedLifetime(delegate) { app.run() }
}
