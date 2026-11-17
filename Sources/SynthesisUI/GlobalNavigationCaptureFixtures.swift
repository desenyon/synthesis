import Foundation
import SynthesisCore

extension Studio {
  func configureGlobalNavigationCapture(_ state: String, board: String, conversation: String) {
    let base: String
    if state.hasSuffix("map") {
      base = "atlas-linked"
    } else if state.hasSuffix("canvas") {
      base = "canvas"
    } else if state.hasSuffix("graph") {
      base = "graph"
    } else if state.hasSuffix("timeline") {
      base = "timeline"
    } else {
      base = "library"
    }
    configureConnectedCapture(base, board: board, conversation: conversation)
    dark = !state.hasPrefix("light-")
    if state.hasPrefix("manual-") { setMode(.manual) }
    perform {
      if state.hasSuffix("settings") {
        openSettings(.writing)
      } else if state.hasSuffix("record"),
        let record = records.first(where: { $0.title == "Mira Vale" })
      {
        openRecord(record)
        openRecordTab(.sections, recordID: record.id)
        inspector = false
      } else if state.hasSuffix("review") {
        openReviewSection(.checks)
      } else if state.hasSuffix("timeline") {
        let lanes = try store.chronologyLanes(worldID: worldID)
        let lane =
          try lanes.first
          ?? store.createChronologyLane(
            worldID: worldID, name: "The age of crossings", kind: "period")
        openTimelineLane(lane.id)
        inspect(.lane(lane.id))
      } else if state.hasSuffix("graph"), let record = records.first {
        showRelationships(for: record)
      } else if state.hasSuffix("library") {
        openLens("Places")
        libraryQuery = "sea"
      }
    }
    captureHint = state
  }

  /// The native menu's real Back/Forward actions are injected by the capture app delegate.
  public func auditGlobalNavigationCapture(
    _ state: String, back: () throws -> Void, forward: () throws -> Void
  ) async throws -> [String] {
    guard ProcessInfo.processInfo.environment["SYNTHESIS_CAPTURE_DIR"] != nil else {
      throw SynthesisError.invalid("Navigation audit requires isolated capture data.")
    }
    let expected = navigationLocation
    if state.hasSuffix("library") {
      let matches = try store.search(
        worldID: worldID, query: libraryQuery, scope: .init(category: libraryCategory))
      guard matches.contains(where: { $0.title == "The Glass Sea" }) else {
        throw SynthesisError.invalid("The Library search has lost its source records.")
      }
    }
    let originalMode = mode
    let sources = try store.records(worldID: worldID)
    openSettings(.data, query: "export")
    try await Task.sleep(for: .milliseconds(200))
    let later = navigationLocation
    guard later != expected, canNavigateBack else { throw SynthesisError.notFound }
    try back()
    try await Task.sleep(for: .milliseconds(250))
    guard navigationLocation == expected, canNavigateForward else {
      throw SynthesisError.invalid("Back failed to restore \(state).")
    }
    try forward()
    try await Task.sleep(for: .milliseconds(200))
    guard navigationLocation == later else {
      throw SynthesisError.invalid("Forward failed to restore \(state).")
    }
    try back()
    try await Task.sleep(for: .milliseconds(250))
    guard navigationLocation == expected, mode == originalMode, !busy, error == nil,
      try store.records(worldID: worldID) == sources
    else { throw SynthesisError.invalid("Navigation changed source data or failed: \(state).") }
    return [
      "PASS \(state): native Back/Forward/Back actions restore exact document/map/tool address",
      "PASS \(state): current source data and assistance mode unchanged; no generation active",
    ]
  }
}
