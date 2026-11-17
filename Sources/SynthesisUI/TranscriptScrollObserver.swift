import AppKit
import SwiftUI

/// Observe the real clip view rather than treating each streamed chunk as a request to scroll.
/// A creator who scrolls upward owns the reading position until they return to the bottom.
struct TranscriptScrollObserver: NSViewRepresentable {
  var changed: (Bool) -> Void
  func makeNSView(context: Context) -> ObserverView {
    let view = ObserverView()
    view.changed = changed
    return view
  }
  func updateNSView(_ view: ObserverView, context: Context) { view.changed = changed }
  static func dismantleNSView(_ view: ObserverView, coordinator: ()) { view.detach() }

  final class ObserverView: NSView {
    var changed: ((Bool) -> Void)?
    private var observer: NSObjectProtocol?
    private var previousY: CGFloat?
    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      detach()
      DispatchQueue.main.async { [weak self] in self?.attach() }
    }
    private func attach() {
      guard observer == nil, let scroll = enclosingScrollView else { return }
      let clip = scroll.contentView
      previousY = clip.bounds.origin.y
      clip.postsBoundsChangedNotifications = true
      observer = NotificationCenter.default.addObserver(
        forName: NSView.boundsDidChangeNotification, object: clip, queue: .main
      ) { [weak self, weak scroll] _ in
        MainActor.assumeIsolated {
          guard let self, let scroll else { return }
          let y = scroll.contentView.bounds.origin.y
          defer { self.previousY = y }
          guard let previous = self.previousY, abs(y - previous) > 0.5 else { return }
          let remaining = (scroll.documentView?.bounds.height ?? 0) - scroll.contentView.bounds.maxY
          let follows = remaining <= 72
          DispatchQueue.main.async { [weak self] in self?.changed?(follows) }
        }
      }
    }
    func detach() {
      if let observer { NotificationCenter.default.removeObserver(observer) }
      observer = nil
    }
  }
}
