import AppKit
import Foundation
import SynthesisCore

extension QuickCaptureController {
  public static let captureStates = [
    "quick-capture-empty", "quick-capture-writing", "quick-capture-other-world",
    "quick-capture-error", "quick-capture-saved", "light-quick-capture-writing",
  ]

  /// Captures the real utility panel against the runner's isolated store. It is never activated,
  /// registers no shortcut and never moves or edits the creator's live main window.
  public func captureFixture(_ state: String, screenSize: NSSize, directory: URL) async throws {
    guard ProcessInfo.processInfo.environment["SYNTHESIS_CAPTURE_DIR"] != nil,
      Self.captureStates.contains(state), !NSApp.isActive
    else { throw SynthesisError.invalid("Quick capture fixtures require the background runner.") }
    let worlds = try model.store.worlds()
    guard let world = worlds.first(where: \.demo) ?? worlds.first else {
      throw SynthesisError.invalid("Missing quick capture fixture universe.")
    }
    try model.store.saveQuickCaptureDraft(worldID: world.id, draft: QuickCaptureDraft())
    guard model.prepare(worldID: world.id) else {
      throw SynthesisError.invalid(model.error ?? "Could not prepare capture.")
    }
    model.dark = !state.hasPrefix("light-")
    model.oled = false
    model.opaqueMaterials = true
    if !state.hasSuffix("empty") {
      model.edit(
        """
        The city wakes at low tide.

        Its streets are drawn in salt. Every evening, the cartographers redraw a different way home.
        """)
      guard model.flush() else { throw SynthesisError.invalid(model.error ?? "Draft failed.") }
    }
    if state.hasSuffix("other-world") {
      let name = "The archipelago beyond the last remembered horizon"
      let other =
        try worlds.first(where: { $0.name == name }) ?? model.store.createWorld(name: name)
      guard model.prepare(worldID: world.id), model.selectWorld(other.id) else {
        throw SynthesisError.invalid("Could not select the alternate capture universe.")
      }
      model.edit("An island that can only be found by forgetting its name.")
      guard model.flush() else { throw SynthesisError.invalid(model.error ?? "Draft failed.") }
    }
    if state.hasSuffix("error") {
      guard !model.selectWorld("unavailable-fixture-universe"), model.error != nil else {
        throw SynthesisError.invalid("The unavailable universe did not report its real failure.")
      }
    }
    if state.hasSuffix("saved") {
      let count = try model.store.records(worldID: world.id).count
      guard let record = model.save(), record.state == "idea", record.canonical == nil,
        try model.store.records(worldID: world.id).count == count + 1,
        try model.store.quickCaptureDraft(worldID: world.id).text.isEmpty,
        model.save() == nil
      else { throw SynthesisError.invalid("Quick capture did not save exactly one draft idea.") }
      print(
        "QUICK_CAPTURE_AUDIT PASS one idea saved, scratch cleared, repeat ignored, canon untouched")
    }
    let panel = preparePanel()
    panel.appearance = NSAppearance(named: model.dark ? .darkAqua : .aqua)
    panel.backgroundColor = NSColor(model.t.background)
    panel.setContentSize(NSSize(width: screenSize.width <= 720 ? 420 : 560, height: 330))
    panel.setFrameOrigin(NSPoint(x: -20_000, y: -20_000))
    panel.orderBack(nil)
    defer { panel.orderOut(nil) }
    try await Task.sleep(for: .milliseconds(180))
    guard !panel.isKeyWindow, !panel.isMainWindow, !NSApp.isActive,
      let view = panel.contentView?.superview
    else { throw SynthesisError.invalid("Quick capture fixture unexpectedly took focus.") }
    view.layoutSubtreeIfNeeded()
    view.displayIfNeeded()
    // A reused offscreen panel can finish laying out its title bar after orderBack.
    panel.layoutWindowControls()
    guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
      throw SynthesisError.invalid("Could not allocate the quick capture image.")
    }
    view.cacheDisplay(in: view.bounds, to: bitmap)
    let headerCenter =
      view.isFlipped
      ? view.bounds.minY + QuickCapturePanel.headerHeight / 2
      : view.bounds.maxY - QuickCapturePanel.headerHeight / 2
    let buttons: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]
    for type in buttons {
      guard let button = panel.standardWindowButton(type),
        abs(view.convert(button.bounds, from: button).midY - headerCenter) <= 1
      else {
        throw SynthesisError.invalid("Quick capture title-bar controls are not centered.")
      }
    }
    guard let png = bitmap.representation(using: .png, properties: [:]) else {
      throw SynthesisError.invalid("Could not encode the quick capture image.")
    }
    try png.write(
      to: directory.appendingPathComponent(
        "\(state)-panel-\(Int(screenSize.width))x\(Int(screenSize.height)).png"))
    print(
      "QUICK_CAPTURE_AUDIT PASS \(state): native nonactivating panel, \(Int(panel.frame.width))pt, world-scoped draft"
    )
  }
}
