import AppKit
import Foundation
import SynthesisCore

extension Studio {
  func configureFocusCapture(_ state: String, board: String, conversation: String) {
    focusMode = false
    let base: String
    if state.hasSuffix("atlas") {
      base = "atlas"
    } else if state.hasSuffix("graph") {
      base = "graph-selected"
    } else if state.hasSuffix("canvas") {
      base = "canvas"
    } else if state.hasSuffix("conversation") {
      base = "conversation-home"
    } else if state.hasSuffix("split") {
      base = "split-editor"
    } else if state.hasSuffix("blank") {
      base = "profile-empty"
    } else {
      base = "editor"
    }
    configureConnectedCapture(base, board: board, conversation: conversation)
    if state.hasPrefix("focus-from-properties"), let record = selectedRecord {
      recordTabs[record.id] = .properties
    }
    dark = !state.hasPrefix("light-")
    if state.hasPrefix("manual-") { setMode(.manual) }
    if state.hasSuffix("collapsed") { collapsed = true }
    inspector = true
    workspaceInspector = selectedRecord == nil && destination != .canvas
    captureHint = state
  }

  public func auditFocusCapture(_ state: String, toggle: () throws -> Void) async throws -> [String]
  {
    guard ProcessInfo.processInfo.environment["SYNTHESIS_CAPTURE_DIR"] != nil else {
      throw SynthesisError.invalid("Focus capture requires isolated data.")
    }
    let location = navigationLocation
    let originalMode = mode
    let originalRecords = try store.records(worldID: worldID)
    let layout = (collapsed, inspector, workspaceInspector, companionExpanded, sidebarWidth)
    let handle = selectedRecord.map { editorHandle(for: $0) }
    let textView = handle?.view
    let startsFromProperties = state.hasPrefix("focus-from-properties")
    if startsFromProperties {
      guard location.context?.recordTab == .properties, textView?.window == nil else {
        throw SynthesisError.invalid("The focus fixture must begin on Properties.")
      }
    }
    try toggle()
    try await Task.sleep(for: .milliseconds(450))
    guard focusMode, visibleSidebarWidth(windowWidth: 1440) == 0,
      dockedInspectorWidth(windowWidth: 1920) == 0,
      textView == nil || handle?.view === textView
    else {
      throw SynthesisError.invalid("Focus did not hide panels or replaced the native editor.")
    }
    if startsFromProperties && handle?.view?.window == nil {
      throw SynthesisError.invalid("Focus from Properties did not reveal the document editor.")
    }
    if state.hasSuffix("restored") || state.hasSuffix("collapsed") {
      try toggle()
      try await Task.sleep(for: .milliseconds(450))
      guard !focusMode else {
        throw SynthesisError.invalid("Exit focus did not restore the workspace.")
      }
    }
    guard location == navigationLocation, originalMode == mode,
      originalRecords == (try store.records(worldID: worldID)),
      collapsed == layout.0, inspector == layout.1, workspaceInspector == layout.2,
      companionExpanded == layout.3, sidebarWidth == layout.4, !busy, error == nil
    else { throw SynthesisError.invalid("Focus changed content, mode or saved panel choices.") }
    return [
      "PASS \(state): native focus shortcut hides/restores presentation without replacing the editor",
      "PASS \(state): addresses, panel choices, original lore and assistance mode preserved",
    ]
  }
}
