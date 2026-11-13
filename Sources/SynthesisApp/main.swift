import AppKit
import SwiftUI
import SynthesisCore
import SynthesisUI

final class StudioWindow: NSWindow {
  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { true }
  override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
    if ProcessInfo.processInfo.environment["SYNTHESIS_CAPTURE_DIR"] != nil { return frameRect }
    return super.constrainFrameRect(frameRect, to: screen)
  }
}
@MainActor final class ApplicationDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
  var window: NSWindow!
  var studio: Studio!
  func applicationDidFinishLaunching(_ notification: Notification) {
    do {
      let store = try WorkspaceStore(path: WorkspaceStore.defaultPath)
      studio = try Studio(store: store)
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
      window.center()
      window.makeKeyAndOrderFront(nil)
      NSApp.setActivationPolicy(.regular)
      NSApp.activate(ignoringOtherApps: true)
      buildMenu()
      if let directory = ProcessInfo.processInfo.environment["SYNTHESIS_CAPTURE_DIR"] {
        Task { await capture(directory) }
      }
    } catch {
      let alert = NSAlert()
      alert.messageText = "Synthesis could not open its workspace"
      alert.informativeText = error.localizedDescription
      alert.runModal()
      NSApp.terminate(nil)
    }
  }
  func windowShouldClose(_ sender: NSWindow) -> Bool { studio.flushEditor() }
  func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    studio.flushEditor() ? .terminateNow : .terminateCancel
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
    for (title, selector, key) in [
      ("Undo", "undo:", "z"), ("Redo", "redo:", "Z"), ("Cut", "cut:", "x"), ("Copy", "copy:", "c"),
      ("Paste", "paste:", "v"), ("Select All", "selectAll:", "a"),
    ] { editMenu.addItem(withTitle: title, action: Selector(selector), keyEquivalent: key) }
    edit.submenu = editMenu
    main.addItem(edit)
    NSApp.mainMenu = main
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
          guard let view = window.contentView else { continue }
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
      print("Native captures complete: \(directory)")
      NSApp.terminate(nil)
    } catch {
      print("Capture failed: \(error)")
      NSApp.terminate(nil)
    }
  }
}
MainActor.assumeIsolated {
  let app = NSApplication.shared
  let delegate = ApplicationDelegate()
  app.delegate = delegate
  withExtendedLifetime(delegate) { app.run() }
}
