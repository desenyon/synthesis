import Foundation
import SynthesisCore

extension Studio {
  /// Reconstruct the real root from persisted preferences; never assign its destination as a fixture.
  public func reopenedStartupCapture(_ state: String, transport: any ModelTransport) throws
    -> Studio
  {
    guard ProcessInfo.processInfo.environment["SYNTHESIS_CAPTURE_DIR"] != nil else {
      throw SynthesisError.invalid("Startup capture requires isolated data.")
    }
    let world = try store.worlds().first {
      state.contains("empty-") ? $0.name == "Halcyon" : $0.demo
    }
    guard let world else { throw SynthesisError.invalid("Missing startup fixture world.") }
    let before = try store.records(worldID: world.id)
    let choice: StartupWorkspace
    if state.hasSuffix("conversation") {
      choice = .conversation
    } else if state.hasSuffix("canvas") {
      choice = .canvas
    } else if state.hasSuffix("dashboard") {
      choice = .dashboard
    } else if state.hasSuffix("last") {
      choice = .remember
    } else {
      choice = .atlas
    }
    var preferences = StudioPreferences()
    preferences.launchWorkspace = choice.rawValue
    try store.setStudioPreferences(preferences)
    try store.setPreference("world", value: world.id)
    try store.setPreference("mode", value: state.hasPrefix("manual-") ? "manual" : "assisted")
    try store.setPreference("theme", value: state.hasPrefix("light-") ? "light" : "dark")
    try store.setPreference("sidebar", value: "expanded")
    try store.setPreference("workspace-inspector", value: "hidden")
    try store.setPreference("destination", value: Destination.knowledge.rawValue)
    try store.setPreference("onboarding-completed", value: "1")
    let reopened = try Studio(store: store, transport: transport)
    let wanted = Destination(rawValue: choice.rawValue) ?? .knowledge
    let expected: Destination = reopened.mode == .manual && wanted == .chat ? .library : wanted
    guard reopened.destination == expected, reopened.worldID == world.id,
      reopened.preferences.launchWorkspace == choice.rawValue, reopened.records == before,
      !reopened.busy, reopened.sheet == nil
    else {
      throw SynthesisError.invalid("Persisted startup did not restore the expected workspace.")
    }
    reopened.captureHint = state
    if state.hasSuffix("settings") {
      reopened.openSettings(.general, query: "Open at launch")
    }
    print(
      "STARTUP_AUDIT PASS \(state): new Studio restored \(expected.rawValue), saved home and world; lore unchanged"
    )
    return reopened
  }
}
