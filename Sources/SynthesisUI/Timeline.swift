import SwiftUI
import SynthesisCore

/// Chronology of sourced events. Date labels keep the world's own language; ordering is an
/// optional position and never invents calendar precision.
/// How much of each event Timeline shows. Remembered on this device only.
enum TimelineDensity: String, CaseIterable, Codable {
  case detailed, compact, overview, axis
  var title: String {
    switch self {
    case .detailed: return "Detailed"
    case .compact: return "Compact"
    case .overview: return "By era"
    case .axis: return "Calendar axis"
    }
  }
}

private enum TimelineDateInput: Hashable {
  case wording, calendarDay, unknown
}

struct TimelineScreen: View {
  @ObservedObject var studio: Studio
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var lanes: [ChronologyLane] = []
  @State private var placements: [String: String] = [:]
  private var foldedLanes: Set<String> {
    get { studio.timelineView.foldedLanes }
    nonmutating set { studio.timelineView.foldedLanes = newValue }
  }
  private var selectedLane: String {
    get { studio.timelineLaneID ?? "" }
    nonmutating set { studio.timelineLaneID = newValue.isEmpty ? nil : newValue }
  }
  @State private var eventLane = ""
  @State private var creatingLane = false
  @State private var editingLane: ChronologyLane?
  @State private var laneParent = ""
  @State private var laneNotes = ""
  @State private var laneName = ""
  @State private var laneKind = "period"
  @State private var laneStart = ""
  @State private var laneEnd = ""
  @State private var events: [WorldEvent] = []
  private var density: TimelineDensity {
    get { studio.timelineView.density }
    nonmutating set { studio.timelineView.density = newValue }
  }
  private var foldedEras: Set<String> {
    get { studio.timelineView.foldedEras }
    nonmutating set { studio.timelineView.foldedEras = newValue }
  }
  private var query: String {
    get { studio.timelineView.query }
    nonmutating set { studio.timelineView.query = newValue }
  }
  @State private var editing: WorldEvent?
  @State private var composing = false
  @State private var newSource = false
  @State private var title = ""
  @State private var date = ""
  @State private var order = ""
  @State private var source = ""
  @State private var sourcePicker = false
  @State private var calendar: TimelineCalendar?
  @State private var timelineDates: [String: TimelineEventDate] = [:]
  @State private var calendarSheetWorld: String?
  @State private var creatingCalendar = false
  @State private var editingWorld: String?
  @State private var expectedEvent: TimelineEventExpectation?
  @State private var dateInput: TimelineDateInput = .wording
  @State private var year = ""
  @State private var month = ""
  @State private var day = ""

  private var calendarDay: CalendarDay? {
    guard let calendar, let year = Int(year), let month = Int(month), let day = Int(day)
    else { return nil }
    let value = CalendarDay(year: year, month: month, day: day)
    guard (try? calendar.startHour(of: value)) != nil else { return nil }
    return value
  }

  private func displayDate(_ event: WorldEvent) -> String {
    if let typed = timelineDates[event.id] {
      if case .unknown = typed, event.dateLabel != "unknown", !event.dateLabel.isEmpty {
        return event.dateLabel
      }
      return typed.label
    }
    return event.dateLabel == "unknown" || event.dateLabel.isEmpty
      ? "Date unknown" : event.dateLabel
  }
  private var filtered: [WorldEvent] {
    events.filter {
      (selectedLane.isEmpty || placements[$0.id] == selectedLane
        || descendants.contains(placements[$0.id] ?? ""))
        && (query.isEmpty || $0.dateLabel.localizedCaseInsensitiveContains(query)
          || displayDate($0).localizedCaseInsensitiveContains(query)
          || $0.title.localizedCaseInsensitiveContains(query))
    }
  }
  private var descendants: Set<String> {
    guard !selectedLane.isEmpty else { return [] }
    return laneFamily(selectedLane)
  }
  var body: some View {
    let rows = filtered
    VStack(spacing: 0) {
      WorkspaceBar(studio: studio) {
        BarTitle(
          icon: Destination.timeline.icon, title: "Timeline",
          detail: "\(events.count) \(events.count == 1 ? "event" : "events")", t: studio.t)
      } trailing: {
        SearchField(
          text: $studio.timelineView.query, placeholder: "Find an era or event", t: studio.t
        )
        .frame(minWidth: 120, idealWidth: 220, maxWidth: 220)
        BarAction(
          title: "Event", icon: "plus", t: studio.t, primary: true,
          help: "Add an event, using existing lore or a new draft document"
        ) { begin(nil) }
      }
      historyHeader
      if !lanes.isEmpty { historyTree }
      if density == .axis {
        axis(rows)
      } else if rows.isEmpty {
        empty.frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        ScrollViewReader { proxy in
          ScrollView {
            ContentColumn {
              switch density {
              case .detailed:
                VStack(alignment: .leading, spacing: 0) {
                  ForEach(Array(rows.enumerated()), id: \.element.id) { index, event in
                    row(event, first: index == 0, last: index == rows.count - 1)
                  }
                }.padding(.vertical, 20)
              case .compact:
                VStack(alignment: .leading, spacing: 1) {
                  ForEach(rows) { event in compactRow(event) }
                }.padding(.vertical, 16)
              case .overview:
                overview(rows, proxy: proxy)
              case .axis:
                EmptyView()
              }
            }
          }
        }
      }
    }
    .onAppear {
      if studio.captureHint == "timeline-compact" { density = .compact }
      if studio.captureHint == "timeline-overview" { density = .overview }
      refresh()
      consumePendingEvent()
      if studio.captureHint.hasPrefix("timeline-axis") {
        density = .axis
        if studio.captureHint == "timeline-axis-new-calendar" {
          calendarSheetWorld = studio.worldID
          creatingCalendar = true
        }
        if studio.captureHint == "timeline-axis-date",
          let dated = events.first(where: { timelineDates[$0.id] != nil })
        {
          begin(dated)
        }
      }
      if studio.captureHint == "timeline-edit", let lane = lanes.first {
        selectedLane = lane.id
        edit(lane)
      }
    }
    .onChange(of: studio.pendingEventSourceID) { _, _ in consumePendingEvent() }
    .onChange(of: studio.worldRevision) { _, _ in refresh() }
    .studioSheet(isPresented: $composing) { form }
    .studioSheet(isPresented: $creatingLane) { laneForm }
    .studioSheet(isPresented: $creatingCalendar) {
      if let worldID = calendarSheetWorld {
        FixedTimelineCalendarSheet(studio: studio, worldID: worldID) {
          creatingCalendar = false
          refresh()
        }
      }
    }
  }

  private func axis(_ rows: [WorldEvent]) -> some View {
    let unplaced = rows.filter { event in
      if case .calendarDay? = timelineDates[event.id] { return false }
      return true
    }
    return ScrollView {
      ContentColumn {
        VStack(alignment: .leading, spacing: 18) {
          if let calendar {
            FixedTimelineAxis(
              calendar: calendar, events: rows, dates: timelineDates, t: studio.t,
              inspect: { studio.inspect(.event($0.id)) }, edit: { begin($0) }
            ).id(calendar.id)
          } else {
            EmptyState(
              icon: "calendar", title: "Set up a calendar",
              message:
                "Define this world’s calendar to position events on the axis.",
              t: studio.t
            ) {
              Button("Create calendar") {
                calendarSheetWorld = studio.worldID
                creatingCalendar = true
              }.buttonStyle(QuietButton(t: studio.t, primary: true))
            }
          }
          if !unplaced.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
              Text("Without a calendar date").font(.studio(.cardTitle))
              ForEach(unplaced) { compactRow($0) }
            }
          } else if rows.isEmpty, !query.isEmpty {
            empty
          }
        }.padding(.vertical, 16)
      }
    }
  }

  private var historyHeader: some View {
    let lane = lanes.first { $0.id == selectedLane }
    return ContentHeader {
      ViewThatFits(in: .horizontal) {
        HStack(spacing: Space.sm) {
          historyScope(lane)
          Spacer(minLength: Space.sm)
          timelineDisplayMenu
          Button("New branch") { beginHistory("branch") }.buttonStyle(QuietButton(t: studio.t))
          Button("New period") { beginHistory("period") }.buttonStyle(QuietButton(t: studio.t))
        }
        VStack(alignment: .leading, spacing: Space.sm) {
          historyScope(lane)
          HStack(spacing: Space.sm) {
            timelineDisplayMenu
            Spacer(minLength: Space.sm)
            PlainMenu {
              Button("New branch") { beginHistory("branch") }
              Button("New period") { beginHistory("period") }
            } label: {
              Label("New history", systemImage: "plus").font(.studio(.label))
            }
          }
        }
      }.frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private func historyScope(_ lane: ChronologyLane?) -> some View {
    HStack(spacing: Space.sm) {
      PlainMenu(flexible: true) {
        Button("All history") { studio.openTimelineLane(nil) }
        ForEach(lanes) { lane in
          Button("\(lane.kind == "branch" ? "Branch" : "Period") · \(lane.name)") {
            studio.openTimelineLane(lane.id)
          }
        }
      } label: {
        HStack(spacing: 5) {
          Text(lane?.name ?? "All history").font(.studio(.label)).lineLimit(1)
          StudioIcon("chevron.down", size: 9).foregroundStyle(studio.t.secondary)
        }.contentShape(Rectangle())
      }.frame(maxWidth: 260, alignment: .leading)
        .layoutPriority(1)
      if let lane {
        let dates = [lane.start, lane.end].filter { !$0.isEmpty }.joined(separator: " — ")
        if !dates.isEmpty {
          Text(dates).font(.studio(.caption)).foregroundStyle(studio.t.secondary)
            .lineLimit(1).help(dates)
        }
        IconButton(icon: "pencil.line", label: "Edit history", t: studio.t) { edit(lane) }
        IconButton(icon: "archivebox", label: "Archive branch or period", t: studio.t) {
          studio.perform {
            try studio.store.setChronologyLaneArchived(
              worldID: studio.worldID, id: lane.id, archived: true)
            selectedLane = ""
            refresh()
            studio.show("Archived \(lane.name)", actionTitle: "Undo") {
              studio.perform {
                try studio.store.setChronologyLaneArchived(
                  worldID: studio.worldID, id: lane.id, archived: false)
                refresh()
              }
            }
          }
        }
      }
    }
  }

  private var timelineDisplayMenu: some View {
    PlainMenu {
      ForEach(TimelineDensity.allCases, id: \.self) { value in
        Button {
          changeDensity(value)
        } label: {
          HStack {
            Text(value.title)
            Spacer()
            if density == value { StudioIcon("check", size: 11) }
          }
        }.accessibilityAddTraits(density == value ? .isSelected : [])
      }
    } label: {
      HStack(spacing: 5) {
        Text(density.title).font(.studio(.label))
        StudioIcon("chevron.down", size: 9).foregroundStyle(studio.t.secondary)
      }.contentShape(Rectangle())
    }.accessibilityLabel("Timeline display, \(density.title)")
  }

  private func changeDensity(_ value: TimelineDensity) {
    withAnimation(reduceMotion ? nil : Motion.panelAnimation) { density = value }
    if value != .axis {
      try? studio.store.setPreference("timeline-density", value: value.rawValue)
    }
  }

  private func beginHistory(_ kind: String) {
    editingLane = nil
    laneParent = selectedLane
    laneNotes = ""
    laneKind = kind
    laneName = ""
    laneStart = ""
    laneEnd = ""
    creatingLane = true
  }

  /// The hierarchy stays visible even when a newly accepted branch has no events yet.
  private var historyTree: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 2) {
        ForEach(treeRows, id: \.lane.id) { entry in
          let family = laneFamily(entry.lane.id)
          HStack(spacing: 4) {
            if lanes.contains(where: { $0.parentID == entry.lane.id }) {
              Button {
                withAnimation(reduceMotion ? nil : Motion.panelAnimation) {
                  if !foldedLanes.insert(entry.lane.id).inserted {
                    foldedLanes.remove(entry.lane.id)
                  }
                }
              } label: {
                StudioIcon("chevron.right", size: 10)
                  .rotationEffect(.degrees(foldedLanes.contains(entry.lane.id) ? 0 : 90))
                  .frame(width: 20, height: 28).contentShape(Rectangle())
              }.buttonStyle(.plain).accessibilityLabel(
                "\(foldedLanes.contains(entry.lane.id) ? "Expand" : "Collapse") \(entry.lane.name)")
            } else {
              Color.clear.frame(width: 20, height: 28)
            }
            Button {
              withAnimation(reduceMotion ? nil : Motion.panelAnimation) {
                studio.openTimelineLane(selectedLane == entry.lane.id ? nil : entry.lane.id)
              }
            } label: {
              HStack(spacing: 8) {
                StudioIcon(
                  entry.lane.kind == "branch" ? "arrow.triangle.branch" : "calendar", size: 13)
                Text(entry.lane.name).lineLimit(1)
                Text(entry.lane.kind == "branch" ? "Branch" : "Period")
                  .font(.studio(size: 11)).foregroundStyle(studio.t.muted)
                Spacer(minLength: 8)
                Text("\(events.filter { family.contains(placements[$0.id] ?? "") }.count)")
                  .monospacedDigit().foregroundStyle(studio.t.secondary)
              }.font(.studio(.label))
                .padding(.trailing, 10).frame(height: 30)
                .contentShape(Rectangle())
            }.buttonStyle(.plain).help("Show \(entry.lane.name) and its nested history")
          }.padding(.leading, 6 + CGFloat(entry.depth) * 20)
            .background(
              selectedLane == entry.lane.id ? studio.t.hover : .clear,
              in: RoundedRectangle(cornerRadius: 6))
        }
      }.padding(.horizontal, 24).padding(.vertical, 8)
    }.frame(maxHeight: min(170, CGFloat(lanes.count * 32 + 16)))
  }
  private var treeRows: [(lane: ChronologyLane, depth: Int)] {
    var result: [(lane: ChronologyLane, depth: Int)] = []
    var seen = Set<String>()
    func visit(_ parent: String?, depth: Int, visible: Bool = true) {
      for lane in lanes where lane.parentID == parent && seen.insert(lane.id).inserted {
        if visible { result.append((lane, depth)) }
        visit(lane.id, depth: depth + 1, visible: visible && !foldedLanes.contains(lane.id))
      }
    }
    visit(nil, depth: 0)
    // An archived parent must not hide a surviving child from All history.
    for lane in lanes where !seen.contains(lane.id) {
      seen.insert(lane.id)
      result.append((lane, 0))
      visit(lane.id, depth: 1, visible: !foldedLanes.contains(lane.id))
    }
    return result
  }
  private func laneFamily(_ id: String) -> Set<String> {
    var result: Set<String> = [id]
    for _ in 0..<lanes.count {
      let children = Set(lanes.filter { $0.parentID.map(result.contains) ?? false }.map(\.id))
      if children.isSubset(of: result) { break }
      result.formUnion(children)
    }
    return result
  }
  /// The top-level period or branch an event's placement belongs to, if any.
  private func era(of event: WorldEvent) -> ChronologyLane? {
    guard var lane = lanes.first(where: { $0.id == placements[event.id] }) else { return nil }
    var seen: Set<String> = [lane.id]
    while let parent = lanes.first(where: { $0.id == lane.parentID }),
      seen.insert(parent.id).inserted
    {
      lane = parent
    }
    return lane
  }
  private func overview(_ rows: [WorldEvent], proxy: ScrollViewProxy) -> some View {
    let eras = lanes.filter { lane in
      lane.parentID == nil || !lanes.contains { $0.id == lane.parentID }
    }
    var groups: [(id: String, lane: ChronologyLane?, events: [WorldEvent])] = eras.map { lane in
      (lane.id, lane, rows.filter { era(of: $0)?.id == lane.id })
    }.filter { !$0.events.isEmpty }
    let unplaced = rows.filter { era(of: $0) == nil }
    if !unplaced.isEmpty { groups.append((TimelineViewState.unplacedEraID, nil, unplaced)) }
    return VStack(alignment: .leading, spacing: 18) {
      if groups.count > 1 {
        ScrollView(.horizontal) {
          HStack(spacing: 6) {
            ForEach(groups, id: \.id) { group in
              FilterChip(
                title: group.lane?.name ?? "Not in a period", count: group.events.count,
                selected: false, t: studio.t
              ) {
                withAnimation(reduceMotion ? nil : Motion.panelAnimation) {
                  proxy.scrollTo(group.id, anchor: .top)
                }
              }
              .help("Jump to \(group.lane?.name ?? "events outside any period")")
            }
          }
        }.scrollIndicators(.never)
      }
      ForEach(groups, id: \.id) { group in
        VStack(alignment: .leading, spacing: 8) {
          Button {
            withAnimation(reduceMotion ? nil : Motion.panelAnimation) {
              if !foldedEras.insert(group.id).inserted { foldedEras.remove(group.id) }
            }
          } label: {
            HStack(spacing: 8) {
              StudioIcon("chevron.right", size: 10)
                .rotationEffect(.degrees(foldedEras.contains(group.id) ? 0 : 90))
              StudioIcon(
                group.lane?.kind == "branch" ? "arrow.triangle.branch" : "calendar", size: 13
              ).foregroundStyle(studio.t.accent)
              Text(group.lane?.name ?? "Not in a period").font(.studio(.cardTitle))
                .lineLimit(1)
              if let lane = group.lane, !(lane.start + lane.end).isEmpty {
                Text([lane.start, lane.end].filter { !$0.isEmpty }.joined(separator: " — "))
                  .font(.studio(size: 12.5)).foregroundStyle(studio.t.secondary).lineLimit(1)
              }
              Spacer(minLength: 8)
              Text("\(group.events.count) \(group.events.count == 1 ? "event" : "events")")
                .font(.studio(.caption)).monospacedDigit().foregroundStyle(studio.t.muted)
            }.contentShape(Rectangle())
          }.buttonStyle(.plain)
            .accessibilityLabel(
              "\(foldedEras.contains(group.id) ? "Expand" : "Collapse") \(group.lane?.name ?? "events outside any period")"
            )
          if !foldedEras.contains(group.id) {
            VStack(alignment: .leading, spacing: 1) {
              ForEach(group.events) { event in compactRow(event) }
            }.padding(.leading, 18)
          }
        }.id(group.id)
      }
    }.padding(.vertical, 18)
  }
  private func compactRow(_ event: WorldEvent) -> some View {
    let source = studio.records.first { $0.id == event.sourceID }
    let date = displayDate(event)
    let unknown = date == "Date unknown"
    let lane = lanes.first { $0.id == placements[event.id] }
    return HStack(spacing: 12) {
      Text(date).font(.studio(.captionStrong))
        .foregroundStyle(unknown ? studio.t.muted : studio.t.category("events")).lineLimit(1)
        .frame(width: 132, alignment: .trailing)
      Circle().fill(unknown ? studio.t.muted : studio.t.category("events")).frame(
        width: 6, height: 6)
      Text(event.title).font(.studio(size: 13.5, weight: .medium)).lineLimit(1)
        .layoutPriority(1)
      if density == .compact, let lane {
        Text(lane.name).font(.studio(size: 11.5)).foregroundStyle(studio.t.muted).lineLimit(1)
      }
      Spacer(minLength: 8)
      if let source {
        Button {
          studio.openRecord(source)
        } label: {
          HStack(spacing: 5) {
            StudioIcon(recordIcon(source), size: 10).foregroundStyle(
              studio.t.category(source.category))
            Text(source.title).font(.studio(.caption)).lineLimit(1)
          }.foregroundStyle(studio.t.secondary)
        }.buttonStyle(.plain).help("Open the source record")
      }
      IconMenu(icon: "ellipsis", label: "Event actions", t: studio.t, size: 22) {
        Button("Edit…") { begin(event) }
        Button("Inspect") { studio.inspect(.event(event.id)) }
        if let source { Button("Open source record") { studio.openRecord(source) } }
        moveActions(event)
        Button("Remove") { remove(event) }
      }
    }.padding(.horizontal, 8).frame(height: 34).hoverFill(studio.t, radius: 7)
      .contextMenu {
        Button("Edit…") { begin(event) }
        Button("Inspect") { studio.inspect(.event(event.id)) }
        if let source { Button("Open source record") { studio.openRecord(source) } }
        moveActions(event)
        Divider()
        Button("Remove") { remove(event) }
      }
  }
  private func row(_ event: WorldEvent, first: Bool, last: Bool) -> some View {
    let sourceRecord = studio.records.first { $0.id == event.sourceID }
    let date = displayDate(event)
    let unknown = date == "Date unknown"
    return HStack(alignment: .top, spacing: 16) {
      Text(date)
        .font(.studio(size: 12.5, weight: .medium))
        .foregroundStyle(unknown ? studio.t.muted : studio.t.category("events"))
        .multilineTextAlignment(.trailing).frame(width: 132, alignment: .trailing)
        .padding(.top, 15)
      VStack(spacing: 0) {
        Rectangle().fill(first ? .clear : studio.t.border).frame(width: 1.5, height: 18)
        Circle().fill(studio.t.background).frame(width: 11, height: 11)
          .overlay(
            Circle().stroke(unknown ? studio.t.muted : studio.t.category("events"), lineWidth: 2))
        Rectangle().fill(last ? .clear : studio.t.border).frame(width: 1.5)
          .frame(maxHeight: .infinity)
      }.frame(width: 12)
      EventCard(
        studio: studio, event: event, source: sourceRecord, edit: { begin(event) },
        remove: { remove(event) },
        moveEarlier: events.first?.id == event.id ? nil : { move(event, by: -1) },
        moveLater: events.last?.id == event.id ? nil : { move(event, by: 1) }
      ).padding(.bottom, 14)
    }.fixedSize(horizontal: false, vertical: true)
  }
  @ViewBuilder private var empty: some View {
    if !query.isEmpty {
      EmptyState(
        icon: "magnifyingglass", title: "No events match",
        message: "Nothing on the timeline matches “\(query)”.", t: studio.t
      ) { Button("Clear search") { query = "" }.buttonStyle(QuietButton(t: studio.t)) }
    } else {
      EmptyState(
        icon: Destination.timeline.icon, title: "No history yet",
        message:
          "Add the moments that shaped this world. Dates can stay vague or unknown — order is optional.",
        t: studio.t
      ) {
        Button("New event") { begin(nil) }.buttonStyle(QuietButton(t: studio.t, primary: true))
      }
    }
  }
  private func consumePendingEvent() {
    guard let id = studio.pendingEventSourceID else { return }
    studio.pendingEventSourceID = nil
    guard studio.records.contains(where: { $0.id == id }) else { return }
    begin(nil)
    source = id
    newSource = false
  }
  private func begin(_ event: WorldEvent?) {
    studio.perform {
      let worldID = studio.worldID
      let fresh = try event.map {
        try studio.store.timelineEventExpectation(worldID: worldID, event: $0)
      }
      let existingDate = fresh?.date
      editingWorld = worldID
      expectedEvent = fresh
      eventLane = event == nil ? selectedLane : fresh?.laneID ?? ""
      editing = event
      title = event?.title ?? ""
      date = event.map { $0.dateLabel == "unknown" ? "" : $0.dateLabel } ?? ""
      order = event?.order.map(String.init) ?? ""
      source = event?.sourceID ?? studio.records.first?.id ?? ""
      newSource = event == nil && studio.records.isEmpty
      year = ""
      month = ""
      day = ""
      switch existingDate {
      case .calendarDay(let value)?:
        dateInput = .calendarDay
        year = String(value.year)
        month = String(value.month)
        day = String(value.day)
      case .unknown?:
        dateInput = .unknown
      case nil:
        dateInput = .wording
      }
      composing = true
    }
  }
  private func move(_ event: WorldEvent, by offset: Int) {
    studio.perform {
      let previous = try studio.store.moveEvent(
        worldID: studio.worldID, id: event.id, by: offset)
      refresh()
      studio.show(
        "Moved “\(event.title)” \(offset < 0 ? "earlier" : "later")", icon: "arrow.up.arrow.down",
        actionTitle: "Undo"
      ) {
        studio.perform {
          try studio.store.restoreEventOrder(worldID: studio.worldID, previous: previous)
          refresh()
        }
      }
    }
  }
  @ViewBuilder private func moveActions(_ event: WorldEvent) -> some View {
    let index = events.firstIndex { $0.id == event.id } ?? 0
    Button("Move earlier") { move(event, by: -1) }.disabled(index == 0)
    Button("Move later") { move(event, by: 1) }.disabled(index >= events.count - 1)
  }
  private func remove(_ event: WorldEvent) {
    studio.perform {
      try studio.store.setEventArchived(worldID: studio.worldID, id: event.id, archived: true)
      refresh()
      studio.show("Removed “\(event.title)”", icon: "minus.circle", actionTitle: "Undo") {
        studio.perform {
          try studio.store.setEventArchived(worldID: studio.worldID, id: event.id, archived: false)
          refresh()
        }
      }
    }
  }
  private func closeForm() { composing = false }
  private var form: some View {
    let existingDate = expectedEvent?.date
    let dateChoices: [(TimelineDateInput, String)] =
      (existingDate == nil ? [(.wording, "Wording only")] : [])
      + (calendar == nil ? [] : [(.calendarDay, "Calendar day")]) + [(.unknown, "Unknown")]
    let valid =
      !title.trimmingCharacters(in: .whitespaces).isEmpty && (newSource || !source.isEmpty)
      && (order.isEmpty || Int(order) != nil) && (dateInput != .calendarDay || calendarDay != nil)
    let save = {
      studio.perform {
        guard let editingWorld, editingWorld == studio.worldID else { throw SynthesisError.stale }
        let proposedDate: TimelineEventDate? =
          dateInput == .unknown
          ? .unknown
          : dateInput == .calendarDay ? calendarDay.map(TimelineEventDate.calendarDay) : nil
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        _ = try studio.store.saveChronologyEvent(
          worldID: studio.worldID, id: editing?.id, title: name, date: date,
          source: newSource ? nil : source,
          order: Int(order), laneID: eventLane.isEmpty ? nil : eventLane,
          timelineDate: proposedDate == existingDate ? nil : proposedDate, expected: expectedEvent)
        try studio.reload()
        composing = false
        refresh()
      }
    }
    return SheetScaffold(
      title: editing == nil ? "New event" : "Edit event", t: studio.t, close: closeForm
    ) {
      FormField(
        label: "What happened", placeholder: "The first crossing", text: $title, t: studio.t)
      HStack(alignment: .top, spacing: 10) {
        FormField(
          label: "When", placeholder: "Leave empty if unknown", text: $date, t: studio.t)
        FormField(label: "Position", placeholder: "Optional", text: $order, t: studio.t)
          .frame(width: 110)
      }
      ChoiceField(
        title: "Calendar placement", selection: $dateInput, choices: dateChoices, t: studio.t)
      if dateInput == .calendarDay, let calendar {
        HStack(spacing: 10) {
          FormField(label: "Year", placeholder: "Year", text: $year, t: studio.t)
          FormField(label: "Month", placeholder: "Month", text: $month, t: studio.t)
          FormField(label: "Day", placeholder: "Day", text: $day, t: studio.t)
        }
        Text(calendarDay == nil ? "Enter a valid date in \(calendar.name)." : calendar.name)
          .font(.studio(.caption)).foregroundStyle(
            calendarDay == nil ? studio.t.danger : studio.t.secondary
          )
          .lineLimit(2)
      }
      ChoiceField(
        title: "Branch or period", selection: $eventLane,
        choices: [("", "Unassigned")] + lanes.map { ($0.id, $0.name) }, t: studio.t)
      Toggle("Write a new document for this event", isOn: $newSource)
        .font(.studio(size: 13.5)).tint(studio.t.accent)
      if newSource {
        Text("A draft named after the event will be added to Library when you save.")
          .font(.studio(size: 13)).foregroundStyle(studio.t.secondary)
      } else {
        VStack(alignment: .leading, spacing: 6) {
          Text("Source record").font(.studio(.captionStrong))
            .foregroundStyle(studio.t.secondary)
          Button {
            sourcePicker = true
          } label: {
            HStack {
              Text(studio.records.first { $0.id == source }?.title ?? "Choose a record")
                .font(.studio(size: 14)).lineLimit(1)
              Spacer()
              StudioIcon("chevron.up.chevron.down", size: 10)
                .foregroundStyle(studio.t.muted)
            }.padding(.horizontal, 10).frame(width: 416, height: 34)
              .background(studio.t.surface, in: RoundedRectangle(cornerRadius: Metric.radius))
              .overlay(
                RoundedRectangle(cornerRadius: Metric.radius).stroke(studio.t.border, lineWidth: 1))
          }.buttonStyle(.plain)
            .popover(isPresented: $sourcePicker) {
              SearchableRecordPicker(records: studio.records, t: studio.t) { record in
                source = record.id
                sourcePicker = false
              }
            }
        }
      }
      Text(
        order.isEmpty || Int(order) != nil
          ? "“When” keeps your world’s own wording. Position is a whole number used only to order events; lower comes first."
          : "Position must be a whole number, or empty."
      ).font(.studio(size: 12.5))
        .foregroundStyle(order.isEmpty || Int(order) != nil ? studio.t.muted : studio.t.danger)
        .lineSpacing(2).fixedSize(horizontal: false, vertical: true)
    } footer: {
      Spacer()
      Button("Cancel") { composing = false }.buttonStyle(QuietButton(t: studio.t, role: .ghost))
      Button(editing == nil ? "Add event" : "Save", action: save)
        .buttonStyle(QuietButton(t: studio.t, primary: true)).keyboardShortcut(.defaultAction)
        .disabled(!valid)
    }
  }
  private func closeLane() { creatingLane = false }
  private func edit(_ lane: ChronologyLane) {
    editingLane = lane
    laneName = lane.name
    laneKind = lane.kind
    laneStart = lane.start
    laneEnd = lane.end
    laneParent = lane.parentID ?? ""
    laneNotes = lane.notes
    creatingLane = true
  }
  private var laneForm: some View {
    SheetScaffold(
      title: editingLane != nil
        ? "Edit history" : (laneKind == "branch" ? "New history branch" : "New period"),
      subtitle: "Keep your world's own chronology. Dates can stay uncertain.", t: studio.t,
      close: closeLane
    ) {
      FormField(
        label: "Name",
        placeholder: laneKind == "branch" ? "An alternate history" : "Age of the first kingdoms",
        text: $laneName, t: studio.t)
      HStack(spacing: 12) {
        FormField(
          label: "Beginning", placeholder: "Optional date or era", text: $laneStart, t: studio.t)
        FormField(
          label: "End", placeholder: "Optional; may still be ongoing", text: $laneEnd, t: studio.t)
      }
      ChoiceField(
        title: "Inside", selection: $laneParent,
        choices: [("", "All history")]
          + lanes.filter { !laneFamily(editingLane?.id ?? "").contains($0.id) }.map {
            ($0.id, $0.name)
          }, t: studio.t)
      FormField(
        label: "Notes", placeholder: "What defines this history?", text: $laneNotes, t: studio.t)
    } footer: {
      Spacer()
      Button(editingLane == nil ? "Create" : "Save changes") {
        studio.perform {
          let lane: ChronologyLane
          if let editingLane {
            lane = try studio.store.updateChronologyLane(
              worldID: studio.worldID, expected: editingLane,
              name: laneName, parentID: laneParent.isEmpty ? nil : laneParent, start: laneStart,
              end: laneEnd, notes: laneNotes)
          } else {
            lane = try studio.store.createChronologyLane(
              worldID: studio.worldID, name: laneName, kind: laneKind,
              parentID: laneParent.isEmpty ? nil : laneParent, start: laneStart, end: laneEnd,
              notes: laneNotes)
          }
          selectedLane = lane.id
          creatingLane = false
          try studio.reload()
          refresh()
        }
      }.buttonStyle(QuietButton(t: studio.t, primary: true)).disabled(
        laneName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
  }
  private func refresh() {
    studio.perform {
      events = try studio.store.events(worldID: studio.worldID)
      lanes = try studio.store.chronologyLanes(worldID: studio.worldID)
      placements = try studio.store.chronologyPlacements(worldID: studio.worldID)
      calendar = try studio.store.timelineCalendar(worldID: studio.worldID)
      timelineDates = try studio.store.timelineEventDates(worldID: studio.worldID)
      if !selectedLane.isEmpty && !lanes.contains(where: { $0.id == selectedLane }) {
        selectedLane = ""
      }
    }
  }
}

private struct EventCard: View {
  @ObservedObject var studio: Studio
  let event: WorldEvent
  let source: LoreRecord?
  var edit: () -> Void
  var remove: () -> Void
  var moveEarlier: (() -> Void)?
  var moveLater: (() -> Void)?
  var body: some View {
    let t = studio.t
    HStack(alignment: .top, spacing: 10) {
      VStack(alignment: .leading, spacing: 8) {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          StudioIcon("calendar", size: 14).foregroundStyle(t.category("events"))
          Text(event.title).font(.studio(.cardTitle))
            .fixedSize(horizontal: false, vertical: true)
        }
        HStack(spacing: 10) {
          if let source {
            Button {
              studio.openRecord(source)
            } label: {
              HStack(spacing: 5) {
                StudioIcon(recordIcon(source), size: 11)
                  .foregroundStyle(t.category(source.category))
                Text(source.title).font(.studio(size: 12.5, weight: .medium)).lineLimit(1)
              }.foregroundStyle(t.secondary).padding(.horizontal, 7).frame(height: 24)
                .background(t.background.opacity(0.6), in: RoundedRectangle(cornerRadius: 6))
                .hoverFill(t, radius: 6)
            }.buttonStyle(.plain).help("Open the source record")
          } else {
            Text("Source archived").font(.studio(size: 12.5)).foregroundStyle(t.muted)
          }
          StateBadge(state: "draft", t: t)
        }
      }
      Spacer(minLength: 0)
      IconMenu(icon: "ellipsis", label: "Event actions", t: t, size: 24) {
        Button("Edit…", action: edit)
        Button("Inspect") { studio.inspect(.event(event.id)) }
        Button("Move earlier") { moveEarlier?() }.disabled(moveEarlier == nil)
        Button("Move later") { moveLater?() }.disabled(moveLater == nil)
        Button("Remove", action: remove)
      }
    }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
      .entitySurface(
        t, selected: studio.inspectionTarget == .event(event.id), base: t.surface, bordered: true
      )
      .contentShape(RoundedRectangle(cornerRadius: Metric.cardRadius))
      .onTapGesture {
        if NSApp.currentEvent?.clickCount == 2 {
          edit()
        } else {
          studio.selectForInspection(.event(event.id))
        }
      }
      .accessibilityAction { studio.selectForInspection(.event(event.id)) }
      .workspaceReferenceDraggable(
        WorldReference(worldID: studio.worldID, kind: .event, id: event.id),
        title: event.title, icon: "calendar", studio: studio
      )
      .accessibilityAction(named: "Edit event", edit)
      .contextMenu {
        Button("Edit…", action: edit)
        Button("Inspect") { studio.inspect(.event(event.id)) }
        if let source { Button("Open source record") { studio.openRecord(source) } }
        Button("Move earlier") { moveEarlier?() }.disabled(moveEarlier == nil)
        Button("Move later") { moveLater?() }.disabled(moveLater == nil)
        Divider()
        Button("Remove", action: remove)
      }
  }
}
