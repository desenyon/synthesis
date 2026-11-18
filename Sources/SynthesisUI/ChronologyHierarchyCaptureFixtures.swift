import Foundation
import SynthesisCore

extension Studio {
  static let chronologyHierarchyCaptureStates = [
    "chronology-hierarchy", "chronology-hierarchy-age",
  ]

  func configureChronologyHierarchyCapture(_ state: String, board: String, conversation: String) {
    guard ProcessInfo.processInfo.environment["SYNTHESIS_CAPTURE_DIR"] != nil else { return }
    configureConnectedCapture("empty-timeline", board: board, conversation: conversation)
    perform {
      let name = "Chronology study"
      let fixture: World
      if let existing = try store.worlds().first(where: { $0.name == name }) {
        fixture = existing
      } else {
        fixture = try store.createWorld(name: name)
        let age = try store.createChronologyLane(
          worldID: fixture.id, name: "Age of the crossing", kind: "period", start: "Year 10",
          end: "Year 80")
        let tides = try store.createChronologyLane(
          worldID: fixture.id, name: "The early tides", kind: "period", parentID: age.id,
          start: "Year 20", end: "Year 60")
        let rule = try store.createChronologyLane(
          worldID: fixture.id, name: "Harbour rule", kind: "period", parentID: age.id,
          start: "Year 50", end: "Year 70")
        let alternate = try store.createChronologyLane(
          worldID: fixture.id, name: "Western account", kind: "branch", start: "Year 10",
          end: "Year 80")
        for (title, lane) in [
          ("The tidekeepers arrive", tides), ("The harbour council meets", rule),
          ("The crossing is postponed", alternate),
        ] {
          _ = try store.saveChronologyEvent(
            worldID: fixture.id, id: nil, title: title, date: "Year 52", source: nil, order: nil,
            laneID: lane.id)
        }
      }
      switchWorld(fixture.id)
      guard worldID == fixture.id else { throw SynthesisError.notFound }
      let lanes = try store.chronologyLanes(worldID: worldID)
      let age = lanes.first { $0.name == "Age of the crossing" }
      guard let age else { throw SynthesisError.notFound }
      openTimelineLane(state.hasSuffix("-age") ? age.id : nil)
      timelineView = TimelineViewState(density: .overview)
      workspaceInspector = false
      companionExpanded = false
      captureHint = state
    }
  }
}
