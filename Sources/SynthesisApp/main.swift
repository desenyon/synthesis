import AppKit
import SwiftUI
import SynthesisCore
import SynthesisUI

final class StudioWindow: NSWindow {
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
        styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered,
        defer: false)
      window.title = "Synthesis"
      window.minSize = NSSize(width: 360, height: 580)
      window.delegate = self
      window.contentView = NSHostingView(rootView: RootView(studio: studio))
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
    fileMenu.addItem(withTitle: "Save", action: #selector(save), keyEquivalent: "s").target = self
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
  @objc func save() { _ = studio.flushEditor() }
  @objc func newItem() {
    if studio.mode == .assisted { studio.newChat() } else { studio.sheet = .document }
  }
  private func capture(_ directory: String) async {
    do {
      try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
      studio.loadSample()
      let sizes: [(Int, Int)] = [(1440, 900), (1920, 1080), (1024, 768), (390, 844)]
      for (width, height) in sizes {
        for state in ["ai-home", "active-chat", "manual", "editor", "collapsed", "dark"]
          + (width == 1440 ? ["library", "graph", "timeline", "canvas", "atlas"] : [])
        {
          studio.stop()
          studio.error = nil
          studio.sheet = nil
          studio.dark = false
          studio.collapsed = false
          studio.setMode(.assisted)
          studio.newChat()
          switch state {
          case "active-chat":
            let chat = try studio.store.createConversation(
              worldID: studio.worldID, title: "The sea that remembers")
            try studio.store.appendMessage(
              worldID: studio.worldID, conversationID: chat.id, role: "user",
              body:
                "What if the glass sea remembered everyone who crossed it? Help me explore the consequences.",
              state: "complete")
            try studio.store.appendMessage(
              worldID: studio.worldID, conversationID: chat.id, role: "system",
              body: "Connect a model in Settings to continue. Your message has been saved.",
              state: "error")
            studio.openChat(chat)
          case "manual": studio.setMode(.manual)
          case "editor":
            studio.setMode(.manual)
            if let record = studio.records.first(where: { $0.title == "The Glass Sea" }) {
              studio.openRecord(record)
            }
          case "library": studio.navigate(.library)
          case "graph": studio.navigate(.knowledge)
          case "timeline": studio.navigate(.timeline)
          case "canvas": studio.navigate(.canvas)
          case "atlas": studio.navigate(.atlas)
          case "collapsed": studio.collapsed = true
          case "dark": studio.dark = true
          default: break
          }
          window.setContentSize(NSSize(width: width, height: height))
          try await Task.sleep(for: .milliseconds(700))
          guard let view = window.contentView else { continue }
          view.layoutSubtreeIfNeeded()
          view.displayIfNeeded()
          guard Int(view.bounds.width) == width, Int(view.bounds.height) == height else {
            throw SynthesisError.invalid("Capture viewport mismatch: \(view.bounds.size)")
          }
          guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { continue }
          view.cacheDisplay(in: view.bounds, to: bitmap)
          if let png = bitmap.representation(using: .png, properties: [:]) {
            try png.write(
              to: URL(fileURLWithPath: directory).appendingPathComponent(
                "\(state)-\(width)x\(height).png"))
          }
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
