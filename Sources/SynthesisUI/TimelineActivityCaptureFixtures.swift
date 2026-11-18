import Foundation
import SynthesisCore

extension Studio {
  func configureTimelineActivityCapture(_ state: String, board: String, conversation: String) {
    guard ProcessInfo.processInfo.environment["SYNTHESIS_CAPTURE_DIR"] != nil else { return }
    configureConnectedCapture("empty-timeline", board: board, conversation: conversation)
    perform {
      let name = "The history of Glassharbor"
      let fixture: World
      if let saved = try store.worlds().first(where: { $0.name == name }) {
        fixture = saved
      } else {
        fixture = try store.createWorld(name: name)
        let first = try store.createChronologyLane(
          worldID: fixture.id, name: "Age of Glass", kind: "period", start: "Year 1",
          end: "Year 39")
        let later = try store.createChronologyLane(
          worldID: fixture.id, name: "The Long Tide", kind: "period", start: "Year 40",
          end: "Year 80")
        let laterChild = try store.createChronologyLane(
          worldID: fixture.id, name: "Lantern winters", kind: "period", parentID: later.id)
        try store.createTimelineCalendar(
          worldID: fixture.id, name: "Harbor reckoning", monthLengths: [30, 30, 30],
          daysPerWeek: 6, hoursPerDay: 24)
        let source = try store.createRecord(worldID: fixture.id, title: "Harbor annals")
        _ = try store.saveChronologyEvent(
          worldID: fixture.id, id: nil, title: "First charts", date: "", source: source.id,
          order: nil, laneID: first.id,
          timelineDate: .calendarDay(CalendarDay(year: 12, month: 1, day: 1)))
        for (title, date) in [
          ("The ledger is sealed", "Year 40"), ("Oren’s crossing", "Year 52"),
          ("The lamps go dark", ""),
        ] {
          _ = try store.saveChronologyEvent(
            worldID: fixture.id, id: nil, title: title, date: date, source: source.id, order: nil,
            laneID: laterChild.id)
        }
      }
      switchWorld(fixture.id)
      guard worldID == fixture.id else { throw SynthesisError.notFound }
      openTimelineLane(nil)
      timelineView = TimelineViewState(
        density: .overview, eraDateFilter: state == "timeline-activity" ? .all : .undated,
        query: state == "timeline-activity-empty" ? "missing song" : "")
      workspaceInspector = false
      companionExpanded = false
      captureHint = state
      captureNonce += 1
    }
  }
}
