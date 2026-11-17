import SwiftUI
import SynthesisCore

extension Studio {
  public var canFocusWorkspace: Bool {
    sheet == nil && (hasVisibleDocument || ![.settings, .worlds].contains(destination))
  }
  /// Temporary presentation only: no panel preferences, lore, tab addresses or AI permissions change.
  public func toggleFocusMode() {
    guard focusMode || canFocusWorkspace else { return }
    guard flushEditor() else { return }
    persistPendingComposer()
    mobileNavigation = false
    focusMode.toggle()
  }
  func visibleSidebarWidth(windowWidth: Double) -> Double {
    windowWidth < 760 || focusMode ? 0 : (collapsed ? Double(Metric.rail) : sidebarWidth)
  }
}

struct FocusWorkspaceControl: View {
  @ObservedObject var studio: Studio
  var body: some View {
    if studio.focusMode {
      if studio.busy {
        IconButton(icon: "stop.fill", label: "Stop response", t: studio.t) { studio.stop() }
      }
      Button("Exit focus") { studio.toggleFocusMode() }
        .buttonStyle(QuietButton(t: studio.t)).help("Exit focus · ⌥⌘F")
        .accessibilityIdentifier("exit-workspace-focus")
    } else if studio.canFocusWorkspace {
      Button("Focus") { studio.toggleFocusMode() }
        .buttonStyle(QuietButton(t: studio.t)).help("Focus workspace · ⌥⌘F")
        .accessibilityIdentifier("enter-workspace-focus")
    }
  }
}
