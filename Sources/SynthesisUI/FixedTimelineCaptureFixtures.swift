import Foundation
import SynthesisCore

extension Studio {
  func configureFixedTimelineCapture(_ state: String, board: String, conversation: String) {
    guard ProcessInfo.processInfo.environment["SYNTHESIS_CAPTURE_DIR"] != nil else { return }
    configureConnectedCapture("empty-timeline", board: board, conversation: conversation)
    perform {
      let needsCalendar = state != "timeline-axis-new-calendar"
      let name = needsCalendar ? "The Tidekeeper calendar" : "Calendar planning"
      let fixture: World
      if let existing = try store.worlds().first(where: { $0.name == name }) {
        fixture = existing
      } else {
        fixture = try store.createWorld(name: name)
        if needsCalendar {
          try store.createTimelineCalendar(
            worldID: fixture.id, name: "Tidekeeper reckoning", monthLengths: [20, 33, 20],
            daysPerWeek: 6, hoursPerDay: 20)
          for (title, day) in [
            ("First crossing", 1), ("Bells of Glass", 4), ("Return of the lanterns", 13),
            ("Letters arrive", 13),
          ] {
            _ = try store.saveChronologyEvent(
              worldID: fixture.id, id: nil, title: title, date: "", source: nil, order: nil,
              laneID: nil, timelineDate: .calendarDay(CalendarDay(year: 40, month: 2, day: day)))
          }
          _ = try store.saveChronologyEvent(
            worldID: fixture.id, id: nil, title: "A harbour abandoned", date: "First winter",
            source: nil, order: nil, laneID: nil)
          _ = try store.saveChronologyEvent(
            worldID: fixture.id, id: nil, title: "The journals go missing", date: "",
            source: nil, order: nil, laneID: nil, timelineDate: .unknown)
        }
      }
      switchWorld(fixture.id)
      guard worldID == fixture.id else { throw SynthesisError.notFound }
      openTimelineLane(nil)
      timelineView = TimelineViewState(density: .axis)
      workspaceInspector = false
      companionExpanded = false
      captureHint = state
      captureNonce += 1
    }
  }
}
