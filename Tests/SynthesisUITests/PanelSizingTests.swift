import AppKit
import SynthesisCore
import Testing

@testable import SynthesisUI

@MainActor struct PanelSizingTests {
  @Test func nativeDividerTracksGesturesAndCommitsOnlyWhenFinished() throws {
    let divider = PanelDividerView(frame: NSRect(x: 0, y: 0, width: 9, height: 400))
    var updates: [(Double, Bool)] = []
    divider.changed = { updates.append(($0, $1)) }
    func mouse(_ type: NSEvent.EventType, x: Double, clicks: Int = 1) throws -> NSEvent {
      try #require(
        NSEvent.mouseEvent(
          with: type, location: NSPoint(x: x, y: 120), modifierFlags: [], timestamp: 0,
          windowNumber: 0, context: nil, eventNumber: 0, clickCount: clicks, pressure: 1))
    }
    divider.mouseDown(with: try mouse(.leftMouseDown, x: 100))
    divider.mouseDragged(with: try mouse(.leftMouseDragged, x: 60))
    #expect(divider.value == 340 && updates.count == 1 && updates[0].1 == false)
    divider.mouseDragged(with: try mouse(.leftMouseDragged, x: -200))
    #expect(divider.value == 480 && updates.last?.1 == false)
    divider.mouseUp(with: try mouse(.leftMouseUp, x: -200))
    #expect(updates.last?.0 == 480 && updates.last?.1 == true)
    let count = updates.count
    divider.finish()
    #expect(updates.count == count, "Ending an already committed gesture cannot write again")
    divider.mouseDown(with: try mouse(.leftMouseDown, x: 0, clicks: 2))
    #expect(divider.value == 300 && updates.last?.1 == true)
    divider.growsRight = true
    divider.mouseDown(with: try mouse(.leftMouseDown, x: 100))
    divider.mouseDragged(with: try mouse(.leftMouseDragged, x: 140))
    #expect(divider.value == 340)
    #expect(divider.resignFirstResponder())
    #expect(updates.last?.1 == true, "Losing focus finishes an in-flight drag")
  }

  @Test func nativeDividerKeyboardAndAccessibilityRespectBounds() throws {
    let divider = PanelDividerView()
    let left = try #require(
      NSEvent.keyEvent(
        with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0,
        context: nil, characters: "", charactersIgnoringModifiers: "", isARepeat: false,
        keyCode: 123))
    divider.keyDown(with: left)
    #expect(divider.value == 284)
    #expect(divider.accessibilityRole() == .splitter)
    #expect(divider.accessibilityValue() as? Double == 284)
    for _ in 0..<20 { #expect(divider.accessibilityPerformDecrement()) }
    #expect(divider.value == 260)
    for _ in 0..<30 { #expect(divider.accessibilityPerformIncrement()) }
    #expect(divider.value == 480)
  }

  @Test func dimensionsPersistButWindowConstraintsDoNotReplaceThePreference() throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    let path = folder.appendingPathComponent("world.sqlite").path
    let studio = try Studio(store: WorkspaceStore(path: path))
    studio.setPanelWidth(.sidebar, to: 252)
    studio.setPanelWidth(.inspector, to: 448)
    studio.setPanelWidth(.companion, to: 576)
    #expect(studio.inspectorDisplayWidth(available: 750) == 315)
    #expect(!studio.editorInspectorDocked(available: 664))
    #expect(!studio.editorInspectorDocked(available: 750))
    #expect(studio.editorInspectorDocked(available: 1080))
    #expect(studio.companionDisplayWidth(available: 950) == 430)
    #expect(studio.inspectorWidth == 448 && studio.companionWidth == 576)
    let reopened = try Studio(store: WorkspaceStore(path: path))
    #expect(
      reopened.sidebarWidth == 252 && reopened.inspectorWidth == 448
        && reopened.companionWidth == 576)
    reopened.workspaceInspector = true
    #expect(reopened.dockedInspectorWidth(windowWidth: 1440) == 448)
    #expect(reopened.dockedInspectorWidth(windowWidth: 1024) == 0)
    reopened.collapsed = true
    #expect(reopened.sidebarWidth == 252)
  }

  @Test func corruptAndOutOfRangeWidthsRecoverWithoutBlockingStartup() throws {
    let store = try WorkspaceStore(path: ":memory:")
    try store.setPreference("sidebar-width", value: "nan")
    try store.setPreference("inspector-width", value: "-800")
    try store.setPreference("companion-width", value: "99999")
    let studio = try Studio(store: store)
    #expect(studio.sidebarWidth == Double(Metric.sidebar))
    #expect(studio.inspectorWidth == 260 && studio.companionWidth == 600)
    studio.setPanelWidth(.sidebar, to: 330, persist: false)
    #expect(
      try store.preference("sidebar-width") == "nan", "Dragging does not write on every frame")
    studio.setPanelWidth(.sidebar, to: studio.sidebarWidth)
    #expect(try store.preference("sidebar-width") == "330.0")
    studio.setPanelWidth(.sidebar, to: StudioPanel.sidebar.standard)
    #expect(studio.sidebarWidth == Double(Metric.sidebar))
  }

  @Test func layoutsRestorePanelWidthsAndLegacyLayoutsRemainReadable() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let studio = try Studio(store: store)
    studio.navigate(.library)
    studio.setPanelWidth(.sidebar, to: 250)
    studio.setPanelWidth(.inspector, to: 444)
    studio.setPanelWidth(.companion, to: 560)
    let layout = try studio.saveLayout(name: "Wide research")
    for panel in StudioPanel.allCases { studio.setPanelWidth(panel, to: panel.standard) }
    #expect(studio.applyLayout(layout.id))
    #expect(
      studio.sidebarWidth == 250 && studio.inspectorWidth == 444 && studio.companionWidth == 560)
    var legacy = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(layout.arrangement)) as? [String: Any]
    )
    legacy.removeValue(forKey: "sidebarWidth")
    legacy.removeValue(forKey: "inspectorWidth")
    let restored = try JSONDecoder().decode(
      WorkspaceArrangement.self, from: JSONSerialization.data(withJSONObject: legacy))
    #expect(
      restored.sidebarWidth == nil && restored.inspectorWidth == nil
        && restored.companionWidth == 560)
  }
}
