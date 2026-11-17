import SwiftUI
import SynthesisCore

/// Chronology of sourced events. Date labels keep the world's own language; ordering is an
/// optional position and never invents calendar precision.
struct TimelineScreen: View {
  @ObservedObject var studio: Studio
  @State private var lanes: [ChronologyLane] = []
  @State private var placements: [String: String] = [:]
  @State private var selectedLane = ""
  @State private var eventLane = ""
  @State private var creatingLane = false
  @State private var laneName = ""
  @State private var laneKind = "period"
  @State private var laneStart = ""
  @State private var laneEnd = ""
  @State private var events: [WorldEvent] = []
  @State private var query = ""
  @State private var editing: WorldEvent?
  @State private var composing = false
  @State private var newSource = false
  @State private var title = ""
  @State private var date = ""
  @State private var order = ""
  @State private var source = ""
  @State private var sourcePicker = false
  private var filtered: [WorldEvent] {
    events.filter {
      (selectedLane.isEmpty || placements[$0.id] == selectedLane
        || descendants.contains(placements[$0.id] ?? ""))
        && (query.isEmpty || $0.dateLabel.localizedCaseInsensitiveContains(query)
          || $0.title.localizedCaseInsensitiveContains(query))
    }
  }
  private var descendants: Set<String> {
    guard !selectedLane.isEmpty else { return [] }
    var ids: Set<String> = [selectedLane]
    for _ in 0..<lanes.count {
      let next = Set(lanes.filter { $0.parentID.map(ids.contains) ?? false }.map(\.id))
      if next.isSubset(of: ids) { break }
      ids.formUnion(next)
    }
    return ids
  }
  var body: some View {
    let rows = filtered
    VStack(spacing: 0) {
      WorkspaceBar(studio: studio) {
        BarTitle(
          icon: Destination.timeline.icon, title: "Timeline",
          detail: "\(events.count) \(events.count == 1 ? "event" : "events")", t: studio.t)
      } trailing: {
        SearchField(text: $query, placeholder: "Find an era or event", t: studio.t)
          .frame(minWidth: 120, idealWidth: 220, maxWidth: 220)
        BarAction(
          title: "Event", icon: "plus", t: studio.t, primary: true,
          help: "Add an event, using existing lore or a new draft document"
        ) { begin(nil) }
      }
      ContentHeader {
        Menu {
          Button("All history") { selectedLane = "" }
          ForEach(lanes) { lane in
            Button("\(lane.kind == "branch" ? "Branch" : "Period") · \(lane.name)") {
              selectedLane = lane.id
            }
          }
        } label: {
          Text(lanes.first { $0.id == selectedLane }?.name ?? "All history").font(
            .studio(size: 13, weight: .medium))
        }.frame(maxWidth: 260, alignment: .leading)
        if let lane = lanes.first(where: { $0.id == selectedLane }) {
          Text([lane.start, lane.end].filter { !$0.isEmpty }.joined(separator: " — ")).font(
            .studio(size: 12)
          ).foregroundStyle(studio.t.secondary)
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
        Spacer()
        Button("New branch") {
          laneKind = "branch"
          laneName = ""
          laneStart = ""
          laneEnd = ""
          creatingLane = true
        }.buttonStyle(QuietButton(t: studio.t))
        Button("New period") {
          laneKind = "period"
          laneName = ""
          laneStart = ""
          laneEnd = ""
          creatingLane = true
        }.buttonStyle(QuietButton(t: studio.t))
      }
      if !lanes.isEmpty { historyTree }
      if rows.isEmpty {
        empty.frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        ScrollView {
          ContentColumn {
            VStack(alignment: .leading, spacing: 0) {
              ForEach(Array(rows.enumerated()), id: \.element.id) { index, event in
                row(event, first: index == 0, last: index == rows.count - 1)
              }
            }.padding(.vertical, 20)
          }
        }
      }
    }
    .onAppear { refresh() }
    .onChange(of: studio.worldRevision) { _, _ in refresh() }
    .studioSheet(isPresented: $composing) { form }
    .studioSheet(isPresented: $creatingLane) { laneForm }
  }
  /// The hierarchy stays visible even when a newly accepted branch has no events yet.
  private var historyTree: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 2) {
        ForEach(treeRows, id: \.lane.id) { entry in
          Button {
            withAnimation(.easeOut(duration: 0.18)) {
              selectedLane = selectedLane == entry.lane.id ? "" : entry.lane.id
            }
          } label: {
            HStack(spacing: 8) {
              StudioIcon(
                entry.lane.kind == "branch" ? "arrow.triangle.branch" : "calendar", size: 13)
              Text(entry.lane.name).lineLimit(1)
              Text(entry.lane.kind == "branch" ? "Branch" : "Period")
                .font(.studio(size: 11)).foregroundStyle(studio.t.muted)
              Spacer(minLength: 8)
              Text("\(events.filter { placements[$0.id] == entry.lane.id }.count)")
                .monospacedDigit().foregroundStyle(studio.t.secondary)
            }.font(.studio(size: 13, weight: .medium))
              .padding(.leading, 10 + CGFloat(entry.depth) * 20).padding(.trailing, 10)
              .frame(height: 30).background(
                selectedLane == entry.lane.id ? studio.t.hover : .clear,
                in: RoundedRectangle(cornerRadius: 6)
              )
              .contentShape(Rectangle())
          }.buttonStyle(.plain).help("Show \(entry.lane.name) and its nested history")
        }
      }.padding(.horizontal, 24).padding(.vertical, 8)
    }.frame(maxHeight: min(170, CGFloat(lanes.count * 32 + 16)))
  }
  private var treeRows: [(lane: ChronologyLane, depth: Int)] {
    var result: [(lane: ChronologyLane, depth: Int)] = []
    var seen = Set<String>()
    func visit(_ parent: String?, depth: Int) {
      for lane in lanes where lane.parentID == parent && seen.insert(lane.id).inserted {
        result.append((lane, depth))
        visit(lane.id, depth: depth + 1)
      }
    }
    visit(nil, depth: 0)
    // An archived parent must not hide a surviving child from All history.
    for lane in lanes where !seen.contains(lane.id) { result.append((lane, 0)) }
    return result
  }
  private func row(_ event: WorldEvent, first: Bool, last: Bool) -> some View {
    let sourceRecord = studio.records.first { $0.id == event.sourceID }
    let unknown = event.dateLabel == "unknown"
    return HStack(alignment: .top, spacing: 16) {
      Text(unknown ? "Date unknown" : event.dateLabel)
        .font(.studio(size: 12.5, weight: .medium))
        .foregroundStyle(unknown ? studio.t.muted : studio.t.accent)
        .multilineTextAlignment(.trailing).frame(width: 132, alignment: .trailing)
        .padding(.top, 15)
      VStack(spacing: 0) {
        Rectangle().fill(first ? .clear : studio.t.border).frame(width: 1.5, height: 18)
        Circle().fill(studio.t.background).frame(width: 11, height: 11)
          .overlay(Circle().stroke(unknown ? studio.t.muted : studio.t.accent, lineWidth: 2))
        Rectangle().fill(last ? .clear : studio.t.border).frame(width: 1.5)
          .frame(maxHeight: .infinity)
      }.frame(width: 12)
      EventCard(
        studio: studio, event: event, source: sourceRecord, edit: { begin(event) },
        remove: { remove(event) }
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
  private func begin(_ event: WorldEvent?) {
    eventLane = event.flatMap { placements[$0.id] } ?? selectedLane
    editing = event
    title = event?.title ?? ""
    date = event.map { $0.dateLabel == "unknown" ? "" : $0.dateLabel } ?? ""
    order = event?.order.map(String.init) ?? ""
    source = event?.sourceID ?? studio.records.first?.id ?? ""
    newSource = event == nil && studio.records.isEmpty
    composing = true
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
    let valid =
      !title.trimmingCharacters(in: .whitespaces).isEmpty && (newSource || !source.isEmpty)
      && (order.isEmpty || Int(order) != nil)
    let save = {
      studio.perform {
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        _ = try studio.store.saveChronologyEvent(
          worldID: studio.worldID, id: editing?.id, title: name, date: date,
          source: newSource ? nil : source,
          order: Int(order), laneID: eventLane.isEmpty ? nil : eventLane)
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
        title: "Branch or period", selection: $eventLane,
        choices: [("", "Unassigned")] + lanes.map { ($0.id, $0.name) }, t: studio.t)
      Toggle("Write a new document for this event", isOn: $newSource)
        .font(.studio(size: 13.5)).tint(studio.t.accent)
      if newSource {
        Text("A draft named after the event will be added to Library when you save.")
          .font(.studio(size: 13)).foregroundStyle(studio.t.secondary)
      } else {
        VStack(alignment: .leading, spacing: 6) {
          Text("Source record").font(.studio(size: 12, weight: .medium))
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
  private var laneForm: some View {
    SheetScaffold(
      title: laneKind == "branch" ? "New history branch" : "New period",
      subtitle: "Keep your world's own chronology. Dates can stay uncertain.", t: studio.t,
      close: closeLane
    ) {
      FormField(
        label: "Name",
        placeholder: laneKind == "branch" ? "An alternate history" : "Age of the first kingdoms",
        text: $laneName, t: studio.t)
      if laneKind == "period" {
        FormField(
          label: "Beginning", placeholder: "Optional date or era", text: $laneStart, t: studio.t)
        FormField(
          label: "End", placeholder: "Optional; may still be ongoing", text: $laneEnd, t: studio.t)
      }
      Text(
        selectedLane.isEmpty
          ? "Created at the root of your history." : "Created inside the selected branch or period."
      )
      .font(.studio(size: 12)).foregroundStyle(studio.t.secondary)
    } footer: {
      Spacer()
      Button("Create") {
        studio.perform {
          let lane = try studio.store.createChronologyLane(
            worldID: studio.worldID, name: laneName, kind: laneKind,
            parentID: selectedLane.isEmpty ? nil : selectedLane, start: laneStart, end: laneEnd)
          selectedLane = lane.id
          creatingLane = false
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
  @State private var hover = false
  var body: some View {
    let t = studio.t
    HStack(alignment: .top, spacing: 10) {
      VStack(alignment: .leading, spacing: 8) {
        Text(event.title).font(.studio(size: 16, weight: .semibold))
          .fixedSize(horizontal: false, vertical: true)
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
        Button("Remove", action: remove)
      }
    }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
      .background(
        t.surface.opacity(hover ? 1 : 0.7), in: RoundedRectangle(cornerRadius: Metric.cardRadius)
      )
      .overlay(RoundedRectangle(cornerRadius: Metric.cardRadius).stroke(t.hairline, lineWidth: 1))
      .onHover { hover = $0 }
      .contextMenu {
        Button("Edit…", action: edit)
        if let source { Button("Open source record") { studio.openRecord(source) } }
        Divider()
        Button("Remove", action: remove)
      }
  }
}
