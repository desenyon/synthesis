import Foundation

public struct CalendarDay: Codable, Equatable, Sendable {
  public var year: Int
  public var month: Int
  public var day: Int

  public init(year: Int, month: Int, day: Int) {
    self.year = year
    self.month = month
    self.day = day
  }

  public var label: String { "Year \(year) · Month \(month) · Day \(day)" }
}

/// A fixed civil calendar with a world-local epoch at the start of year 0.
/// The supported values keep elapsed hours exact during both integer conversion and plotting.
public struct TimelineCalendar: Equatable, Sendable {
  public let id: String
  public let name: String
  public let monthLengths: [Int]
  public let daysPerWeek: Int
  public let hoursPerDay: Int

  private static let years = -1_000_000...1_000_000

  init(id: String, name: String, monthLengths: [Int], daysPerWeek: Int, hoursPerDay: Int) throws {
    guard !name.isEmpty, name.count <= 120, !monthLengths.isEmpty, monthLengths.count <= 48,
      monthLengths.allSatisfy({ (1...500).contains($0) }),
      (1...100).contains(daysPerWeek), (1...100).contains(hoursPerDay)
    else {
      throw SynthesisError.invalid(
        "Give the calendar a short name, 1–48 months of 1–500 days, and 1–100 days per week and hours per day."
      )
    }
    self.id = id
    self.name = name
    self.monthLengths = monthLengths
    self.daysPerWeek = daysPerWeek
    self.hoursPerDay = hoursPerDay
  }

  /// Locates the day's beginning on the axis. A calendar date describes the whole civil day.
  public func startHour(of date: CalendarDay) throws -> Int64 {
    guard Self.years.contains(date.year), (1...monthLengths.count).contains(date.month),
      (1...monthLengths[date.month - 1]).contains(date.day)
    else { throw SynthesisError.invalid("Enter a valid year, month, and day in this calendar.") }
    let daysBeforeYear = Int64(date.year) * Int64(monthLengths.reduce(0, +))
    let daysBeforeMonth = Int64(monthLengths.prefix(date.month - 1).reduce(0, +))
    return (daysBeforeYear + daysBeforeMonth + Int64(date.day - 1)) * Int64(hoursPerDay)
  }

  public func day(containingHour hour: Int64) throws -> CalendarDay {
    let yearHours = Int64(monthLengths.reduce(0, +) * hoursPerDay)
    let remainder = hour % yearHours
    let year = hour / yearHours - (remainder < 0 ? 1 : 0)
    guard let civilYear = Int(exactly: year), Self.years.contains(civilYear) else {
      throw SynthesisError.invalid("This time falls outside the calendar's supported years.")
    }
    let hourWithinYear = remainder < 0 ? remainder + yearHours : remainder
    var dayIndex = Int(hourWithinYear) / hoursPerDay
    for (monthIndex, length) in monthLengths.enumerated() {
      if dayIndex < length {
        return CalendarDay(year: civilYear, month: monthIndex + 1, day: dayIndex + 1)
      }
      dayIndex -= length
    }
    throw SynthesisError.invalid("The calendar definition is invalid.")
  }
}

public enum TimelineEventDate: Equatable, Sendable {
  case calendarDay(CalendarDay)
  case unknown

  public var label: String {
    switch self {
    case .calendarDay(let date): return date.label
    case .unknown: return "Date unknown"
    }
  }
}

public struct TimelineTimeScale: Sendable {
  public let lowerHour: Int64
  public let upperHour: Int64

  public init?(hours: [Int64], minimumSpan: Int64) {
    guard let first = hours.min(), let last = hours.max(), minimumSpan > 0 else { return nil }
    if first == last {
      let (lower, lowerOverflow) = first.subtractingReportingOverflow(minimumSpan / 2)
      let (upper, upperOverflow) = lower.addingReportingOverflow(minimumSpan)
      guard !lowerOverflow, !upperOverflow else { return nil }
      lowerHour = lower
      upperHour = upper
    } else {
      lowerHour = first
      upperHour = last
    }
  }

  public func fraction(at hour: Int64) -> Double {
    let (delta, deltaOverflow) = hour.subtractingReportingOverflow(lowerHour)
    let (span, spanOverflow) = upperHour.subtractingReportingOverflow(lowerHour)
    if !deltaOverflow, !spanOverflow { return Double(delta) / Double(span) }
    return (Double(hour) - Double(lowerHour)) / (Double(upperHour) - Double(lowerHour))
  }
}

public struct TimelineEventExpectation: Equatable, Sendable {
  let worldID: String
  let event: WorldEvent
  public let laneID: String?
  public let date: TimelineEventDate?
  let dateRevision: String?
}

extension WorkspaceStore {
  public func timelineCalendar(worldID: String) throws -> TimelineCalendar? {
    _ = try world(worldID)
    guard
      let row = try db.rows("SELECT * FROM timeline_calendars WHERE world_id=?", [worldID]).first
    else { return nil }
    guard let raw = row["month_lengths"], raw.utf8.count <= 2_048,
      let id = row["id"], let name = row["name"],
      let week = row["days_per_week"].flatMap(Int.init),
      let hours = row["hours_per_day"].flatMap(Int.init)
    else { throw SynthesisError.invalid("The saved calendar definition is invalid.") }
    let lengths = try JSONDecoder().decode([Int].self, from: Data(raw.utf8))
    return try TimelineCalendar(
      id: id, name: name, monthLengths: lengths, daysPerWeek: week, hoursPerDay: hours)
  }

  @discardableResult public func createTimelineCalendar(
    worldID: String, name: String, monthLengths: [Int], daysPerWeek: Int, hoursPerDay: Int
  ) throws -> TimelineCalendar {
    let calendar = try TimelineCalendar(
      id: UUID().uuidString, name: name.trimmingCharacters(in: .whitespacesAndNewlines),
      monthLengths: monthLengths, daysPerWeek: daysPerWeek, hoursPerDay: hoursPerDay)
    let months = String(decoding: try JSONEncoder().encode(calendar.monthLengths), as: UTF8.self)
    return try db.transaction {
      guard try timelineCalendar(worldID: worldID) == nil else {
        throw SynthesisError.invalid("This world already has a Timeline calendar.")
      }
      let now = timestamp()
      try db.execute(
        """
        INSERT INTO timeline_calendars
          (id,world_id,name,month_lengths,days_per_week,hours_per_day,created_at,updated_at)
        VALUES(?,?,?,?,?,?,?,?)
        """,
        [
          calendar.id, worldID, calendar.name, months, String(daysPerWeek), String(hoursPerDay),
          now, now,
        ])
      return calendar
    }
  }

  public func timelineEventDates(worldID: String) throws -> [String: TimelineEventDate] {
    let calendar = try timelineCalendar(worldID: worldID)
    let rows = try db.rows(
      """
      SELECT d.* FROM timeline_event_dates d
      JOIN events e ON e.id=d.event_id AND e.world_id=d.world_id
      WHERE d.world_id=? AND e.archived=0
      """, [worldID])
    return try decodeTimelineEventDates(rows, calendar: calendar)
  }

  public func timelineEventExpectation(worldID: String, event: WorldEvent) throws
    -> TimelineEventExpectation
  {
    guard
      let row = try db.rows(
        """
        SELECT e.title,e.date_label,e.source_id,e.sort_order,p.lane_id,d.*
        FROM events e
        LEFT JOIN chronology_placements p ON p.event_id=e.id AND p.world_id=e.world_id
        LEFT JOIN timeline_event_dates d ON d.event_id=e.id AND d.world_id=e.world_id
        WHERE e.world_id=? AND e.id=? AND e.archived=0
        """, [worldID, event.id]
      ).first, row["title"] == event.title, row["date_label"] == event.dateLabel,
      row["source_id"] == event.sourceID, row["sort_order"].flatMap(Int.init) == event.order
    else { throw SynthesisError.stale }
    let revision = row["revision"]
    let date: TimelineEventDate?
    if revision != nil {
      date = try decodeTimelineEventDates([row], calendar: timelineCalendar(worldID: worldID))[
        event.id]
    } else {
      date = nil
    }
    return TimelineEventExpectation(
      worldID: worldID, event: event, laneID: row["lane_id"], date: date, dateRevision: revision)
  }

  func storeTimelineEventDate(worldID: String, eventID: String, date: TimelineEventDate) throws {
    guard
      try db.rows(
        "SELECT id FROM events WHERE world_id=? AND id=? AND archived=0 AND state='draft'",
        [worldID, eventID]
      ).first != nil
    else { throw SynthesisError.invalid("Only active draft events can be dated.") }
    let calendarID: String?
    let year: String?
    let month: String?
    let day: String?
    switch date {
    case .calendarDay(let value):
      guard let calendar = try timelineCalendar(worldID: worldID) else {
        throw SynthesisError.invalid("Define this world's Timeline calendar first.")
      }
      _ = try calendar.startHour(of: value)
      calendarID = calendar.id
      year = String(value.year)
      month = String(value.month)
      day = String(value.day)
    case .unknown:
      calendarID = nil
      year = nil
      month = nil
      day = nil
    }
    if let revision = try db.rows(
      "SELECT revision FROM timeline_event_dates WHERE world_id=? AND event_id=?",
      [worldID, eventID]
    ).first?["revision"].flatMap(Int.init), revision >= Int.max - 1 {
      throw SynthesisError.invalid("This saved Timeline date has reached its revision limit.")
    }
    let now = timestamp()
    try db.execute(
      """
      INSERT INTO timeline_event_dates
        (id,world_id,event_id,calendar_id,year,month,day,created_at,updated_at,revision)
      VALUES(?,?,?,?,?,?,?,?,?,1)
      ON CONFLICT(world_id,event_id) DO UPDATE SET calendar_id=excluded.calendar_id,
        year=excluded.year,month=excluded.month,day=excluded.day,updated_at=excluded.updated_at,
        revision=timeline_event_dates.revision+1
      WHERE timeline_event_dates.calendar_id IS NOT excluded.calendar_id
        OR timeline_event_dates.year IS NOT excluded.year
        OR timeline_event_dates.month IS NOT excluded.month
        OR timeline_event_dates.day IS NOT excluded.day
      """,
      [UUID().uuidString, worldID, eventID, calendarID, year, month, day, now, now])
  }

  func validateTimelineArchive(worldID: String) throws {
    let calendar = try timelineCalendar(worldID: worldID)
    let rows = try db.rows("SELECT * FROM timeline_event_dates WHERE world_id=?", [worldID])
    _ = try decodeTimelineEventDates(rows, calendar: calendar)
  }

  private func decodeTimelineEventDates(
    _ rows: [[String: String]], calendar: TimelineCalendar?
  ) throws -> [String: TimelineEventDate] {
    var result: [String: TimelineEventDate] = [:]
    for row in rows {
      guard let eventID = row["event_id"], let revision = row["revision"].flatMap(Int.init),
        revision > 0, revision < Int.max
      else { throw SynthesisError.invalid("The saved Timeline date is invalid.") }
      if row["calendar_id"] == nil {
        result[eventID] = .unknown
        continue
      }
      guard let calendar, row["calendar_id"] == calendar.id,
        let year = row["year"].flatMap(Int.init), let month = row["month"].flatMap(Int.init),
        let day = row["day"].flatMap(Int.init)
      else { throw SynthesisError.invalid("The saved Timeline date is invalid.") }
      let value = CalendarDay(year: year, month: month, day: day)
      _ = try calendar.startHour(of: value)
      result[eventID] = .calendarDay(value)
    }
    return result
  }
}
