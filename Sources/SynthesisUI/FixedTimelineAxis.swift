import SwiftUI
import SynthesisCore

struct FixedTimelineAxis: View {
  let calendar: TimelineCalendar
  let events: [WorldEvent]
  let dates: [String: TimelineEventDate]
  let t: Theme
  var inspect: (WorldEvent) -> Void
  var edit: (WorldEvent) -> Void

  @State private var magnification = 1
  private let margin: CGFloat = 76

  private struct Entry {
    let event: WorldEvent
    let hour: Int64
    let day: CalendarDay
  }

  var body: some View {
    let entries = events.compactMap { event -> Entry? in
      guard case .calendarDay(let day)? = dates[event.id],
        let start = try? calendar.startHour(of: day)
      else { return nil }
      return Entry(event: event, hour: start, day: day)
    }.sorted { ($0.hour, $0.event.id) < ($1.hour, $1.event.id) }
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 8) {
        Text(calendar.name).font(.studio(.cardTitle)).lineLimit(1)
        Spacer(minLength: 6)
        IconButton(icon: "minus", label: "Zoom out", t: t) {
          magnification /= 2
        }.disabled(magnification <= 1 || entries.isEmpty)
        Button("Fit") { magnification = 1 }
          .buttonStyle(QuietButton(t: t)).disabled(magnification == 1 || entries.isEmpty)
        IconButton(icon: "plus", label: "Zoom in", t: t) {
          magnification *= 2
        }.disabled(magnification >= 16 || entries.isEmpty)
      }
      if let scale = TimelineTimeScale(
        hours: entries.map(\.hour), minimumSpan: Int64(calendar.hoursPerDay))
      {
        GeometryReader { geometry in
          let width = max(2 * margin + 1, geometry.size.width) * CGFloat(magnification)
          ScrollView(.horizontal) {
            chart(entries, scale: scale, width: width)
          }
        }.frame(height: 122)
        Text("Markers identify calendar days.").font(.studio(.caption)).foregroundStyle(t.muted)
      } else {
        Text("Add a calendar date to an event to place it on the axis.")
          .font(.studio(.label)).foregroundStyle(t.secondary)
      }
    }
  }

  private func chart(_ entries: [Entry], scale: TimelineTimeScale, width: CGFloat) -> some View {
    let plotWidth = width - 2 * margin
    let locations = entries.map { margin + plotWidth * CGFloat(scale.fraction(at: $0.hour)) }
    let stepCount = max(2, min(40, Int(plotWidth / 130)))
    let ticks = tickDates(scale: scale, steps: stepCount)
    var groups: [[Int]] = []
    for index in locations.indices {
      if let last = groups.last?.first, locations[index] - locations[last] < 142 {
        groups[groups.count - 1].append(index)
      } else {
        groups.append([index])
      }
    }
    return ZStack(alignment: .topLeading) {
      Canvas { context, size in
        var line = Path()
        line.move(to: CGPoint(x: margin, y: 34))
        line.addLine(to: CGPoint(x: size.width - margin, y: 34))
        for tick in ticks {
          let x = margin + plotWidth * CGFloat(scale.fraction(at: tick.hour))
          line.move(to: CGPoint(x: x, y: 29))
          line.addLine(to: CGPoint(x: x, y: 39))
        }
        context.stroke(line, with: .color(t.secondary), lineWidth: 1)
        for x in locations {
          let dot = Path(ellipseIn: CGRect(x: x - 3, y: 31, width: 6, height: 6))
          context.fill(dot, with: .color(t.accent))
        }
      }.accessibilityHidden(true)
      ForEach(ticks, id: \.hour) { tick in
        Text("\(tick.date.year) · \(tick.date.month) · \(tick.date.day)")
          .font(.studio(.caption)).monospacedDigit().foregroundStyle(t.secondary)
          .position(x: margin + plotWidth * CGFloat(scale.fraction(at: tick.hour)), y: 14)
          .accessibilityLabel(tick.date.label)
      }
      ForEach(groups.indices, id: \.self) { index in
        let group = groups[index]
        let groupEntries = group.map { entries[$0] }
        if let first = group.first {
          groupControl(groupEntries)
            .frame(width: 134, height: 34)
            .position(x: locations[first], y: 70)
        }
      }
    }
    .frame(width: width, height: 104)
    .background(t.surface, in: RoundedRectangle(cornerRadius: Metric.radius))
  }

  private func tickDates(scale: TimelineTimeScale, steps: Int) -> [(hour: Int64, date: CalendarDay)]
  {
    var seen = Set<Int64>()
    return (0...steps).compactMap { index in
      let sample =
        scale.lowerHour
        + (scale.upperHour - scale.lowerHour) * Int64(index) / Int64(steps)
      guard let date = try? calendar.day(containingHour: sample),
        let hour = try? calendar.startHour(of: date),
        hour >= scale.lowerHour, seen.insert(hour).inserted
      else { return nil }
      return (hour, date)
    }
  }

  @ViewBuilder private func groupControl(_ entries: [Entry]) -> some View {
    if let first = entries.first, entries.count == 1 {
      Button {
        inspect(first.event)
      } label: {
        Text(first.event.title).lineLimit(1)
      }
      .buttonStyle(QuietButton(t: t))
      .help(first.day.label)
      .accessibilityValue(first.day.label)
      .contextMenu {
        Button("Inspect event") { inspect(first.event) }
        Button("Edit date…") { edit(first.event) }
      }
    } else {
      PlainMenu {
        ForEach(entries, id: \.event.id) { entry in
          Button {
            inspect(entry.event)
          } label: {
            VStack(alignment: .leading, spacing: 3) {
              Text(entry.event.title).lineLimit(1)
              Text(entry.day.label).font(.studio(.caption)).foregroundStyle(t.secondary)
            }
          }
        }
      } label: {
        Label("\(entries.count) events", systemImage: "ellipsis.circle")
          .font(.studio(.label))
          .foregroundStyle(t.text)
      }.help("Browse nearby events")
    }
  }
}
