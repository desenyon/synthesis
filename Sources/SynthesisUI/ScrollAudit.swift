import AppKit
import SynthesisCore

/// Exercises real rendered scroll views without pointer events or activating a window.
/// This is used only by the isolated capture runner, never by a creator's session.
@MainActor public func auditScrollRegions(in root: NSView, showing target: String) async throws
  -> [String]
{
  guard ProcessInfo.processInfo.environment["SYNTHESIS_CAPTURE_DIR"] != nil else {
    throw SynthesisError.invalid("Scroll verification requires the isolated capture runner.")
  }
  root.layoutSubtreeIfNeeded()
  root.displayIfNeeded()
  func collect(_ view: NSView) -> [NSScrollView] {
    let own = (view as? NSScrollView).map { [$0] } ?? []
    return own + view.subviews.flatMap(collect)
  }
  let candidates = collect(root).filter { $0.bounds.width > 130 && $0.bounds.height > 100 }
    .sorted { $0.convert($0.bounds, to: root).midX < $1.convert($1.bounds, to: root).midX }
  guard candidates.count == 3 else {
    throw SynthesisError.invalid(
      "Expected navigation, document and inspector scroll regions; found \(candidates.map { "\(type(of: $0)): \($0.frame)" }.joined(separator: "; "))"
    )
  }
  let names = ["sidebar", "document", "inspector"]
  // Open document views deliberately retain their viewport across fixture changes.
  // Establish the same baseline for every capture before testing relative movement.
  for scroll in candidates {
    scroll.contentView.scroll(to: .zero)
    scroll.reflectScrolledClipView(scroll.contentView)
  }
  try await Task.sleep(for: .milliseconds(100))
  let frames = candidates.map { $0.convert($0.bounds, to: root) }
  var checks: [String] = []
  for (index, scroll) in candidates.enumerated() {
    let offsets = candidates.map { $0.contentView.bounds.origin }
    let available = (scroll.documentView?.bounds.height ?? 0) - scroll.contentSize.height
    guard available > 100 else {
      throw SynthesisError.invalid("The \(names[index]) scroll fixture is too short: \(available)")
    }
    let desired = NSPoint(x: offsets[index].x, y: min(280, available))
    scroll.contentView.scroll(to: desired)
    scroll.reflectScrolledClipView(scroll.contentView)
    try await Task.sleep(for: .milliseconds(100))
    root.layoutSubtreeIfNeeded()
    guard abs(scroll.contentView.bounds.origin.y - offsets[index].y) > 50 else {
      throw SynthesisError.invalid("The \(names[index]) region did not scroll.")
    }
    for other in candidates.indices where other != index {
      guard candidates[other].contentView.bounds.origin == offsets[other] else {
        throw SynthesisError.invalid("Scrolling \(names[index]) also moved \(names[other]).")
      }
    }
    guard candidates.map({ $0.convert($0.bounds, to: root) }) == frames else {
      throw SynthesisError.invalid("Scrolling \(names[index]) moved workspace frames.")
    }
    checks.append("PASS \(names[index]) scrolls independently without moving workspace frames")
    scroll.contentView.scroll(to: offsets[index])
    scroll.reflectScrolledClipView(scroll.contentView)
    try await Task.sleep(for: .milliseconds(50))
  }
  if let index = names.firstIndex(of: target) {
    let scroll = candidates[index]
    let available = (scroll.documentView?.bounds.height ?? 0) - scroll.contentSize.height
    scroll.contentView.scroll(to: NSPoint(x: 0, y: min(280, available)))
    scroll.reflectScrolledClipView(scroll.contentView)
    try await Task.sleep(for: .milliseconds(100))
  }
  return checks
}
