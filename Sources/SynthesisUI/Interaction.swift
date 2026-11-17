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
  @Environment(\.controlActiveState) private var activeState
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  func body(content: Content) -> some View {
    content
      .onContinuousHover { phase in
        switch phase {
        case .active: hovered = enabled && activeState == .key
        case .ended: hovered = false
        }
      }
      .onChange(of: enabled) { _, value in if !value { hovered = false } }
      .onChange(of: activeState) { _, value in if value != .key { hovered = false } }
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

/// One entity treatment across spatial cards, map labels, rows and event previews.
/// Neither hover nor selection changes layout, and neither is an editing/approval action.
private struct EntitySurface<S: Shape>: ViewModifier {
  let t: Theme
  let selected: Bool
  let shape: S
  let base: Color
  let bordered: Bool
  @State private var hovered = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  func body(content: Content) -> some View {
    content.background {
      shape.fill(base).overlay {
        shape.fill(selected ? t.selectionFill : (hovered ? t.hover : .clear))
      }.allowsHitTesting(false)
    }
    .overlay {
      shape.stroke(
        selected ? t.selectionBorder : (hovered ? t.hoverBorder : (bordered ? t.border : .clear)),
        lineWidth: selected ? 1.5 : 1
      ).allowsHitTesting(false)
    }
    .trackedHover($hovered)
    .onChange(of: selected) { _, _ in hovered = false }
    .animation(reduceMotion ? nil : Motion.feedbackAnimation, value: selected)
    .accessibilityAddTraits(selected ? .isSelected : [])
  }
}
extension View {
  func entitySurface<S: Shape>(
    _ t: Theme, selected: Bool, shape: S, base: Color = .clear, bordered: Bool = false
  ) -> some View {
    modifier(EntitySurface(t: t, selected: selected, shape: shape, base: base, bordered: bordered))
  }
  func entitySurface(
    _ t: Theme, selected: Bool, radius: CGFloat = Metric.cardRadius,
    base: Color = .clear, bordered: Bool = false
  ) -> some View {
    entitySurface(
      t, selected: selected, shape: RoundedRectangle(cornerRadius: radius),
      base: base, bordered: bordered)
  }
}
