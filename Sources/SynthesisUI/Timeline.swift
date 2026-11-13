import SwiftUI
import SynthesisCore

/// Chronology of sourced events. Date labels keep the world's own language; ordering is an
/// optional position and never invents calendar precision.
struct TimelineScreen: View {
  @ObservedObject var studio: Studio
  @State private var events: [WorldEvent] = []
  @State private var query = ""
  @State private var editing: WorldEvent?
  @State private var composing = false
  @State private var title = ""
  @State private var date = ""
  @State private var order = ""
  @State private var source = ""
  private var filtered: [WorldEvent] {
    events.filter {
      query.isEmpty || $0.dateLabel.localizedCaseInsensitiveContains(query)
        || $0.title.localizedCaseInsensitiveContains(query)
    }
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
          help: studio.records.isEmpty
            ? "Create a record first; every event cites its source" : "Add an event"
        ) { begin(nil) }.disabled(studio.records.isEmpty)
      }
      if rows.isEmpty {
        empty.frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        ScrollView {
          VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, event in
              row(event, first: index == 0, last: index == rows.count - 1)
            }
          }.padding(.vertical, 20).padding(.horizontal, 28).frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
      }
    }
    .onAppear { refresh() }
    .sheet(isPresented: $composing) { form }
  }
  private func row(_ event: WorldEvent, first: Bool, last: Bool) -> some View {
    let sourceRecord = studio.records.first { $0.id == event.sourceID }
    let unknown = event.dateLabel == "unknown"
    return HStack(alignment: .top, spacing: 16) {
      Text(unknown ? "Date unknown" : event.dateLabel)
        .font(.system(size: 12.5, weight: .medium))
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
    } else if studio.records.isEmpty {
      EmptyState(
        icon: Destination.timeline.icon, title: "No history yet",
        message: "Events cite a record as their source. Create a document or entity first.",
        t: studio.t
      ) {
        Button("New record") { studio.sheet = .document }
          .buttonStyle(QuietButton(t: studio.t, primary: true))
      }
    } else {
      EmptyState(
        icon: Destination.timeline.icon, title: "No history yet",
        message:
          "Add the moments that shaped this world. Dates can stay vague or unknown — order is optional.",
        t: studio.t
      ) {
        Button("Add an event") { begin(nil) }.buttonStyle(QuietButton(t: studio.t, primary: true))
      }
    }
  }
  private func begin(_ event: WorldEvent?) {
    editing = event
    title = event?.title ?? ""
    date = event.map { $0.dateLabel == "unknown" ? "" : $0.dateLabel } ?? ""
    order = event?.order.map(String.init) ?? ""
    source = event?.sourceID ?? studio.records.first?.id ?? ""
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
      !title.trimmingCharacters(in: .whitespaces).isEmpty && !source.isEmpty
      && (order.isEmpty || Int(order) != nil)
    let save = {
      studio.perform {
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if let editing {
          _ = try studio.store.updateEvent(
            worldID: studio.worldID, id: editing.id, title: name, date: date, source: source,
            order: Int(order))
        } else {
          _ = try studio.store.addEvent(
            worldID: studio.worldID, title: name, date: date, source: source, order: Int(order))
        }
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
      VStack(alignment: .leading, spacing: 6) {
        Text("Source record").font(.system(size: 12, weight: .medium))
          .foregroundStyle(studio.t.secondary)
        PlainMenu {
          ForEach(studio.records.prefix(80)) { record in
            Button(record.title) { source = record.id }
          }
        } label: {
          HStack {
            Text(studio.records.first { $0.id == source }?.title ?? "Choose a record")
              .font(.system(size: 14)).lineLimit(1)
            Spacer()
            Image(systemName: "chevron.up.chevron.down").font(.system(size: 10))
              .foregroundStyle(studio.t.muted)
          }.padding(.horizontal, 10).frame(width: 416, height: 34)
            .background(studio.t.surface, in: RoundedRectangle(cornerRadius: Metric.radius))
            .overlay(
              RoundedRectangle(cornerRadius: Metric.radius).stroke(studio.t.border, lineWidth: 1))
        }
      }
      Text(
        order.isEmpty || Int(order) != nil
          ? "“When” keeps your world’s own wording. Position is a whole number used only to order events; lower comes first."
          : "Position must be a whole number, or empty."
      ).font(.system(size: 12.5))
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
  private func refresh() {
    studio.perform { events = try studio.store.events(worldID: studio.worldID) }
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
        Text(event.title).font(.system(size: 16, weight: .semibold))
          .fixedSize(horizontal: false, vertical: true)
        HStack(spacing: 10) {
          if let source {
            Button {
              studio.openRecord(source)
            } label: {
              HStack(spacing: 5) {
                Image(systemName: recordIcon(source)).font(.system(size: 11))
                  .foregroundStyle(t.category(source.category))
                Text(source.title).font(.system(size: 12.5, weight: .medium)).lineLimit(1)
              }.foregroundStyle(t.secondary).padding(.horizontal, 7).frame(height: 24)
                .background(t.background.opacity(0.6), in: RoundedRectangle(cornerRadius: 6))
                .hoverFill(t, radius: 6)
            }.buttonStyle(.plain).help("Open the source record")
          } else {
            Text("Source archived").font(.system(size: 12.5)).foregroundStyle(t.muted)
          }
          StateBadge(state: "draft", t: t)
        }
      }
      Spacer(minLength: 0)
      IconMenu(icon: "ellipsis", label: "Event actions", t: t, size: 24) {
        Button("Edit…", action: edit)
        Button("Remove", action: remove)
      }.opacity(hover ? 1 : 0)
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
