import Foundation
import Testing

@testable import SynthesisCore

struct FixedTimelineTests {
  @Test func authoredCalendarPlacesDatesByElapsedTimeAcrossZero() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "History")
    let calendar = try store.createTimelineCalendar(
      worldID: world.id, name: "Tidekeeper reckoning", monthLengths: [10, 20],
      daysPerWeek: 6, hoursPerDay: 20)
    #expect(try calendar.startHour(of: CalendarDay(year: -1, month: 2, day: 20)) == -20)
    #expect(try calendar.startHour(of: CalendarDay(year: 0, month: 1, day: 1)) == 0)
    #expect(try calendar.startHour(of: CalendarDay(year: 0, month: 2, day: 1)) == 200)
    #expect(try calendar.day(containingHour: -1) == CalendarDay(year: -1, month: 2, day: 20))
    #expect(throws: (any Error).self) {
      try calendar.startHour(of: CalendarDay(year: 0, month: 1, day: 11))
    }
    #expect(throws: (any Error).self) {
      try calendar.startHour(of: CalendarDay(year: Int.max, month: 1, day: 1))
    }
    let scale = try #require(TimelineTimeScale(hours: [0, 200, 600], minimumSpan: 20))
    #expect(scale.fraction(at: 200) == 1.0 / 3.0)
    #expect(scale.fraction(at: 600) == 1.0)
    #expect(TimelineTimeScale(hours: [], minimumSpan: 20) == nil)
    let single = try #require(TimelineTimeScale(hours: [200], minimumSpan: 20))
    #expect(single.fraction(at: 200) == 0.5)
  }

  @Test func typedEventEditsAreAtomicScopedAndStaleSafe() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "History")
    let foreign = try store.createWorld(name: "Elsewhere")
    let calendar = try store.createTimelineCalendar(
      worldID: world.id, name: "Reckoning", monthLengths: [10, 20],
      daysPerWeek: 6, hoursPerDay: 20)
    let date = TimelineEventDate.calendarDay(CalendarDay(year: 2, month: 1, day: 7))
    #expect(throws: (any Error).self) {
      try store.saveChronologyEvent(
        worldID: foreign.id, id: nil, title: "No calendar here", date: "Winter",
        source: nil, order: nil, laneID: nil, timelineDate: date)
    }
    #expect(try store.records(worldID: foreign.id).isEmpty)
    #expect(try store.events(worldID: foreign.id).isEmpty)
    let event = try store.saveChronologyEvent(
      worldID: world.id, id: nil, title: "Crossing", date: "First winter",
      source: nil, order: 7, laneID: nil, timelineDate: date)
    let old = try store.timelineEventExpectation(worldID: world.id, event: event)
    #expect(try store.timelineEventDates(worldID: world.id)[event.id] == date)
    try store.setEventArchived(worldID: world.id, id: event.id, archived: true)
    #expect(try store.timelineEventDates(worldID: world.id)[event.id] == nil)
    try store.setEventArchived(worldID: world.id, id: event.id, archived: false)
    #expect(try store.timelineEventDates(worldID: world.id)[event.id] == date)
    _ = try store.saveChronologyEvent(
      worldID: world.id, id: event.id, title: event.title, date: event.dateLabel,
      source: event.sourceID, order: event.order, laneID: nil,
      timelineDate: .unknown, expected: old)
    #expect(try store.timelineEventDates(worldID: world.id)[event.id] == .unknown)
    #expect(throws: (any Error).self) {
      try store.saveChronologyEvent(
        worldID: world.id, id: event.id, title: "Stale edit", date: "",
        source: nil, order: nil, laneID: nil, timelineDate: date, expected: old)
    }
    #expect(try store.events(worldID: world.id).first?.title == "Crossing")
    #expect(try store.records(worldID: world.id).count == 1)
    #expect(try store.timelineCalendar(worldID: world.id) == calendar)
  }

  @Test func chronologyRoundTripKeepsCoordinatesAndLiteralLegacyLabels() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "History")
    let calendar = try store.createTimelineCalendar(
      worldID: world.id, name: world.id, monthLengths: [9, 47],
      daysPerWeek: 7, hoursPerDay: 24)
    let legacy = try store.saveChronologyEvent(
      worldID: world.id, id: nil, title: "Legacy event", date: world.id, source: nil,
      order: -2, laneID: nil)
    let date = TimelineEventDate.calendarDay(CalendarDay(year: 42, month: 2, day: 2))
    let timed = try store.saveChronologyEvent(
      worldID: world.id, id: nil, title: "Dated event", date: "First winter", source: nil,
      order: 5, laneID: nil, timelineDate: date)
    try store.setEventArchived(worldID: world.id, id: timed.id, archived: true)
    let raw = try store.exportWorldArchive(worldID: world.id)
    let (copy, ids) = try store.importWorldArchiveMapping(raw)
    let copiedCalendar = try #require(try store.timelineCalendar(worldID: copy.id))
    #expect(copiedCalendar.id != calendar.id && copiedCalendar.name == world.id)
    let copiedLegacy = try #require(try store.events(worldID: copy.id).first)
    #expect(copiedLegacy.id == ids[legacy.id])
    #expect(copiedLegacy.dateLabel == world.id && copiedLegacy.order == -2)
    let copiedTimedID = try #require(ids[timed.id])
    #expect(try store.timelineEventDates(worldID: copy.id)[copiedTimedID] == nil)
    try store.setEventArchived(worldID: copy.id, id: copiedTimedID, archived: false)
    #expect(try store.timelineEventDates(worldID: copy.id)[copiedTimedID] == date)
    let json = try #require(
      JSONSerialization.jsonObject(with: store.exportWorld(copy.id)) as? [String: Any])
    #expect((json["timelineEventDates"] as? [[String: String]])?.count == 1)

    var malformed = try JSONDecoder().decode(WorldArchive.self, from: raw)
    malformed.tables["timeline_event_dates"]?[0]["day"] = "48"
    #expect(throws: (any Error).self) {
      try store.importWorldArchive(JSONEncoder().encode(malformed))
    }
    malformed.version = 12
    malformed.tables.removeValue(forKey: "timeline_event_dates")
    malformed.tables.removeValue(forKey: "timeline_calendars")
    let older = try store.importWorldArchive(JSONEncoder().encode(malformed))
    #expect(try store.timelineCalendar(worldID: older.id) == nil)
    #expect(try store.timelineEventDates(worldID: older.id).isEmpty)
    #expect(try store.events(worldID: older.id).first?.order == -2)
  }

  @Test func dateAtTheRevisionLimitRemainsReadableAfterARejectedEdit() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "History")
    _ = try store.createTimelineCalendar(
      worldID: world.id, name: "Reckoning", monthLengths: [30], daysPerWeek: 6, hoursPerDay: 20)
    let event = try store.saveChronologyEvent(
      worldID: world.id, id: nil, title: "Crossing", date: "", source: nil, order: nil,
      laneID: nil, timelineDate: .unknown)
    try store.db.execute(
      "UPDATE timeline_event_dates SET revision=? WHERE world_id=? AND event_id=?",
      [String(Int.max - 1), world.id, event.id])
    let expected = try store.timelineEventExpectation(worldID: world.id, event: event)
    #expect(throws: SynthesisError.self) {
      try store.saveChronologyEvent(
        worldID: world.id, id: event.id, title: "Attempted change", date: "",
        source: event.sourceID,
        order: nil, laneID: nil, timelineDate: .calendarDay(.init(year: 1, month: 1, day: 1)),
        expected: expected)
    }
    #expect(try store.timelineEventDates(worldID: world.id)[event.id] == .unknown)
    #expect(try store.events(worldID: world.id).first?.title == event.title)
  }

  @Test func calendarOnlyEditsRecordActivityWithoutDuplicationOnImport() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Calendar activity")
    try store.createTimelineCalendar(
      worldID: world.id, name: "Reckoning", monthLengths: [30],
      daysPerWeek: 7, hoursPerDay: 24)
    let event = try store.saveChronologyEvent(
      worldID: world.id, id: nil, title: "Crossing", date: "First winter",
      source: nil, order: nil, laneID: nil)
    func apply(_ date: TimelineEventDate) throws {
      let expected = try store.timelineEventExpectation(worldID: world.id, event: event)
      try store.saveChronologyEvent(
        worldID: world.id, id: event.id, title: event.title, date: event.dateLabel,
        source: event.sourceID, order: event.order, laneID: nil, timelineDate: date,
        expected: expected)
    }
    let day = TimelineEventDate.calendarDay(.init(year: 1, month: 1, day: 2))
    try apply(day)
    try apply(day)
    try apply(.unknown)
    let activity = try store.worldChangeHistory(worldID: world.id, kind: .event)
      .filter { $0.detail.hasPrefix("Calendar date") }
    #expect(activity.map(\.detail) == ["Calendar date updated", "Calendar date set"])
    #expect(activity.allSatisfy { $0.objectID == event.id && $0.action == .updated })

    let copy = try store.importWorldArchiveMapping(store.exportWorldArchive(worldID: world.id))
    let copied = try store.worldChangeHistory(worldID: copy.world.id, kind: .event)
      .filter { $0.detail.hasPrefix("Calendar date") }
    #expect(copied.count == 2 && copied.allSatisfy { $0.objectID == copy.ids[event.id] })
  }
}
