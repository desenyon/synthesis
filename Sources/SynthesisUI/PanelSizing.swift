import AppKit
import SwiftUI

/// Device-local presentation bounds; narrow windows constrain display, not the saved preference.
enum StudioPanel: String, CaseIterable {
  case sidebar, inspector, companion, split
  var key: String { "\(rawValue)-width" }
  var title: String {
    switch self {
    case .sidebar: "Navigation"
    case .inspector: "Inspector"
    case .companion: "Conversation"
    case .split: "Second document"
    }
  }
  var limits: ClosedRange<Double> {
    switch self {
    case .sidebar: 240...360
    case .inspector: 260...480
    case .companion: 320...600
    case .split: 380...720
    }
  }
  var standard: Double {
    switch self {
    case .sidebar: Double(Metric.sidebar)
    case .inspector: 300
    case .companion: 400
    case .split: 460
    }
  }
  func bounded(_ value: Double) -> Double {
    value.isFinite ? min(limits.upperBound, max(limits.lowerBound, value)) : standard
  }
}

extension Studio {
  func panelWidth(_ panel: StudioPanel) -> Double {
    switch panel {
    case .sidebar: sidebarWidth
    case .inspector: inspectorWidth
    case .companion: companionWidth
    case .split: splitWidth
    }
  }
  func setPanelWidth(_ panel: StudioPanel, to value: Double, persist: Bool = true) {
    let next = panel.bounded(value)
    switch panel {
    case .sidebar: sidebarWidth = next
    case .inspector: inspectorWidth = next
    case .companion: companionWidth = next
    case .split: splitWidth = next
    }
    if persist { perform { try store.setPreference(panel.key, value: String(next)) } }
  }
  func restorePanelWidths() throws {
    for panel in StudioPanel.allCases {
      let saved = try store.preference(panel.key).flatMap(Double.init) ?? panel.standard
      setPanelWidth(panel, to: saved, persist: false)
    }
  }
  func inspectorDisplayWidth(available: Double) -> Double {
    min(inspectorWidth, max(220, available * 0.42))
  }
  func editorInspectorDocked(available: Double) -> Bool {
    available - inspectorDisplayWidth(available: available) >= 480
  }
  func companionDisplayWidth(available: Double) -> Double {
    min(companionWidth, max(320, available - 520))
  }
}

/// A native splitter supplies pointer tracking, keyboard adjustment and accessibility
/// without depending on a transparent SwiftUI shape becoming an accessibility element.
struct PanelResizeHandle: View {
  static let width: CGFloat = 9
  @ObservedObject var studio: Studio
  let panel: StudioPanel
  var displayedWidth: Double?
  var maximum: Double?
  var divider = true
  var body: some View {
    PanelResizeControl(
      studio: studio, panel: panel, displayedWidth: displayedWidth,
      maximum: maximum, divider: divider
    ).frame(width: Self.width).frame(maxHeight: .infinity)
  }
}

private struct PanelResizeControl: NSViewRepresentable {
  @ObservedObject var studio: Studio
  let panel: StudioPanel
  var displayedWidth: Double?
  var maximum: Double?
  var divider: Bool
  func makeNSView(context: Context) -> PanelDividerView { PanelDividerView() }
  func updateNSView(_ view: PanelDividerView, context: Context) {
    view.value = displayedWidth ?? studio.panelWidth(panel)
    view.limits =
      panel.limits.lowerBound...max(panel.limits.lowerBound, maximum ?? panel.limits.upperBound)
    view.standard = panel.standard
    view.growsRight = panel == .sidebar
    view.label = "\(panel.title) width"
    view.line = divider ? NSColor(studio.t.hairline) : .clear
    view.focus = NSColor(studio.t.accent)
    view.changed = { value, persist in studio.setPanelWidth(panel, to: value, persist: persist) }
    view.toolTip =
      "Drag to resize \(panel.title.lowercased()). Double-click to reset; arrow keys adjust when focused."
    view.needsDisplay = true
    view.window?.invalidateCursorRects(for: view)
  }
  static func dismantleNSView(_ view: PanelDividerView, coordinator: ()) { view.finish() }
}

final class PanelDividerView: NSView {
  var value = 300.0
  var limits = 260.0...480.0
  var standard = 300.0
  var growsRight = false
  var label = "Panel width"
  var line = NSColor.separatorColor
  var focus = NSColor.keyboardFocusIndicatorColor
  var changed: (Double, Bool) -> Void = { _, _ in }
  private var drag: (origin: Double, width: Double)?
  override var intrinsicContentSize: NSSize { NSSize(width: 9, height: NSView.noIntrinsicMetric) }
  override var acceptsFirstResponder: Bool { true }
  override func resetCursorRects() { addCursorRect(bounds, cursor: .resizeLeftRight) }
  override func draw(_ dirtyRect: NSRect) {
    line.setFill()
    NSRect(x: growsRight ? bounds.width - 1 : 0, y: 0, width: 1, height: bounds.height).fill()
    if window?.firstResponder === self {
      focus.setStroke()
      let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), xRadius: 3, yRadius: 3)
      path.lineWidth = 1
      path.stroke()
    }
  }
  override func becomeFirstResponder() -> Bool {
    needsDisplay = true
    return true
  }
  override func resignFirstResponder() -> Bool {
    finish()
    needsDisplay = true
    return true
  }
  private func apply(_ next: Double, persist: Bool = true) {
    guard next.isFinite else { return }
    value = min(limits.upperBound, max(limits.lowerBound, next))
    changed(value, persist)
    NSAccessibility.post(element: self, notification: .valueChanged)
  }
  override func mouseDown(with event: NSEvent) {
    if event.clickCount == 2 {
      apply(standard)
      return
    }
    window?.makeFirstResponder(self)
    drag = (event.locationInWindow.x, value)
  }
  override func mouseDragged(with event: NSEvent) {
    guard let drag else { return }
    apply(
      drag.width + (event.locationInWindow.x - drag.origin) * (growsRight ? 1 : -1), persist: false)
  }
  override func mouseUp(with event: NSEvent) { finish() }
  func finish() {
    guard drag != nil else { return }
    drag = nil
    changed(value, true)
  }
  override func keyDown(with event: NSEvent) {
    guard event.modifierFlags.intersection([.command, .control, .option]).isEmpty else {
      super.keyDown(with: event)
      return
    }
    if event.keyCode == 123 {
      apply(value - 16)
    } else if event.keyCode == 124 {
      apply(value + 16)
    } else {
      super.keyDown(with: event)
    }
  }
  override func isAccessibilityElement() -> Bool { true }
  override func accessibilityRole() -> NSAccessibility.Role? { .splitter }
  override func accessibilityLabel() -> String? { label }
  override func accessibilityValue() -> Any? { value }
  override func accessibilityHelp() -> String? {
    "Resize this panel. Left and right arrows adjust by 16 points. Double-click to reset."
  }
  override func accessibilityPerformIncrement() -> Bool {
    apply(value + 16)
    return true
  }
  override func accessibilityPerformDecrement() -> Bool {
    apply(value - 16)
    return true
  }
}

struct PanelWidthControl: View {
  @ObservedObject var studio: Studio
  let panel: StudioPanel
  var body: some View {
    HStack(spacing: 10) {
      Text("\(Int(studio.panelWidth(panel))) pt").font(.studio(.control)).monospacedDigit()
      Stepper(
        panel.title,
        value: Binding(
          get: { studio.panelWidth(panel) },
          set: { studio.setPanelWidth(panel, to: $0) }), in: panel.limits, step: 16
      ).labelsHidden()
    }.fixedSize()
      .contextMenu {
        Button("Reset width") { studio.setPanelWidth(panel, to: panel.standard) }
      }
  }
}
