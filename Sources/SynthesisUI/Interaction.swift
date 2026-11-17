import AppKit
import SwiftUI

private struct InteractionScopeKey: EnvironmentKey {
  static let defaultValue = ""
}
extension EnvironmentValues {
  /// Changing pages or object selection invalidates transient pointer feedback.
  var interactionScope: String {
    get { self[InteractionScopeKey.self] }
    set { self[InteractionScopeKey.self] = newValue }
  }
}

/// One pointer lifecycle for native controls. SwiftUI may omit an exit event when a menu,
/// another window or navigation removes the hovered area; clear those paths explicitly.
private struct TrackedHover: ViewModifier {
  @Binding var hovered: Bool
  @Environment(\.isEnabled) private var enabled
  @Environment(\.interactionScope) private var scope
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  func body(content: Content) -> some View {
    content
      .onContinuousHover { phase in
        switch phase {
        case .active: hovered = enabled
        case .ended: hovered = false
        }
      }
      .onChange(of: enabled) { _, value in if !value { hovered = false } }
      .onChange(of: scope) { _, _ in hovered = false }
      .onDisappear { hovered = false }
      .onReceive(
        NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)
      ) { _ in hovered = false }
      .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) {
        _ in hovered = false
      }
      .animation(reduceMotion ? nil : Motion.feedbackAnimation, value: hovered)
  }
}
extension View {
  func trackedHover(_ hovered: Binding<Bool>) -> some View {
    modifier(TrackedHover(hovered: hovered))
  }
}
