import AppKit
import SwiftUI
import Testing

@testable import SynthesisUI

@MainActor struct InteractionTests {
  private final class State: ObservableObject {
    @Published var hovered = false
    @Published var scope = "Library"
    @Published var enabled = true
  }
  private struct Probe: View {
    @ObservedObject var state: State
    var body: some View {
      Text("Control").trackedHover($state.hovered)
        .environment(\.interactionScope, state.scope)
        .disabled(!state.enabled)
    }
  }
  @Test func transientHoverClearsWhenContextFocusOrAvailabilityChanges() async {
    _ = NSApplication.shared
    let state = State()
    let host = NSHostingView(rootView: Probe(state: state))
    host.frame = CGRect(x: 0, y: 0, width: 160, height: 60)
    func settle() async {
      host.layoutSubtreeIfNeeded()
      try? await Task.sleep(for: .milliseconds(40))
    }
    await settle()
    state.hovered = true
    await settle()
    state.scope = "Graph:Mira"
    await settle()
    #expect(!state.hovered)
    for notification in [
      NSApplication.didResignActiveNotification, NSWindow.didResignKeyNotification,
    ] {
      state.hovered = true
      await settle()
      NotificationCenter.default.post(name: notification, object: nil)
      await settle()
      #expect(!state.hovered)
    }
    state.hovered = true
    await settle()
    state.enabled = false
    await settle()
    #expect(!state.hovered)
    // This host never creates, orders or activates a window.
  }
}
