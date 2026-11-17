import AppKit
import SynthesisCore

/// Exercises the rendered controls' native accessibility actions without key or pointer events.
@MainActor public func auditPanelSizes(in root: NSView, studio: Studio, companion: Bool)
  async throws -> [String]
{
  guard ProcessInfo.processInfo.environment["SYNTHESIS_CAPTURE_DIR"] != nil, !NSApp.isActive else {
    throw SynthesisError.invalid("Panel verification requires the background capture runner.")
  }
  var labels: [String] = []
  func find(_ label: String) -> (any NSAccessibilityProtocol)? {
    var visited = Set<ObjectIdentifier>()
    func visit(_ value: Any) -> (any NSAccessibilityProtocol)? {
      guard let object = value as? NSObject, visited.insert(ObjectIdentifier(object)).inserted
      else { return nil }
      if let element = object as? any NSAccessibilityProtocol {
        if let name = element.accessibilityLabel() { labels.append(name) }
        if element.accessibilityLabel() == label { return element }
        for child in element.accessibilityChildren() ?? [] {
          if let found = visit(child) { return found }
        }
      }
      if let view = object as? NSView {
        for child in view.subviews { if let found = visit(child) { return found } }
      }
      return nil
    }
    return visit(root)
  }
  var checks: [String] = []
  for panel in [StudioPanel.sidebar, companion ? .companion : .inspector] {
    let label = "\(panel.title) width"
    guard let control = find(label) else {
      throw SynthesisError.invalid("Missing resize control: \(label); saw \(labels.prefix(70))")
    }
    guard let divider = control as? PanelDividerView,
      abs(divider.bounds.width - 9) < 0.5, divider.bounds.height > 100
    else {
      throw SynthesisError.invalid("\(label) must have a 9-point, full-height hit area")
    }
    let before = studio.panelWidth(panel)
    guard control.accessibilityPerformDecrement() else {
      throw SynthesisError.invalid("Cannot decrease \(label)")
    }
    try await Task.sleep(for: .milliseconds(120))
    guard studio.panelWidth(panel) == before - 16 else {
      throw SynthesisError.invalid("\(label) did not decrease")
    }
    guard let fresh = find(label), fresh.accessibilityPerformIncrement() else {
      throw SynthesisError.invalid("Cannot increase \(label)")
    }
    try await Task.sleep(for: .milliseconds(120))
    guard studio.panelWidth(panel) == before,
      try studio.store.preference(panel.key).flatMap(Double.init) == before,
      !NSApp.isActive, root.window?.isKeyWindow != true
    else {
      throw SynthesisError.invalid(
        "\(label) failed restore, persistence or background verification")
    }
    checks.append(
      "PASS \(label): narrow hit area, native increment/decrement and persistence without activation"
    )
  }
  return checks
}
