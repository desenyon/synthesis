import SwiftUI
import SynthesisCore

enum TimelineDateFilter: String, Codable, CaseIterable {
  case all, dated, undated

  var title: String {
    switch self {
    case .all: return "All dates"
    case .dated: return "Known dates"
    case .undated: return "Unknown dates"
    }
  }

  func includes(_ event: WorldEvent, date: TimelineEventDate?) -> Bool {
    guard self != .all else { return true }
    let hasDate = if case .calendarDay? = date { true } else { Self.wording(of: event) != nil }
    return self == .dated ? hasDate : !hasDate
  }

  static func wording(of event: WorldEvent) -> String? {
    let label = event.dateLabel.trimmingCharacters(in: .whitespacesAndNewlines)
    return label.isEmpty || label.caseInsensitiveCompare("unknown") == .orderedSame ? nil : label
  }
}

struct TimelineEraGroup: Identifiable {
  let lane: ChronologyLane?
  let events: [WorldEvent]

  var id: String { lane?.id ?? TimelineViewState.unplacedEraID }
  var name: String { lane?.name ?? "Not in a period" }
  var countLabel: String { "\(events.count) \(events.count == 1 ? "event" : "events")" }

  static func group(
    _ events: [WorldEvent], lanes: [ChronologyLane], placements: [String: String]
  ) -> [Self] {
    let laneIDs = Set(lanes.map(\.id))
    let roots = lanes.filter { lane in
      lane.parentID.map { !laneIDs.contains($0) } ?? true
    }
    let children = Dictionary(grouping: lanes, by: \.parentID)
    var rootByLane: [String: String] = [:]
    var pending = roots.map { (laneID: $0.id, rootID: $0.id) }
    while let entry = pending.popLast() {
      guard rootByLane[entry.laneID] == nil else { continue }
      rootByLane[entry.laneID] = entry.rootID
      for child in children[entry.laneID, default: []] {
        pending.append((laneID: child.id, rootID: entry.rootID))
      }
    }
    let byRoot = Dictionary(grouping: events) { event in
      placements[event.id].flatMap { rootByLane[$0] } ?? TimelineViewState.unplacedEraID
    }
    var groups = roots.compactMap { lane in
      byRoot[lane.id].map { Self(lane: lane, events: $0) }
    }
    if let unplaced = byRoot[TimelineViewState.unplacedEraID] {
      groups.append(Self(lane: nil, events: unplaced))
    }
    return groups
  }
}

struct TimelineActivitySummary: View {
  let groups: [TimelineEraGroup]
  @Binding var dateFilter: TimelineDateFilter
  let t: Theme
  var showGroup: (TimelineEraGroup.ID) -> Void

  var body: some View {
    let largestCount = groups.map { $0.events.count }.max() ?? 1
    VStack(alignment: .leading, spacing: Space.sm) {
      HStack(spacing: Space.sm) {
        Text("Events by era").font(.studio(.cardTitle)).lineLimit(1)
        Spacer(minLength: 0)
        PlainMenu {
          ForEach(TimelineDateFilter.allCases, id: \.self) { option in
            Button {
              dateFilter = option
            } label: {
              HStack {
                Text(option.title)
                Spacer()
                if option == dateFilter { StudioIcon("check", size: 11) }
              }
            }.accessibilityAddTraits(dateFilter == option ? .isSelected : [])
          }
        } label: {
          HStack(spacing: 5) {
            Text(dateFilter.title).font(.studio(.label))
            StudioIcon("chevron.down", size: 9).foregroundStyle(t.secondary)
          }
        }.accessibilityLabel("Date filter, \(dateFilter.title)")
      }
      if groups.isEmpty {
        Text("No events match the current filters.").font(.studio(.caption))
          .foregroundStyle(t.secondary).fixedSize(horizontal: false, vertical: true)
      }
      ForEach(groups) { group in
        Button {
          showGroup(group.id)
        } label: {
          VStack(alignment: .leading, spacing: Space.xs) {
            HStack(spacing: Space.sm) {
              Text(group.name).font(.studio(.label)).lineLimit(1).help(group.name)
              Spacer(minLength: 0)
              Text(group.countLabel).font(.studio(.caption)).monospacedDigit()
                .foregroundStyle(t.secondary)
            }
            GeometryReader { track in
              ZStack(alignment: .leading) {
                Capsule().fill(t.surface)
                Capsule().fill(t.accent)
                  .frame(
                    width: track.size.width * CGFloat(group.events.count) / CGFloat(largestCount))
              }
            }.frame(height: 5).accessibilityHidden(true)
          }
          .padding(.horizontal, Space.sm).padding(.vertical, Space.xs)
          .contentShape(Rectangle())
        }.buttonStyle(.plain).hoverFill(t, radius: Metric.smallRadius)
          .accessibilityLabel("\(group.name), \(group.countLabel)")
          .accessibilityHint("Show events in this group")
      }
    }
  }
}
