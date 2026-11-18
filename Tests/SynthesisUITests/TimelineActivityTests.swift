import Testing

@testable import SynthesisCore
@testable import SynthesisUI

struct TimelineActivityTests {
  @Test func countGroupsUseLiveEraMembershipAndTheSelectedDateFilter() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Histories")
    let source = try store.createRecord(worldID: world.id, title: "Annals")
    let first = try store.createChronologyLane(
      worldID: world.id, name: "First Age", kind: "period")
    let nested = try store.createChronologyLane(
      worldID: world.id, name: "The Crossing", kind: "period", parentID: first.id)
    let second = try store.createChronologyLane(
      worldID: world.id, name: "Second Age", kind: "period")

    try store.createTimelineCalendar(
      worldID: world.id, name: "Reckoning", monthLengths: [28, 28], daysPerWeek: 7,
      hoursPerDay: 24)
    func add(
      _ title: String, date: String, lane: String?, calendarDate: TimelineEventDate? = nil
    ) throws -> WorldEvent {
      try store.saveChronologyEvent(
        worldID: world.id, id: nil, title: title, date: date, source: source.id, order: nil,
        laneID: lane, timelineDate: calendarDate)
    }
    let a = try add("Founding", date: "  UNKNOWN  ", lane: first.id)
    let b = try add(
      "Crossing", date: "", lane: nested.id,
      calendarDate: .calendarDay(CalendarDay(year: 12, month: 1, day: 1)))
    let c = try add("Drowning", date: "Year 40", lane: second.id)
    let d = try add("Lights go out", date: "", lane: nil, calendarDate: .unknown)
    let placements = try store.chronologyPlacements(worldID: world.id)

    func groups(_ filter: TimelineDateFilter) throws -> [TimelineEraGroup] {
      let dates = try store.timelineEventDates(worldID: world.id)
      return TimelineEraGroup.group(
        try store.events(worldID: world.id).filter { filter.includes($0, date: dates[$0.id]) },
        lanes: try store.chronologyLanes(worldID: world.id), placements: placements)
    }
    let all = try groups(.all)
    #expect(all.map(\.id) == [first.id, second.id, TimelineViewState.unplacedEraID])
    #expect(all.map { $0.events.map(\.id) } == [[a.id, b.id], [c.id], [d.id]])
    #expect(try groups(.dated).flatMap(\.events).map(\.id) == [b.id, c.id])
    #expect(try groups(.undated).flatMap(\.events).map(\.id) == [a.id, d.id])

    try store.setChronologyLaneArchived(worldID: world.id, id: first.id, archived: true)
    let afterArchive = try groups(.all)
    #expect(afterArchive.map(\.id) == [nested.id, second.id, TimelineViewState.unplacedEraID])
    #expect(afterArchive.map { $0.events.map(\.id) } == [[b.id], [c.id], [a.id, d.id]])

    try store.setEventArchived(worldID: world.id, id: d.id, archived: true)
    #expect(try groups(.undated).first?.events.map(\.id) == [a.id])
  }
}
